// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// Standalone import script that works without Flutter
/// Directly writes to the SQLite database
void main(List<String> args) async {
  print('🎵 Justchords to NextChord - Standalone Importer\n');

  final cliOptions = _parseCliOptions(args);
  final libraryPath = _resolveLibraryPath(cliOptions.libraryPath);
  final dbPath = await _findDatabasePath();

  if (dbPath == null) {
    print('❌ Could not find NextChord database.');
    print('💡 Run the app at least once to create the database.');
    exit(1);
  }

  print('📂 Reading from: $libraryPath');
  print('💾 Database: $dbPath\n');

  try {
    // Read and parse library.json
    final file = File(libraryPath);
    if (!await file.exists()) {
      print('❌ Error: File not found at $libraryPath');
      exit(1);
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final songsJson = data['songs'] as List<dynamic>?;
    if (songsJson == null || songsJson.isEmpty) {
      print('❌ Error: No songs found in library.json');
      exit(1);
    }

    print('📊 Total songs in library: ${songsJson.length}\n');

    // Extract MIDI profiles for import
    final midiProfiles = <String, List<Map<String, dynamic>>>{};
    final midiLibraryMessages = data['midiLibraryMessages'] as List<dynamic>?;
    if (midiLibraryMessages != null) {
      for (final profile
          in midiLibraryMessages.whereType<Map<String, dynamic>>()) {
        final id = profile['id'] as String?;
        final midi = profile['midi'] as List<dynamic>?;
        if (id != null && midi != null) {
          midiProfiles[id] = midi.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    print('🎹 Found ${midiProfiles.length} MIDI profiles\n');

    final selectedSongs = <Map<String, dynamic>>[];
    if (cliOptions.titleFilter != null) {
      final normalizedFilter = cliOptions.titleFilter!.trim().toLowerCase();
      print('🎯 Filtering titles containing: "${cliOptions.titleFilter}"');
      for (final song in songsJson.whereType<Map<String, dynamic>>()) {
        final title = (song['title'] as String? ?? '').trim();
        final rawData = song['rawData'] as String? ?? '';
        if (title.isEmpty || rawData.isEmpty) continue;
        if (title.toLowerCase().contains(normalizedFilter)) {
          selectedSongs.add(song);
        }
      }

      if (selectedSongs.isEmpty) {
        print(
            '❌ No songs matched the title filter "${cliOptions.titleFilter}".');
        exit(1);
      }
    } else {
      // Select a random subset of songs when no filter is provided
      final targetCount = cliOptions.songsToImport;
      final random = Random();
      final availableIndices = List.generate(songsJson.length, (i) => i)
        ..shuffle(random);

      for (final index in availableIndices) {
        if (selectedSongs.length >= targetCount) break;

        final song = songsJson[index] as Map<String, dynamic>;
        final title = song['title'] as String? ?? '';
        final rawData = song['rawData'] as String? ?? '';

        if (title.isNotEmpty && rawData.isNotEmpty) {
          selectedSongs.add(song);
        }
      }
    }

    print('✅ Selected ${selectedSongs.length} songs:\n');

    // Display selected songs
    for (var i = 0; i < selectedSongs.length; i++) {
      final song = selectedSongs[i];
      final title = song['title'] as String? ?? 'Untitled';
      final artist =
          song['subtitle'] as String? ?? song['artist'] as String? ?? 'Unknown';
      print('${i + 1}. "$title" by $artist');
    }

    print('\n💾 Would you like to import these songs to the database? (y/n)');
    final response = stdin.readLineSync()?.toLowerCase();

    if (response != 'y' && response != 'yes') {
      print('\n❌ Import cancelled.');
      exit(0);
    }

    print('\n📝 Importing songs...\n');

    // Open database
    final db = sqlite3.open(dbPath);

    try {
      // Ensure database schema is up to date
      print('🔍 Validating database schema...');
      await _ensureDatabaseSchema(db);
      print('✅ Database schema validated\n');

      // Import MIDI profiles first
      if (midiProfiles.isNotEmpty) {
        print('🎹 Importing MIDI profiles...');
        await _importMidiProfiles(db, data);
        print('✅ MIDI profiles imported\n');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      var imported = 0;

      for (final songJson in selectedSongs) {
        final title = songJson['title'] as String? ?? 'Untitled';
        final artist = songJson['subtitle'] as String? ??
            songJson['artist'] as String? ??
            'Unknown';
        final rawData = songJson['rawData'] as String? ?? '';
        final timeSignature = (songJson['timeSignature'] as String? ?? '4/4')
            .replaceAll(r'\/', '/');
        final tempo = songJson['tempo'] as String?;
        final duration = songJson['duration'] as String?;
        final tags =
            (songJson['tags'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        final tagsJson = jsonEncode(tags);

        // Extract key
        String key = 'C';
        if (songJson['keyChord'] != null) {
          final keyChord = songJson['keyChord'] as Map<String, dynamic>;
          key = keyChord['key'] as String? ?? 'C';
        }

        // Parse BPM
        int bpm = 120;
        if (tempo != null && tempo.isNotEmpty) {
          try {
            bpm = int.parse(tempo);
          } catch (_) {
            bpm = 120;
          }
        }

        // Check for MIDI data in song entry
        final profileId = _extractProfileId(songJson);

        // Convert to ChordPro
        final body = _convertToChordPro(
            rawData, title, artist, key, timeSignature, tempo, duration);

        // Generate UUID
        final id = const Uuid().v4();

        // Insert into database with profile_id if present
        db.execute('''
          INSERT INTO songs (
            id, title, artist, body, key, capo, bpm, time_signature, 
            tags, audio_file_path, notes, created_at, updated_at, is_deleted, profile_id
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          id,
          title,
          artist,
          body,
          key,
          0, // capo
          bpm,
          timeSignature,
          tagsJson,
          null, // audio_file_path
          null, // notes
          now,
          now,
          0, // is_deleted (false)
          profileId, // profile_id (null if no MIDI profile)
        ]);

        if (profileId != null) {
          print('   ✓ Imported: $title (with MIDI profile)');
        } else {
          print('   ✓ Imported: $title');
        }
        imported++;
      }

      print('\n✅ Successfully imported $imported songs!');
    } finally {
      db.dispose();
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

String _resolveLibraryPath(String? cliArgument) {
  final env = Platform.environment;
  final overrides = <String?>[
    cliArgument,
    env['NEXTCHORD_LIBRARY_PATH'],
  ];

  final candidates = <String>[];

  for (final override in overrides) {
    if (override == null || override.trim().isEmpty) continue;
    final resolved = p.isAbsolute(override)
        ? p.normalize(override)
        : p.normalize(p.join(Directory.current.path, override));
    candidates.add(resolved);
  }

  final scriptFile = File(Platform.script.toFilePath());
  final scriptsDir = scriptFile.parent;
  final repoRoot = scriptsDir.parent;

  candidates.add(p.join(Directory.current.path, 'examples', 'library.json'));
  candidates.add(p.join(repoRoot.path, 'examples', 'library.json'));

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  // Fall back to the last candidate so the error message shows the repo path
  return candidates.isNotEmpty
      ? candidates.last
      : p.join(repoRoot.path, 'examples', 'library.json');
}

class _CliOptions {
  final String? libraryPath;
  final String? titleFilter;
  final int songsToImport;

  const _CliOptions({
    this.libraryPath,
    this.titleFilter,
    this.songsToImport = 20,
  });
}

_CliOptions _parseCliOptions(List<String> args) {
  String? libraryPath;
  String? titleFilter;
  int? songsToImport;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '--title' || arg == '-t') {
      if (i + 1 >= args.length) {
        print('❌ Missing value for --title option.');
        exit(64);
      }
      titleFilter = args[++i];
      continue;
    }

    if (arg.startsWith('--title=')) {
      titleFilter = arg.substring('--title='.length);
      continue;
    }

    if (arg == '--songs' || arg == '-n') {
      if (i + 1 >= args.length) {
        print('❌ Missing value for --songs option.');
        exit(64);
      }
      final value = args[++i];
      final parsed = int.tryParse(value);
      if (parsed == null || parsed <= 0) {
        print(
            '❌ Invalid value for --songs: "$value". Must be a positive integer.');
        exit(64);
      }
      songsToImport = parsed;
      continue;
    }

    if (arg.startsWith('--songs=')) {
      final value = arg.substring('--songs='.length);
      final parsed = int.tryParse(value);
      if (parsed == null || parsed <= 0) {
        print(
            '❌ Invalid value for --songs: "$value". Must be a positive integer.');
        exit(64);
      }
      songsToImport = parsed;
      continue;
    }

    // Treat the first non-option argument as a custom library path
    libraryPath ??= arg;
  }

  return _CliOptions(
    libraryPath: libraryPath,
    titleFilter: titleFilter?.trim().isEmpty == true ? null : titleFilter,
    songsToImport: songsToImport ?? 20,
  );
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
    possiblePaths.addAll([
      '$userProfile\\Documents\\nextchord_db.sqlite',
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
  for (final path in possiblePaths) {
    print('   - $path');
    if (await File(path).exists()) {
      print('   ✓ Found!\n');
      return path;
    }
  }

  print('   ✗ Not found in standard locations\n');

  if (deepSearchRoot != null && await deepSearchRoot.exists()) {
    await for (final entity
        in deepSearchRoot.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('nextchord_db.sqlite')) {
        print('   ✓ Found at: ${entity.path}\n');
        return entity.path;
      }
    }
  }

  return null;
}

/// Convert Justchords rawData to ChordPro format
String _convertToChordPro(String rawData, String title, String artist,
    String key, String timeSignature, String? tempo, String? duration) {
  final buffer = StringBuffer();

  if (title.isNotEmpty) {
    buffer.writeln('{title:$title}');
  }
  if (artist.isNotEmpty) {
    buffer.writeln('{artist:$artist}');
  }
  if (key.isNotEmpty) {
    buffer.writeln('{key:$key}');
  }
  if (timeSignature.isNotEmpty) {
    buffer.writeln('{time:$timeSignature}');
  }
  if (tempo != null && tempo.isNotEmpty) {
    buffer.writeln('{tempo:$tempo}');
  }
  if (duration != null && duration.isNotEmpty) {
    buffer.writeln('{duration:$duration}');
  }

  buffer.writeln();

  // Convert section markers
  String converted = rawData;

  converted = converted.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]'),
    (match) {
      final section = match.group(1)!;
      if (section.toLowerCase().contains('verse') ||
          section.toLowerCase().contains('chorus') ||
          section.toLowerCase().contains('bridge') ||
          section.toLowerCase().contains('intro') ||
          section.toLowerCase().contains('outro') ||
          section.toLowerCase().contains('solo') ||
          section.toLowerCase().contains('instrumental') ||
          section.toLowerCase().contains('pre-chorus') ||
          section.toLowerCase().contains('ending')) {
        return '{comment:$section}';
      }
      return '[$section]';
    },
  );

  converted =
      converted.replaceAll(RegExp(r'# Created using SongSheet Pro:.*'), '');

  buffer.write(converted.trim());

  return buffer.toString();
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

/// Import MIDI profiles from library.json data
Future<void> _importMidiProfiles(Database db, Map<String, dynamic> data) async {
  try {
    final midiLibraryMessages = data['midiLibraryMessages'] as List<dynamic>?;
    if (midiLibraryMessages == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    var imported = 0;

    // Check for existing profiles
    final existingResults = db.select('SELECT id FROM midi_profiles');
    final existingProfileIds =
        existingResults.map((row) => row['id'] as String).toSet();

    for (final profile
        in midiLibraryMessages.whereType<Map<String, dynamic>>()) {
      final id = profile['id'] as String?;
      final name = profile['name'] as String?;
      final midiMessages = profile['midi'] as List<dynamic>? ?? [];

      if (id == null || midiMessages.isEmpty) continue;

      // Skip if profile already exists
      if (existingProfileIds.contains(id)) {
        print('   ⏭️  Skipping existing profile: "$name" (ID: $id)');
        continue;
      }

      // Convert raw MIDI messages to NextChord format
      final midiData = _convertMidiProfile(midiMessages);
      if (midiData == null) continue;

      final programChangeNumber = midiData['programChangeNumber'] as int?;
      final controlChanges = jsonEncode(midiData['controlChanges'] as List);
      final timing = midiData['timing'] as bool;
      final notes = midiData['notes'] as String?;

      // Insert new profile
      db.execute('''
        INSERT INTO midi_profiles (
          id, name, program_change_number, control_changes, 
          timing, notes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
        name ?? 'Imported Profile',
        programChangeNumber,
        controlChanges,
        timing ? 1 : 0,
        notes,
        now,
        now,
      ]);

      print('   ✅ Imported profile: "$name" (ID: $id)');
      imported++;
    }

    print('🎉 MIDI profile import completed! Imported: $imported');
  } catch (e) {
    print('❌ Error importing MIDI profiles: $e');
    rethrow;
  }
}

/// Convert raw MIDI messages to NextChord profile format
Map<String, dynamic>? _convertMidiProfile(List<dynamic> midiMessages) {
  if (midiMessages.isEmpty) return null;

  int? programChangeNumber;
  List<Map<String, dynamic>> controlChanges = [];
  bool timing = false;

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
      case 248: // MIDI Clock (0xF8)
        timing = true;
        break;
      default:
        // Ignore other status types for now
        break;
    }
  }

  // If no MIDI data was actually extracted, return null
  if (programChangeNumber == null && controlChanges.isEmpty && !timing) {
    return null;
  }

  // Generate notes based on the MIDI commands
  String? notes;
  final descriptionParts = <String>[];
  if (programChangeNumber != null) {
    descriptionParts.add('PC$programChangeNumber');
  }
  for (final cc in controlChanges) {
    descriptionParts.add('CC${cc['controller']}:${cc['value']}');
  }
  if (timing) {
    descriptionParts.add('MIDI Clock');
  }

  if (descriptionParts.isNotEmpty) {
    notes = 'Imported from library.json: ${descriptionParts.join(', ')}';
  }

  return {
    'programChangeNumber': programChangeNumber,
    'controlChanges': controlChanges,
    'timing': timing,
    'notes': notes,
  };
}

/// Extract profile ID from song JSON data
String? _extractProfileId(Map<String, dynamic> songJson) {
  // Check if song has a MIDI profile reference
  final profileId = songJson['midiAppearMessage'] as String?;
  return profileId;
}
