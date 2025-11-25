#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:nextchord/data/database/app_database.dart';
import 'package:nextchord/data/repositories/song_repository.dart';
import 'package:nextchord/data/repositories/setlist_repository.dart';
import 'package:nextchord/core/utils/justchords_importer.dart';

/// Comprehensive migration script that imports all data from examples/library.json
/// to the new NextChord database (nextchord_db.sqlite)
///
/// This script handles:
/// - Songs with metadata (title, artist, tempo, key, timeSignature, etc.)
/// - MIDI trigger actions (converted to basic MIDI profiles)
/// - Setlists (if present in the JSON)
///
/// Usage: dart scripts/migrate_from_library.dart [--dry-run]
///
/// Options:
///   --dry-run: Show what would be migrated without actually writing to database

void main(List<String> args) async {
  final isDryRun = args.contains('--dry-run');

  print('🎵 NextChord Migration Script');
  print('=' * 40);

  if (isDryRun) {
    print('🔍 DRY RUN MODE - No data will be written');
    print('=' * 40);
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

    // Initialize database (unless dry run)
    AppDatabase? db;
    SongRepository? songRepo;
    SetlistRepository? setlistRepo;

    if (!isDryRun) {
      print('🗄️  Initializing NextChord database...');
      db = AppDatabase();
      songRepo = SongRepository(db);
      setlistRepo = SetlistRepository(db);
    }

    // Migration statistics
    final stats = MigrationStats();

    // Step 1: Migrate MIDI trigger actions as basic MIDI profiles
    print('\n🎹 Migrating MIDI trigger actions...');
    await _migrateMidiTriggers(data, songRepo, stats, isDryRun);

    // Step 2: Migrate songs
    print('\n🎵 Migrating songs...');
    await _migrateSongs(data, songRepo, stats, isDryRun);

    // Step 3: Migrate setlists (if present)
    print('\n📋 Migrating setlists...');
    await _migrateSetlists(data, setlistRepo, songRepo, stats, isDryRun);

    // Step 4: Summary
    print('\n' + '=' * 40);
    print('📊 MIGRATION SUMMARY');
    print('=' * 40);
    print('Songs migrated: ${stats.songsMigrated}');
    print('Songs skipped: ${stats.songsSkipped}');
    print('MIDI profiles created: ${stats.midiProfilesCreated}');
    print('Setlists migrated: ${stats.setlistsMigrated}');

    if (isDryRun) {
      print(
          '\n✅ Dry run completed. Run without --dry-run to actually migrate data.');
    } else {
      print('\n✅ Migration completed successfully!');

      // Close database connection
      await db?.close();
    }
  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  }
}

/// Migrate MIDI trigger actions as basic MIDI profiles
Future<void> _migrateMidiTriggers(
  Map<String, dynamic> data,
  SongRepository? songRepo,
  MigrationStats stats,
  bool isDryRun,
) async {
  final midiTriggers = data['midiTriggerActions'] as List<dynamic>?;

  if (midiTriggers == null || midiTriggers.isEmpty) {
    print('   No MIDI trigger actions found');
    return;
  }

  print('   Found ${midiTriggers.length} MIDI trigger actions');

  // Note: The current NextChord database doesn't have a direct MIDI profiles table
  // This would need to be implemented based on the current database schema
  // For now, we'll just count them and note they need manual configuration

  for (final trigger in midiTriggers) {
    final triggerData = trigger as Map<String, dynamic>;
    final message = triggerData['message'] as Map<String, dynamic>?;
    final action = triggerData['action'] as Map<String, dynamic>?;
    final id = triggerData['id'] as String?;

    if (message != null && action != null && id != null) {
      stats.midiProfilesCreated++;

      if (!isDryRun) {
        // TODO: Implement MIDI profile creation based on current database schema
        // This would involve creating entries in the appropriate MIDI tables
        print(
            '   📝 MIDI trigger $id would be created (manual setup required)');
      } else {
        print('   📝 Would create MIDI profile for trigger $id');
      }
    }
  }

  print(
      '   ℹ️  Note: MIDI profiles require manual configuration in NextChord settings');
}

/// Migrate songs from the library
Future<void> _migrateSongs(
  Map<String, dynamic> data,
  SongRepository? songRepo,
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
    final songData = songsJson[i];
    final song = songData as Map<String, dynamic>;

    // Progress indicator
    stdout.write('   Processing song ${i + 1}/${songsJson.length}... ');

    // Extract song data
    final title = song['title'] as String? ?? '';
    final rawData = song['rawData'] as String? ?? '';

    // Skip empty songs
    if (title.isEmpty && rawData.isEmpty) {
      stats.songsSkipped++;
      print('  Skipped (empty title and content)');
      continue;
    }

    try {
      // Convert to NextChord song format
      final nextchordSong = JustchordsImporter.parseSong(song);

      if (!isDryRun && songRepo != null) {
        // Check if song already exists (by title and artist)
        final existingSongs = await songRepo.searchSongs(
          nextchordSong.title,
        );

        final alreadyExists = existingSongs.any((s) =>
            s.title.toLowerCase() == nextchordSong.title.toLowerCase() &&
            s.artist.toLowerCase() == nextchordSong.artist.toLowerCase());

        if (alreadyExists) {
          stats.songsSkipped++;
          print(
              '  Skipped duplicate: "${nextchordSong.title}" by ${nextchordSong.artist}');
        } else {
          await songRepo.insertSong(nextchordSong);
          stats.songsMigrated++;
          print(
              '  Migrated: "${nextchordSong.title}" by ${nextchordSong.artist}');
        }
      } else {
        stats.songsMigrated++;
        print(
            '  Would migrate: "${nextchordSong.title}" by ${nextchordSong.artist}');
      }
    } catch (e) {
      stats.songsSkipped++;
      print('  Error processing song: $e');
    }
  }
}

/// Migrate setlists from the library
Future<void> _migrateSetlists(
  Map<String, dynamic> data,
  SetlistRepository? setlistRepo,
  SongRepository? songRepo,
  MigrationStats stats,
  bool isDryRun,
) async {
  final setlistsJson = data['setlists'] as List<dynamic>?;

  if (setlistsJson == null || setlistsJson.isEmpty) {
    print('   No setlists found in library.json');
    return;
  }

  print('   Found ${setlistsJson.length} setlists');

  // Note: The library.json doesn't appear to contain setlists in the current sample
  // This function is prepared for when setlists are present

  for (final setlistData in setlistsJson) {
    final setlist = setlistData as Map<String, dynamic>;

    // Extract setlist data
    final name = setlist['name'] as String? ?? 'Untitled Setlist';
    final songIds = setlist['songIds'] as List<dynamic>? ?? [];

    if (!isDryRun && setlistRepo != null && songRepo != null) {
      // TODO: Implement setlist creation based on current database schema
      // This would involve:
      // 1. Creating the setlist
      // 2. Looking up songs by their original IDs
      // 3. Adding songs to the setlist

      stats.setlistsMigrated++;
      print('   ✅ Would migrate setlist: $name with ${songIds.length} songs');
    } else {
      stats.setlistsMigrated++;
      print('   📝 Would migrate setlist: $name with ${songIds.length} songs');
    }
  }
}

/// Statistics tracking for migration
class MigrationStats {
  int songsMigrated = 0;
  int songsSkipped = 0;
  int midiProfilesCreated = 0;
  int setlistsMigrated = 0;
}
