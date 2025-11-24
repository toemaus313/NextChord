import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// Standalone setlist import script that works without Flutter
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

    // Extract playlists/setlists
    final playlists = data['playlists'] as List<dynamic>?;
    if (playlists == null || playlists.isEmpty) {
      exit(1);
    }

    // Display playlists to be imported
    for (var i = 0; i < playlists.length; i++) {
      final playlist = playlists[i] as Map<String, dynamic>;
      final id = playlist['id'] as String? ?? 'Unknown ID';
      final name = playlist['title'] as String? ?? 'Untitled Setlist';
      final songCount =
          (playlist['arrangement'] as List<dynamic>?)?.length ?? 0;
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
      // Ensure database schema is up to date
      await _ensureDatabaseSchema(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      var imported = 0;
      var skipped = 0;
      var updated = 0;

      // Check for existing playlists if not overwriting
      Set<String> existingPlaylistIds = {};
      if (!cliOptions.overwriteExisting) {
        final existingResults = db.select('SELECT id FROM setlists');
        existingPlaylistIds =
            existingResults.map((row) => row['id'] as String).toSet();
      }

      // Get all songs for ID mapping
      final songResults = db.select('SELECT id, title, artist FROM songs');
      final songMap = <String, Map<String, String>>{};
      for (final row in songResults) {
        songMap[row['id'] as String] = {
          'title': row['title'] as String,
          'artist': row['artist'] as String,
        };
      }

      // Get all songs from library.json for potential import
      final librarySongs = data['songs'] as List<dynamic>? ?? [];
      final librarySongMap = <String, Map<String, dynamic>>{};
      for (final song in librarySongs.whereType<Map<String, dynamic>>()) {
        final id = song['id'] as String?;
        if (id != null) {
          librarySongMap[id] = song;
        }
      }

      // First pass: identify and import missing songs
      final missingSongIds = <String>{};
      for (final playlistJson in playlists.whereType<Map<String, dynamic>>()) {
        final arrangement = playlistJson['arrangement'] as List<dynamic>? ?? [];
        for (final item in arrangement.whereType<Map<String, dynamic>>()) {
          final songId = item['id'] as String?;
          if (songId != null && !songMap.containsKey(songId)) {
            missingSongIds.add(songId);
          }
        }
      }

      if (missingSongIds.isNotEmpty && !cliOptions.dryRun) {
        await _importMissingSongs(db, missingSongIds, librarySongMap);

        // Refresh song map after imports
        final updatedSongResults =
            db.select('SELECT id, title, artist FROM songs');
        songMap.clear();
        for (final row in updatedSongResults) {
          songMap[row['id'] as String] = {
            'title': row['title'] as String,
            'artist': row['artist'] as String,
          };
        }
      } else if (missingSongIds.isNotEmpty && cliOptions.dryRun) {
        // DRY RUN: Would import missing songs
      }

      for (final playlistJson in playlists.whereType<Map<String, dynamic>>()) {
        final id = playlistJson['id'] as String? ?? const Uuid().v4();
        final name = playlistJson['title'] as String? ?? 'Untitled Setlist';
        final arrangement = playlistJson['arrangement'] as List<dynamic>? ?? [];

        // Skip if playlist already exists and not overwriting
        if (!cliOptions.overwriteExisting && existingPlaylistIds.contains(id)) {
          skipped++;
          continue;
        }

        // In dry run mode with missing songs, skip processing
        if (cliOptions.dryRun && missingSongIds.isNotEmpty) {
          continue;
        }

        // Convert arrangement to NextChord setlist items
        final setlistItems = <Map<String, dynamic>>[];
        var songsFound = 0;
        var songsMissing = 0;

        for (final item in arrangement.whereType<Map<String, dynamic>>()) {
          final songId = item['id'] as String?;
          final title = item['title'] as String? ?? 'Unknown Song';
          final capo = item['capo'] as int?;
          final transpose = item['transpose'] as String?;

          if (songId == null) continue;

          // Try to find song by ID first
          if (songMap.containsKey(songId)) {
            // Convert transpose string to transpose steps (e.g., "C#" -> 2 steps up)
            int transposeSteps = 0;
            if (transpose != null && transpose.isNotEmpty) {
              // Simple conversion - this could be enhanced with proper music theory
              final transposeMap = {
                'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4,
                'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8,
                'A': 9, 'A#': 10, 'Bb': 10, 'B': 11,
                'C': 0, // reference
              };
              transposeSteps = transposeMap[transpose] ?? 0;
            }

            setlistItems.add({
              'type': 'song',
              'songId': songId,
              'order': songsFound,
              'transposeSteps': transposeSteps,
              'capo': capo ?? 0,
            });
            songsFound++;
          } else {
            // Song not found in database
            songsMissing++;
          }
        }

        if (setlistItems.isEmpty) {
          skipped++;
          continue;
        }

        // Convert items to JSON for database
        final itemsJson = jsonEncode(setlistItems);

        if (cliOptions.overwriteExisting && existingPlaylistIds.contains(id)) {
          // Update existing playlist
          db.execute('''
            UPDATE setlists SET
              name = ?, items = ?, notes = ?, updated_at = ?
            WHERE id = ?
          ''', [
            name,
            itemsJson,
            'Imported from library.json',
            now,
            id,
          ]);
          updated++;
        } else {
          // Insert new playlist
          db.execute('''
            INSERT INTO setlists (
              id, name, items, notes, image_path, setlist_specific_edits_enabled,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            id,
            name,
            itemsJson,
            'Imported from library.json',
            null, // image_path
            1, // setlist_specific_edits_enabled (true)
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

/// CLI options for setlist import
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
      '$homeDir/Library/Containers/us.antonovich.troubadour/Data/Documents/troubadour_db.sqlite',
      '$homeDir/Documents/troubadour_db.sqlite',
    ]);
  } else if (Platform.isWindows) {
    final userProfile = env['USERPROFILE'] ?? homeDir;
    // Prioritize Documents folder and look for any SQLite file
    possiblePaths.addAll([
      '$userProfile\\Documents\\troubadour_db.sqlite',
      '$userProfile\\Documents\\*.sqlite', // Allow any SQLite file in Documents
      '$userProfile\\AppData\\Local\\troubadour_db.sqlite',
      '$userProfile\\AppData\\Roaming\\troubadour_db.sqlite',
    ]);
    deepSearchRoot = Directory('$userProfile\\Documents');
  } else {
    possiblePaths.addAll([
      '$homeDir/troubadour_db.sqlite',
      '$homeDir/Documents/troubadour_db.sqlite',
      '$homeDir/Documents/troubadour_db.sqlite',
    ]);
  }

  possiblePaths.add('troubadour_db.sqlite'); // Current directory fallback

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

/// Ensure database schema is up to date for setlists
Future<void> _ensureDatabaseSchema(Database db) async {
  try {
    // Check if setlists table exists
    final tables = db.select('''
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='setlists'
    ''');

    if (tables.isEmpty) {
      db.execute('''
        CREATE TABLE setlists (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          items TEXT NOT NULL,
          notes TEXT,
          image_path TEXT,
          setlist_specific_edits_enabled INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    } else {}

    // Check for and add missing columns if needed
    try {
      db.select('SELECT image_path FROM setlists LIMIT 1');
    } catch (e) {
      db.execute('ALTER TABLE setlists ADD COLUMN image_path TEXT');
    }

    try {
      db.select('SELECT setlist_specific_edits_enabled FROM setlists LIMIT 1');
    } catch (e) {
      db.execute(
          'ALTER TABLE setlists ADD COLUMN setlist_specific_edits_enabled INTEGER NOT NULL DEFAULT 1');
    }

    return;
  } catch (e) {
    rethrow;
  }
}

/// Import missing songs from library.json
Future<void> _importMissingSongs(Database db, Set<String> missingSongIds,
    Map<String, Map<String, dynamic>> librarySongMap) async {
  try {
    final now = DateTime.now().millisecondsSinceEpoch;
    var imported = 0;

    for (final songId in missingSongIds) {
      final songJson = librarySongMap[songId];
      if (songJson == null) continue;

      final title = songJson['title'] as String? ?? 'Untitled';
      final artist = songJson['subtitle'] as String? ??
          songJson['artist'] as String? ??
          'Unknown';
      final rawData = songJson['rawData'] as String? ?? '';
      final timeSignature = (songJson['timeSignature'] as String? ?? '4/4')
          .replaceAll(r'\/', '/');
      final tempo = songJson['tempo'] as String?;
      final duration = songJson['duration'] as String?;
      final tags = (songJson['tags'] as List?)?.whereType<String>().toList() ??
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
      final profileId = songJson['midiAppearMessage'] as String?;

      // Convert to ChordPro
      final body = _convertToChordPro(
          rawData, title, artist, key, timeSignature, tempo, duration);

      // Insert into database with profile_id if present
      db.execute('''
        INSERT INTO songs (
          id, title, artist, body, key, capo, bpm, time_signature, 
          tags, audio_file_path, notes, created_at, updated_at, is_deleted, profile_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        songId,
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

      imported++;
    }
  } catch (e) {
    rethrow;
  }
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
