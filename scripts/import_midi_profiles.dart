import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// CLI options for MIDI profile import
class CliOptions {
  final String libraryPath;
  final bool dryRun;
  final bool overwriteExisting;

  const CliOptions({
    required this.libraryPath,
    this.dryRun = false,
    this.overwriteExisting = false,
  });
}

/// Standalone MIDI profile import script that works without Flutter
/// Directly writes to the SQLite database
void main(List<String> args) async {
  final cliOptions = _parseCliOptions(args);
  final libraryPath = _resolveLibraryPath(cliOptions.libraryPath);
  final dbPath = await _findDatabasePath();

  if (dbPath == null) {
    exit(1);
  }

  try {
    // Read and parse library.json
    final file = File(libraryPath);
    if (!await file.exists()) {
      exit(1);
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Extract MIDI profiles
    final midiProfiles = <Map<String, dynamic>>[];
    final midiLibraryMessages = data['midiLibraryMessages'] as List<dynamic>?;
    if (midiLibraryMessages != null) {
      for (final profile
          in midiLibraryMessages.whereType<Map<String, dynamic>>()) {
        if (profile['id'] != null && profile['midi'] != null) {
          midiProfiles.add(profile);
        }
      }
    }

    if (midiProfiles.isEmpty) {
      exit(1);
    }

    // Display profiles to be imported
    for (var i = 0; i < midiProfiles.length; i++) {
      final profile = midiProfiles[i];
      final id = profile['id'] as String? ?? 'Unknown ID';
      final name = profile['name'] as String? ?? _generateProfileName(profile);
    }

    if (!cliOptions.dryRun) {
      final response = stdin.readLineSync()?.toLowerCase();

      if (response != 'y' && response != 'yes') {
        exit(0);
      }
    }

    // Open database
    final db = sqlite3.open(dbPath);

    try {
      // Ensure midi_profiles table exists with correct schema
      await _ensureDatabaseSchema(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      var imported = 0;
      var skipped = 0;
      var updated = 0;

      // Check for existing profiles if not overwriting
      Set<String> existingProfileIds = {};
      if (!cliOptions.overwriteExisting) {
        final existingResults = db.select('SELECT id FROM midi_profiles');
        existingProfileIds =
            existingResults.map((row) => row['id'] as String).toSet();
      }

      for (final profileJson in midiProfiles) {
        final id = profileJson['id'] as String? ?? const Uuid().v4();
        final name =
            profileJson['name'] as String? ?? _generateProfileName(profileJson);
        final midiMessages = profileJson['midi'] as List<dynamic>? ?? [];

        // Skip if profile already exists and not overwriting
        if (!cliOptions.overwriteExisting && existingProfileIds.contains(id)) {
          skipped++;
          continue;
        }

        // Convert raw MIDI messages to NextChord format
        final midiData = _convertMidiProfile(midiMessages);
        if (midiData == null) {
          skipped++;
          continue;
        }

        final programChangeNumber = midiData['programChangeNumber'] as int?;
        final controlChanges = jsonEncode(midiData['controlChanges'] as List);
        final notes = midiData['notes'] as String?;

        if (cliOptions.overwriteExisting && existingProfileIds.contains(id)) {
          // Update existing profile
          db.execute('''
            UPDATE midi_profiles SET
              name = ?, program_change_number = ?, control_changes = ?, 
              timing = ?, notes = ?, updated_at = ?
          ''', [
            name,
            programChangeNumber,
            controlChanges,
            0,
            notes,
            now,
            id,
          ]);
          updated++;
        } else {
          // Insert new profile
          db.execute('''
            INSERT INTO midi_profiles (
              id, name, program_change_number, control_changes, 
              timing, notes, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            id,
            name,
            programChangeNumber,
            controlChanges,
            0,
            notes,
            now,
            now,
          ]);
          imported++;
        }
      }
    } finally {
      db.dispose();
    }
  } catch (e) {
    exit(1);
  }
}

/// Parse CLI options
CliOptions _parseCliOptions(List<String> args) {
  String libraryPath = 'library.json';
  bool dryRun = false;
  bool overwriteExisting = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--help':
        _printUsage();
        exit(0);
      case '--dry-run':
        dryRun = true;
        break;
      case '--overwrite':
        overwriteExisting = true;
        break;
      case '--file':
        if (i + 1 < args.length) {
          libraryPath = args[++i];
        } else {
          exit(1);
        }
        break;
      default:
        if (args[i].startsWith('--')) {
          _printUsage();
          exit(1);
        }
        break;
    }
  }

  return CliOptions(
    libraryPath: libraryPath,
    dryRun: dryRun,
    overwriteExisting: overwriteExisting,
  );
}

/// Print usage information
void _printUsage() {}

/// Resolve library.json path
String _resolveLibraryPath(String libraryPath) {
  if (p.isAbsolute(libraryPath)) {
    return libraryPath;
  }

  // Try relative to script directory, then examples directory
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final examplesDir = p.join(p.dirname(scriptDir), 'examples');

  final possiblePaths = [
    p.join(scriptDir, libraryPath),
    p.join(examplesDir, libraryPath),
    libraryPath,
  ];

  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  return libraryPath; // Return original if not found
}

/// Find the NextChord database file
Future<String?> _findDatabasePath() async {
  final env = Platform.environment;
  final homeDir = env['HOME'] ?? env['USERPROFILE'];

  if (homeDir == null) {
    return null;
  }

  final possiblePaths = <String>[];
  Directory? deepSearchRoot;

  if (Platform.isMacOS) {
    possiblePaths.addAll([
      '$homeDir/Library/Containers/com.example.nextchord/Data/Documents/nextchord_db.sqlite',
      '$homeDir/Documents/nextchord_db.sqlite',
    ]);
  } else if (Platform.isWindows) {
    final userProfile = env['USERPROFILE'] ?? homeDir;
    // Prioritize Documents folder and look for any SQLite file
    possiblePaths.addAll([
      '$userProfile\\Documents\\nextchord_db.sqlite',
      '$userProfile\\Documents\\*.sqlite', // Allow any SQLite file in Documents
      '$userProfile\\AppData\\Local\\nextchord_db.sqlite',
      '$userProfile\\AppData\\Roaming\\nextchord_db.sqlite',
    ]);
    deepSearchRoot = Directory('$userProfile\\Documents');
  } else {
    possiblePaths.addAll([
      '$homeDir/nextchord_db.sqlite',
      '$homeDir/Documents/nextchord_db.sqlite',
    ]);
  }

  possiblePaths.add('nextchord_db.sqlite'); // Current directory fallback

  // If on Windows, search Documents folder for any SQLite file
  if (Platform.isWindows &&
      deepSearchRoot != null &&
      await deepSearchRoot.exists()) {
    await for (final entity
        in deepSearchRoot.list(recursive: false, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        return entity.path;
      }
    }

    // Also search subdirectories in Documents
    await for (final entity
        in deepSearchRoot.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        return entity.path;
      }
    }
  }

  return null;
}

/// Ensure database schema is up to date for MIDI profiles
Future<void> _ensureDatabaseSchema(Database db) async {
  try {
    // Check if midi_profiles table exists
    final tables = db.select('''
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='midi_profiles'
    ''');

    if (tables.isEmpty) {
      db.execute('''
        CREATE TABLE midi_profiles (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          program_change_number INTEGER,
          control_changes TEXT NOT NULL DEFAULT '[]',
          timing BOOLEAN NOT NULL DEFAULT FALSE,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    } else {}

    // Check if profile_id column exists in songs table
    try {
      db.select('SELECT profile_id FROM songs LIMIT 1');
    } catch (e) {
      db.execute('ALTER TABLE songs ADD COLUMN profile_id TEXT');
    }

    return;
  } catch (e) {
    rethrow;
  }
}

/// Generate a user-friendly name from MIDI profile data
String _generateProfileName(Map<String, dynamic> profile) {
  final midiMessages = profile['midi'] as List<dynamic>? ?? [];
  if (midiMessages.isEmpty) return 'Unnamed Profile';

  final parts = <String>[];

  for (final message in midiMessages.whereType<Map<String, dynamic>>()) {
    final status = message['status'] as int? ?? 0;
    final data1 = message['data1'] as int? ?? 0;
    final data2 = message['data2'] as int? ?? 0;

    switch (status) {
      case 192: // Program Change
        parts.add('PC$data1');
        break;
      case 176: // Control Change
        parts.add('CC$data1:$data2');
        break;
      case 248: // MIDI Clock
        parts.add('Timing');
        break;
    }
  }

  if (parts.isEmpty) return 'Unnamed Profile';

  return parts.join(', ');
}

/// Convert raw MIDI messages to NextChord profile format
Map<String, dynamic>? _convertMidiProfile(List<dynamic> midiMessages) {
  if (midiMessages.isEmpty) return null;

  int? programChangeNumber;
  final List<Map<String, dynamic>> controlChanges = [];

  for (final message in midiMessages.whereType<Map<String, dynamic>>()) {
    final status = message['status'] as int? ?? 0;
    final data1 = message['data1'] as int? ?? 0;
    final data2 = message['data2'] as int? ?? 0;

    switch (status) {
      case 176: // Control Change (0xB0)
        controlChanges.add({
          'controller': data1,
          'value': data2,
          'label': null,
        });
        break;
      case 192: // Program Change (0xC0)
        programChangeNumber = data1;
        break;
      default:
        // Ignore other status types (including timing) for now
        break;
    }
  }

  if (programChangeNumber == null && controlChanges.isEmpty) {
    return null;
  }

  String? notes;
  final descriptionParts = <String>[];
  if (programChangeNumber != null) {
    descriptionParts.add('PC$programChangeNumber');
  }
  for (final cc in controlChanges) {
    descriptionParts.add('CC${cc['controller']}:${cc['value']}');
  }

  if (descriptionParts.isNotEmpty) {
    notes = 'Imported from library.json: ${descriptionParts.join(', ')}';
  }

  return {
    'programChangeNumber': programChangeNumber,
    'controlChanges': controlChanges,
    'notes': notes,
  };
}
