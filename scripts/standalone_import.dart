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
  
  final libraryPath = _resolveLibraryPath(args.isNotEmpty ? args.first : null);
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
    
    // Select 20 random songs
    final random = Random();
    final availableIndices = List.generate(songsJson.length, (i) => i);
    availableIndices.shuffle(random);
    
    final selectedSongs = <Map<String, dynamic>>[];
    for (final index in availableIndices) {
      if (selectedSongs.length >= 20) break;
      
      final song = songsJson[index] as Map<String, dynamic>;
      final title = song['title'] as String? ?? '';
      final rawData = song['rawData'] as String? ?? '';
      
      if (title.isNotEmpty && rawData.isNotEmpty) {
        selectedSongs.add(song);
      }
    }
    
    print('✅ Selected ${selectedSongs.length} songs:\n');
    
    // Display selected songs
    for (var i = 0; i < selectedSongs.length; i++) {
      final song = selectedSongs[i];
      final title = song['title'] as String? ?? 'Untitled';
      final artist = song['subtitle'] as String? ?? song['artist'] as String? ?? 'Unknown';
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
      final now = DateTime.now().millisecondsSinceEpoch;
      var imported = 0;
      
      for (final songJson in selectedSongs) {
        final title = songJson['title'] as String? ?? 'Untitled';
        final artist = songJson['subtitle'] as String? ?? songJson['artist'] as String? ?? 'Unknown';
        final rawData = songJson['rawData'] as String? ?? '';
        final timeSignature = (songJson['timeSignature'] as String? ?? '4/4').replaceAll(r'\/', '/');
        final tempo = songJson['tempo'] as String?;
        
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
        
        // Convert to ChordPro
        final body = _convertToChordPro(rawData, title, artist, key, timeSignature, tempo);
        
        // Generate UUID
        final id = const Uuid().v4();
        
        // Insert into database
        db.execute('''
          INSERT INTO songs (
            id, title, artist, body, key, capo, bpm, time_signature, 
            tags, audio_file_path, notes, created_at, updated_at, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          id,
          title,
          artist,
          body,
          key,
          0, // capo
          bpm,
          timeSignature,
          null, // tags
          null, // audio_file_path
          null, // notes
          now,
          now,
          0, // is_deleted (false)
        ]);
        
        imported++;
        print('   ✓ Imported: $title');
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
  return candidates.isNotEmpty ? candidates.last : p.join(repoRoot.path, 'examples', 'library.json');
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
    await for (final entity in deepSearchRoot.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('nextchord_db.sqlite')) {
        print('   ✓ Found at: ${entity.path}\n');
        return entity.path;
      }
    }
  }

  return null;
}

/// Convert Justchords rawData to ChordPro format
String _convertToChordPro(String rawData, String title, String artist, String key, String timeSignature, String? tempo) {
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
  
  converted = converted.replaceAll(RegExp(r'# Created using SongSheet Pro:.*'), '');
  
  buffer.write(converted.trim());
  
  return buffer.toString();
}
