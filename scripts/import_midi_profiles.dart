// ignore_for_file: avoid_print

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
  print('🎹 MIDI Profiles - Standalone Importer\n');

  final cliOptions = _parseCliOptions(args);
  final libraryPath = _resolveLibraryPath(cliOptions.libraryPath);
  final dbPath = await _findDatabasePath();

  if (dbPath == null) {
    print('❌ Could not find NextChord database.');
    print('💡 Run the app at least once to create the database.');
    exit(1);
  }

  print('📂 Reading from: $libraryPath');
  print('💾 Database: $dbPath');
  if (cliOptions.dryRun) {
    print('🔍 DRY RUN MODE - No changes will be made to database');
  }
  print('');

  try {
    // Read and parse library.json
    final file = File(libraryPath);
    if (!await file.exists()) {
      print('❌ Error: File not found at $libraryPath');
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
      print('❌ Error: No MIDI profiles found in library.json');
      exit(1);
    }

    print('📊 Found ${midiProfiles.length} MIDI profiles in library.json\n');

    // Display profiles to be imported
    for (var i = 0; i < midiProfiles.length; i++) {
      final profile = midiProfiles[i];
      final id = profile['id'] as String? ?? 'Unknown ID';
      final name = profile['name'] as String? ?? _generateProfileName(profile);
      print('${i + 1}. "$name" (ID: $id)');
    }

    if (!cliOptions.dryRun) {
      print(
          '\n💾 Would you like to import these MIDI profiles to the database? (y/n)');
      final response = stdin.readLineSync()?.toLowerCase();

      if (response != 'y' && response != 'yes') {
        print('\n❌ Import cancelled.');
        exit(0);
      }
    }

    print('\n📝 Importing MIDI profiles...\n');

    // Open database
    final db = sqlite3.open(dbPath);

    try {
      // Ensure midi_profiles table exists with correct schema
      print('🔍 Validating database schema...');
      await _ensureDatabaseSchema(db);
      print('✅ Database schema validated\n');

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
          print('⏭️  Skipping existing profile: "$name" (ID: $id)');
          skipped++;
          continue;
        }

        // Convert raw MIDI messages to NextChord format
        final midiData = _convertMidiProfile(midiMessages);
        if (midiData == null) {
          print('⚠️  Skipping empty profile: "$name" (ID: $id)');
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
          print('🔄 Updated profile: "$name" (ID: $id)');
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
          print('✅ Imported profile: "$name" (ID: $id)');
          imported++;
        }
      }

      print('\n🎉 Import completed!');
      print('📊 Summary:');
      print('   ✅ Imported: $imported');
      print('   🔄 Updated: $updated');
      print('   ⏭️  Skipped: $skipped');
      print('   📋 Total processed: ${midiProfiles.length}');

      if (cliOptions.dryRun) {
        print('\n🔍 DRY RUN MODE - No changes were made to database');
      }
    } finally {
      db.dispose();
    }
  } catch (e) {
    print('\n❌ Error during import: $e');
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
          print('❌ Error: --file requires a path argument');
          exit(1);
        }
        break;
      default:
        if (args[i].startsWith('--')) {
          print('❌ Error: Unknown option ${args[i]}');
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
void _printUsage() {
  print('Usage: dart import_midi_profiles.dart [options]');
  print('');
  print('Options:');
  print(
      '  --file <path>     Path to library.json file (default: library.json)');
  print(
      '  --dry-run         Show what would be imported without making changes');
  print(
      '  --overwrite       Update existing profiles instead of skipping them');
  print('  --help            Show this help message');
  print('');
  print('Examples:');
  print('  dart import_midi_profiles.dart');
  print('  dart import_midi_profiles.dart --file ../data/library.json');
  print('  dart import_midi_profiles.dart --dry-run --overwrite');
}

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
    print('❗ Unable to determine home directory.');
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

  print('🔍 Searching for database in:');

  // First check for exact matches
  for (final path in possiblePaths.where((p) => !p.contains('*'))) {
    print('   - $path');
    if (await File(path).exists()) {
      print('   ✓ Found!\n');
      return path;
    }
  }

  print('   ✗ Not found in standard locations\n');

  // If on Windows, search Documents folder for any SQLite file
  if (Platform.isWindows &&
      deepSearchRoot != null &&
      await deepSearchRoot.exists()) {
    print('🔍 Searching Documents folder for SQLite files...');
    await for (final entity
        in deepSearchRoot.list(recursive: false, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        print('   ✓ Found SQLite file: ${entity.path}\n');
        return entity.path;
      }
    }

    // Also search subdirectories in Documents
    print('🔍 Searching Documents subdirectories...');
    await for (final entity
        in deepSearchRoot.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        print('   ✓ Found SQLite file: ${entity.path}\n');
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
      print('📝 Creating midi_profiles table...');
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
      print('✅ midi_profiles table created');
    } else {
      print('✅ midi_profiles table already exists');
    }

    // Check if profile_id column exists in songs table
    try {
      db.select('SELECT profile_id FROM songs LIMIT 1');
      print('✅ profile_id column exists in songs table');
    } catch (e) {
      print('📝 Adding profile_id column to songs table...');
      db.execute('ALTER TABLE songs ADD COLUMN profile_id TEXT');
      print('✅ profile_id column added to songs table');
    }

    return;
  } catch (e) {
    print('❌ Error ensuring database schema: $e');
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
