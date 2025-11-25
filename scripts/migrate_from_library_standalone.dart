#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

/// Standalone migration script that imports all data from examples/library.json
/// to the new NextChord database (nextchord_db.sqlite) without Flutter dependencies
///
/// Usage: dart scripts/migrate_from_library_standalone.dart [--dry-run]

void main(List<String> args) async {
  final isDryRun = args.contains('--dry-run');

  print('🎵 NextChord Migration Script (Standalone)');
  print('=' * 50);

  if (isDryRun) {
    print('🔍 DRY RUN MODE - No data will be written');
    print('=' * 50);
  }

  try {
    // Path to the library.json file
    const libraryPath = 'examples/library.json';

    // Verify the library file exists
    final libraryFile = File(libraryPath);
    if (!await libraryFile.exists()) {
      print('❌ Error: Library file not found at $libraryPath');
      exit(1);
    }

    // Read and parse the JSON
    print('📖 Reading library.json...');
    final jsonString = await libraryFile.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Database path - use actual NextChord app database location
    final dbPath = Platform.isMacOS
        ? '${Platform.environment['HOME']}/Library/Containers/us.antonovich.nextchord/Data/Documents/nextchord_db.sqlite'
        : 'nextchord_db.sqlite'; // Fallback for other platforms

    // Open database (unless dry run)
    Database? db;

    if (!isDryRun) {
      print('🗄️  Opening NextChord database: $dbPath');
      db = sqlite3.open(dbPath);

      // Initialize database schema if needed
      _initializeDatabase(db);
    }

    // Migration statistics
    final stats = MigrationStats();

    // Step 1: Analyze library structure
    print('\n📋 Analyzing library structure...');
    _analyzeLibraryStructure(data, stats);

    // Step 2: Migrate songs first (needed for UUID mapping)
    print('\n🎵 Migrating songs...');
    await _migrateSongs(data, db, stats, isDryRun);

    // Step 3: Migrate MIDI profiles
    print('\n🎹 Migrating MIDI profiles...');
    await _migrateMidiProfiles(data, db, stats, isDryRun);

    // Step 4: Migrate pedal mappings
    print('\n🎹 Migrating pedal mappings...');
    await _migratePedalMappings(data, db, stats, isDryRun);

    // Step 5: Migrate playlists (setlists) - needs song UUID mapping
    print('\n📋 Migrating playlists (setlists)...');
    await _migratePlaylists(data, db, stats, isDryRun);

    // Step 6: Summary
    print('\n' + '=' * 50);
    print('📊 MIGRATION SUMMARY');
    print('=' * 50);
    print('Songs migrated: ${stats.songsMigrated}');
    print('Songs skipped: ${stats.songsSkipped}');
    print('Errors encountered: ${stats.errors}');
    print('');
    print('📋 LIBRARY CONTENTS FOUND:');
    print('Songs: ${stats.songsFound}');
    print('MIDI trigger actions: ${stats.midiTriggerActions}');
    print('Pedal mappings: ${stats.pedalMappings}');
    print('MIDI profiles: ${stats.midiProfiles}');
    print('Setlists: ${stats.setlists}');
    print('');
    print('🎹 MIGRATION RESULTS:');
    print('MIDI profiles migrated: ${stats.midiProfilesMigrated}');
    print('Pedal mappings migrated: ${stats.pedalMappingsMigrated}');
    print('Setlists migrated: ${stats.setlistsMigrated}');
    print('');

    // Show songs with MIDI profiles
    if (stats.profileToSongs.isNotEmpty) {
      print('🎵 SONGS WITH MIDI PROFILES:');
      stats.profileToSongs.forEach((profileName, songs) {
        if (songs.isNotEmpty) {
          print('  $profileName (${songs.length} songs):');
          songs.forEach((song) => print('    • $song'));
        }
      });
      print('');
    }

    print('🎹 MIDI DATA NOTES:');
    print('• MIDI trigger actions found but require manual setup in NextChord');
    print('• MIDI profiles imported from midiLibraryMessages');
    print('• MIDI profile assignments applied to songs via midiAppearMessage');
    print('• Pedal mappings imported and ready for MIDI pedal implementation');
    print('• No setlists found in library.json');

    if (isDryRun) {
      print(
          '\n✅ Dry run completed. Run without --dry-run to actually migrate data.');
    } else {
      print('\n✅ Migration completed successfully!');
      db?.dispose();
    }
  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  }
}

/// Analyze library structure and report what data types are available
void _analyzeLibraryStructure(Map<String, dynamic> data, MigrationStats stats) {
  // Count songs
  final songs = data['songs'] as List<dynamic>?;
  stats.songsFound = songs?.length ?? 0;
  print('   Found ${stats.songsFound} songs');

  // Count MIDI trigger actions
  final midiTriggers = data['midiTriggerActions'] as List<dynamic>?;
  stats.midiTriggerActions = midiTriggers?.length ?? 0;
  if (stats.midiTriggerActions > 0) {
    print('   Found ${stats.midiTriggerActions} MIDI trigger actions');
  }

  // Count pedal mappings
  final pedalMappings = data['pedalMapping'] as List<dynamic>?;
  stats.pedalMappings = pedalMappings?.length ?? 0;
  if (stats.pedalMappings > 0) {
    print('   Found ${stats.pedalMappings} pedal mappings');
  }

  // Check for MIDI profiles in midiLibraryMessages
  final midiLibraryMessages = data['midiLibraryMessages'] as List<dynamic>?;
  stats.midiProfiles = midiLibraryMessages?.length ?? 0;
  if (stats.midiProfiles > 0) {
    print(
        '   Found ${stats.midiProfiles} MIDI profiles in midiLibraryMessages');
  }

  // Check for playlists (setlists)
  final playlists = data['playlists'] as List<dynamic>?;
  stats.setlists = playlists?.length ?? 0;
  if (stats.setlists > 0) {
    print('   Found ${stats.setlists} playlists (setlists)');
  }

  print('   ✅ Library analysis complete');
}

/// Initialize database schema
void _initializeDatabase(Database db) {
  print('   Initializing database schema...');

  // Create songs table
  db.execute('''
    CREATE TABLE IF NOT EXISTS songs (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      body TEXT NOT NULL,
      key TEXT NOT NULL DEFAULT 'C',
      capo INTEGER NOT NULL DEFAULT 0,
      bpm INTEGER NOT NULL DEFAULT 120,
      time_signature TEXT NOT NULL DEFAULT '4/4',
      tags TEXT NOT NULL DEFAULT '[]',
      audio_file_path TEXT,
      notes TEXT,
      profile_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Create pedal_mappings table
  db.execute('''
    CREATE TABLE IF NOT EXISTS pedal_mappings (
      id TEXT PRIMARY KEY,
      key TEXT NOT NULL,
      action TEXT NOT NULL,
      description TEXT,
      is_enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Create midi_profiles table
  db.execute('''
    CREATE TABLE IF NOT EXISTS midi_profiles (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      program_change_number INTEGER,
      control_changes TEXT DEFAULT '[]',
      timing INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Create setlists table
  db.execute('''
    CREATE TABLE IF NOT EXISTS setlists (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      items TEXT, -- JSON array of SetlistItems
      notes TEXT,
      image_path TEXT,
      setlist_specific_edits_enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''');

  print('   ✅ Database schema initialized');
}

/// Migrate MIDI profiles from the library
Future<void> _migrateMidiProfiles(
  Map<String, dynamic> data,
  Database? db,
  MigrationStats stats,
  bool isDryRun,
) async {
  final midiProfilesJson = data['midiLibraryMessages'] as List<dynamic>?;

  if (midiProfilesJson == null || midiProfilesJson.isEmpty) {
    print('   No MIDI profiles found');
    return;
  }

  print('   Found ${midiProfilesJson.length} MIDI profiles');

  for (int i = 0; i < midiProfilesJson.length; i++) {
    final profileData = midiProfilesJson[i];
    final profile = profileData as Map<String, dynamic>;

    // Extract profile data
    final name = profile['name'] as String? ?? '';
    final date = profile['date'] as double?;
    final midiMessages = profile['midi'] as List<dynamic>?;

    if (name.isEmpty || midiMessages == null) {
      stats.errors++;
      print('   ❌ Invalid MIDI profile data at index $i');
      continue;
    }

    try {
      // Parse MIDI messages
      int? programChangeNumber;
      List<Map<String, dynamic>> controlChanges = [];

      for (final message in midiMessages) {
        final msg = message as Map<String, dynamic>;
        final status = msg['status'] as int? ?? 0;
        final data1 = msg['data1'] as int? ?? 0;
        final data2 = msg['data2'] as int? ?? 0;

        if (status == 192) {
          // Program Change message
          programChangeNumber = data1;
        } else if (status == 176) {
          // Control Change message
          controlChanges.add({
            'controller': data1, // Use 'controller' not 'cc'
            'value': data2,
            'label': null,
          });
        }
      }

      // Generate profile ID and store mapping
      final profileId = _generateProfileId(name, date);
      final originalUuid = profile['id'] as String? ?? '';

      // Store mapping from original UUID to profile name (not new ID)
      if (originalUuid.isNotEmpty) {
        stats.profileNameToId[originalUuid] =
            name; // Store name, not generated ID
        stats.profileToSongs[name] = [];
        ; // Use name as key
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final controlChangesJson = jsonEncode(controlChanges);

      if (!isDryRun && db != null) {
        // Insert MIDI profile
        db.execute('''
          INSERT INTO midi_profiles (
            id, name, program_change_number, control_changes, timing, notes, 
            created_at, updated_at, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          profileId,
          name,
          programChangeNumber,
          controlChangesJson,
          0, // timing disabled
          null, // no notes
          now,
          now,
          0, // not deleted
        ]);

        stats.midiProfilesMigrated++;
        print(
            '   ✅ Migrated MIDI profile: $name (PC: ${programChangeNumber ?? 'none'}, CC: ${controlChanges.length})');
      } else {
        stats.midiProfilesMigrated++;
        print(
            '   📝 Would migrate MIDI profile: $name (PC: ${programChangeNumber ?? 'none'}, CC: ${controlChanges.length})');
      }
    } catch (e) {
      stats.errors++;
      print('   ❌ Error migrating MIDI profile: $e');
    }
  }
}

/// Generate a consistent profile ID
String _generateProfileId(String name, double? date) {
  final combined =
      '${name}_${date ?? 0}_${DateTime.now().millisecondsSinceEpoch}';
  return combined.hashCode.abs().toString();
}

/// Migrate pedal mappings from the library
Future<void> _migratePedalMappings(
  Map<String, dynamic> data,
  Database? db,
  MigrationStats stats,
  bool isDryRun,
) async {
  final pedalMappingsJson = data['pedalMapping'] as List<dynamic>?;

  if (pedalMappingsJson == null || pedalMappingsJson.isEmpty) {
    print('   No pedal mappings found');
    return;
  }

  print('   Found ${pedalMappingsJson.length} pedal mappings');

  for (int i = 0; i < pedalMappingsJson.length; i++) {
    final mappingData = pedalMappingsJson[i];
    final mapping = mappingData as Map<String, dynamic>;

    // Extract mapping data
    final key = mapping['key'] as String? ?? '';
    final action = mapping['action'] as Map<String, dynamic>?;
    final id = mapping['id'] as String?;

    if (key.isEmpty || action == null || id == null) {
      stats.errors++;
      print('   ❌ Invalid pedal mapping data at index $i');
      continue;
    }

    try {
      // Convert action to JSON string
      final actionJson = jsonEncode(action);

      // Create description based on action
      String description = 'Unknown action';
      if (action.containsKey('nextSongSection')) {
        description = 'Next song section';
      } else if (action.containsKey('previousSongSection')) {
        description = 'Previous song section';
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      if (!isDryRun && db != null) {
        // Insert pedal mapping
        db.execute('''
          INSERT INTO pedal_mappings (
            id, key, action, description, is_enabled, created_at, updated_at, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          id,
          key,
          actionJson,
          description,
          1, // enabled
          now,
          now,
          0, // not deleted
        ]);

        stats.pedalMappingsMigrated++;
        print('   ✅ Migrated pedal mapping: $key -> $description');
      } else {
        stats.pedalMappingsMigrated++;
        print('   📝 Would migrate pedal mapping: $key -> $description');
      }
    } catch (e) {
      stats.errors++;
      print('   ❌ Error migrating pedal mapping: $e');
    }
  }
}

/// Migrate songs from the library
Future<void> _migrateSongs(
  Map<String, dynamic> data,
  Database? db,
  MigrationStats stats,
  bool isDryRun,
) async {
  final songsJson = data['songs'] as List<dynamic>?;

  if (songsJson == null || songsJson.isEmpty) {
    print('   No songs found');
    return;
  }

  print('   Found ${songsJson.length} songs');

  for (int i = 0; i < songsJson.length; i++) {
    final song = songsJson[i] as Map<String, dynamic>;

    // Progress indicator
    stdout.write('   Processing song ${i + 1}/${songsJson.length}... ');

    try {
      // Extract song data
      final title = song['title'] as String? ?? '';
      final artist =
          song['artist'] as String? ?? song['subtitle'] as String? ?? '';
      final rawData = song['rawData'] as String? ?? '';
      final midiAppearMessage = song['midiAppearMessage'] as String?;
      final tempo = song['tempo'] as String?;
      final duration = song['duration'] as String?;
      final originalSongId =
          song['id'] as String?; // Original UUID for playlist mapping

      // Generate song ID first
      final songId = _generateSongId(title, artist);

      // Store original UUID to new ID mapping for playlists
      if (originalSongId != null) {
        stats.originalSongUuidToNewId[originalSongId] = songId;
      }

      // Check for MIDI profile assignment
      String? profileName;
      if (midiAppearMessage != null && midiAppearMessage.isNotEmpty) {
        profileName = stats.profileNameToId[midiAppearMessage];
        if (profileName != null) {
          stats.profileToSongs[profileName]
              ?.add(title.isEmpty ? 'Untitled Song' : title);
        }
      }

      // Extract key information
      final keyChord = song['keyChord'] as Map<String, dynamic>?;
      final key = keyChord?['key'] as String? ?? 'C';

      final timeSignature =
          (song['timeSignature'] as String? ?? '4/4').replaceAll(r'\/', '/');

      // Skip empty songs
      if (title.isEmpty && rawData.isEmpty) {
        stats.songsSkipped++;
        print('⏭️  Skipped (empty title and content)');
        continue;
      }

      // Convert rawData to ChordPro format
      final body =
          _convertToChordPro(rawData, title, artist, key, timeSignature, tempo);

      // Parse BPM from tempo string
      int bpm = 120;
      if (tempo != null && tempo.isNotEmpty) {
        try {
          bpm = int.parse(tempo);
        } catch (_) {
          bpm = 120;
        }
      }

      // Create notes if duration is provided
      final notes = duration != null ? 'Duration: $duration' : null;

      final now = DateTime.now().millisecondsSinceEpoch;

      if (!isDryRun && db != null) {
        // Check if song already exists
        final existing = db.select('''
          SELECT COUNT(*) as count FROM songs 
          WHERE title = ? AND artist = ?
        ''', [
          title.isEmpty ? 'Untitled Song' : title,
          artist.isEmpty ? 'Unknown Artist' : artist
        ]);

        if (existing.first['count'] > 0) {
          stats.songsSkipped++;
          print('⏭️  Skipped duplicate: "$title" by $artist');
        } else {
          // Insert song
          db.execute('''
            INSERT INTO songs (
              id, title, artist, body, key, capo, bpm, time_signature,
              tags, audio_file_path, notes, profile_id, created_at, updated_at, is_deleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            songId,
            title.isEmpty ? 'Untitled Song' : title,
            artist.isEmpty ? 'Unknown Artist' : artist,
            body,
            key,
            0, // capo
            bpm,
            timeSignature,
            '[]', // tags (empty JSON array)
            null, // audio_file_path
            notes,
            profileName,
            now,
            now,
            0, // is_deleted = 0 (not deleted)
          ]);

          stats.songsMigrated++;
          print('✅ Migrated: "$title" by $artist');
        }
      } else {
        stats.songsMigrated++;
        print('📝 Would migrate: "$title" by $artist');
      }
    } catch (e) {
      stats.errors++;
      print('❌ Error: $e');
    }
  }
}

/// Convert Justchords rawData format to ChordPro format
String _convertToChordPro(String rawData, String title, String artist,
    String key, String timeSignature, String? tempo) {
  final buffer = StringBuffer();

  // Add metadata directives
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

  buffer.writeln();

  // Convert the rawData format to ChordPro
  String converted = rawData;

  // Convert section markers like [Verse], [Chorus], [Bridge], etc.
  converted = converted.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]'),
    (match) {
      final section = match.group(1)!;
      // Check if it's a section label (not a chord)
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
      // Otherwise, assume it's a chord and keep it as is
      return '[$section]';
    },
  );

  buffer.write(converted);
  return buffer.toString();
}

/// Generate a consistent song ID
String _generateSongId(String title, String artist) {
  final combined =
      '${title}_${artist}_${DateTime.now().millisecondsSinceEpoch}';
  return combined.hashCode.abs().toString();
}

/// Migrate playlists (setlists) from the library
Future<void> _migratePlaylists(
  Map<String, dynamic> data,
  Database? db,
  MigrationStats stats,
  bool isDryRun,
) async {
  final playlistsJson = data['playlists'] as List<dynamic>?;

  if (playlistsJson == null || playlistsJson.isEmpty) {
    print('   No playlists found');
    return;
  }

  print('   Found ${playlistsJson.length} playlists');

  for (int i = 0; i < playlistsJson.length; i++) {
    final playlistData = playlistsJson[i];
    final playlist = playlistData as Map<String, dynamic>;

    try {
      // Extract playlist data
      final separateSongSettings =
          playlist['separateSongSettings'] as bool? ?? false;
      final arrangement = playlist['arrangement'] as List<dynamic>? ?? [];
      final playlistTitle =
          playlist['title'] as String? ?? 'Imported Playlist ${i + 1}';

      // Generate setlist ID and use actual playlist title
      final setlistId = _generateSetlistId(i);
      final setlistName = playlistTitle;

      final now = DateTime.now().millisecondsSinceEpoch;

      if (!isDryRun && db != null) {
        // Transform arrangement to match app's expected format
        final transformedItems = arrangement.map((item) {
          final itemMap = item as Map<String, dynamic>;
          final originalSongId = itemMap['id'] as String?;
          final newSongId = originalSongId != null
              ? stats.originalSongUuidToNewId[originalSongId]
              : null;
          final capo = itemMap['capo'] as int? ?? 0;
          final order = arrangement.indexOf(item);

          // Transform to app's expected format
          return {
            'type': 'song',
            'songId': newSongId ?? originalSongId ?? '',
            'order': order,
            'transposeSteps':
                0, // App uses transposeSteps, not transpose string
            'capo': capo,
          };
        }).toList();

        // Insert setlist
        db.execute('''
          INSERT INTO setlists (
            id, name, items, notes, image_path, setlist_specific_edits_enabled, 
            created_at, updated_at, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          setlistId,
          setlistName,
          jsonEncode(transformedItems), // Store transformed items as JSON
          'Imported from Justchords library',
          null, // no image
          separateSongSettings ? 1 : 0,
          now,
          now,
          0, // not deleted
        ]);

        stats.setlistsMigrated++;
        print(
            '   ✅ Migrated playlist: $setlistName (${arrangement.length} songs)');
      } else {
        stats.setlistsMigrated++;
        print(
            '   📝 Would migrate playlist: $setlistName (${arrangement.length} songs)');
      }
    } catch (e) {
      stats.errors++;
      print('   ❌ Error migrating playlist: $e');
    }
  }
}

/// Generate a consistent setlist ID
String _generateSetlistId(int index) {
  final combined = 'setlist_${index}_${DateTime.now().millisecondsSinceEpoch}';
  return combined.hashCode.abs().toString();
}

/// Migration statistics
class MigrationStats {
  int songsMigrated = 0;
  int songsSkipped = 0;
  int errors = 0;

  // Library contents tracking
  int songsFound = 0;
  int midiTriggerActions = 0;
  int pedalMappings = 0;
  int midiProfiles = 0;
  int setlists = 0;

  // Migration counts
  int pedalMappingsMigrated = 0;
  int midiProfilesMigrated = 0;
  int setlistsMigrated = 0;

  // MIDI profile assignments
  Map<String, String> profileNameToId = {};
  Map<String, List<String>> profileToSongs = {};

  // Song UUID mapping for playlists
  Map<String, String> originalSongUuidToNewId = {};
}
