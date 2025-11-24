import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../domain/entities/song.dart';

/// Utility to import songs from Justchords library.json format
class JustchordsImporter {
  /// Convert Justchords rawData format to ChordPro format
  static String _convertToChordPro(String rawData, String title, String artist, String key, String timeSignature, String? tempo) {
    // Start with metadata directives
    final buffer = StringBuffer();
    
    if (title.isNotEmpty) {
    }
    if (artist.isNotEmpty) {
    }
    if (key.isNotEmpty) {
    }
    if (timeSignature.isNotEmpty) {
    }
    if (tempo != null && tempo.isNotEmpty) {
    }
    
    buffer.writeln();
    
    // Convert the rawData format to ChordPro
    // Justchords uses various formats, we'll do basic conversion
    String converted = rawData;
    
    // Convert {start_of_verse} and {end_of_verse} tags
    converted = converted.replaceAll('{start_of_verse}', '{start_of_verse}');
    converted = converted.replaceAll('{end_of_verse}', '{end_of_verse}');
    
    // Convert {start_of_chorus} and {end_of_chorus} tags
    converted = converted.replaceAll('{start_of_chorus}', '{start_of_chorus}');
    converted = converted.replaceAll('{end_of_chorus}', '{end_of_chorus}');
    
    // Convert section markers like [Verse], [Chorus], [Bridge], etc.
    converted = converted.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]'),
      (match) {
        final section = match.group(1)!;
        // Check if it's a chord or a section label
        if (section.contains('Verse') || section.contains('verse')) {
          return '{comment:$section}';
        } else if (section.contains('Chorus') || section.contains('chorus') || section.contains('A#horus')) {
          return '{comment:$section}';
        } else if (section.contains('Bridge') || section.contains('bridge')) {
          return '{comment:$section}';
        } else if (section.contains('Intro') || section.contains('intro')) {
          return '{comment:$section}';
        } else if (section.contains('Outro') || section.contains('outro') || section.contains('Dnding')) {
          return '{comment:$section}';
        } else if (section.contains('Solo') || section.contains('solo')) {
          return '{comment:$section}';
        } else if (section.contains('Instrumental')) {
          return '{comment:$section}';
        } else if (section.contains('Pre-Chorus') || section.contains('Pre-chorus')) {
          return '{comment:$section}';
        }
        // Otherwise, assume it's a chord and keep it as is
        return '[$section]';
      },
    );
    
    // Remove any SongSheet Pro attribution
    
    buffer.write(converted.trim());
    
    return buffer.toString();
  }
  
  /// Parse a Justchords song object and convert to NextChord Song entity
  static Song parseSong(Map<String, dynamic> justchordsSong) {
    final title = justchordsSong['title'] as String? ?? 'Untitled';
    final artist = justchordsSong['subtitle'] as String? ?? justchordsSong['artist'] as String? ?? 'Unknown Artist';
    final rawData = justchordsSong['rawData'] as String? ?? '';
    final timeSignature = (justchordsSong['timeSignature'] as String? ?? '4/4').replaceAll(r'\/', '/');
    final tempo = justchordsSong['tempo'] as String?;
    final duration = justchordsSong['duration'] as String?;
    
    // Extract key from keyChord object
    String key = 'C';
    if (justchordsSong['keyChord'] != null) {
      final keyChord = justchordsSong['keyChord'] as Map<String, dynamic>;
      key = keyChord['key'] as String? ?? 'C';
    }
    
    // Convert rawData to ChordPro format
    final body = _convertToChordPro(rawData, title, artist, key, timeSignature, tempo);
    
    // Parse BPM from tempo string
    int bpm = 120;
    if (tempo != null && tempo.isNotEmpty) {
      try {
        bpm = int.parse(tempo);
      } catch (_) {
        bpm = 120;
      }
    }
    
    final now = DateTime.now();
    
    return Song(
      id: const Uuid().v4(),
      title: title,
      artist: artist,
      body: body,
      key: key,
      capo: 0,
      bpm: bpm,
      timeSignature: timeSignature,
      tags: const ['imported', 'justchords'],
      notes: duration != null ? 'Duration: $duration' : null,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Import songs from a Justchords library.json file
  static Future<List<Song>> importFromFile(String filePath, {int? count, List<int>? indices}) async {
    final file = File(filePath);
    if (!await file.exists()) {
    }
    
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    final songsJson = data['songs'] as List<dynamic>?;
    if (songsJson == null || songsJson.isEmpty) {
      throw Exception('No songs found in library.json');
    }
    
    List<Map<String, dynamic>> selectedSongs;
    
    if (indices != null && indices.isNotEmpty) {
      // Import specific songs by index
      selectedSongs = indices
          .where((i) => i >= 0 && i < songsJson.length)
          .map((i) => songsJson[i] as Map<String, dynamic>)
          .toList();
    } else if (count != null && count > 0) {
      // Import random songs
      final random = Random();
      final availableIndices = List.generate(songsJson.length, (i) => i);
      availableIndices.shuffle(random);
      
      final numToImport = min(count, songsJson.length);
      selectedSongs = availableIndices
          .take(numToImport)
          .map((i) => songsJson[i] as Map<String, dynamic>)
          .toList();
    } else {
      // Import all songs
      selectedSongs = songsJson.cast<Map<String, dynamic>>();
    }
    
    // Filter out empty songs (songs with no title or rawData)
    selectedSongs = selectedSongs.where((song) {
      final title = song['title'] as String? ?? '';
      final rawData = song['rawData'] as String? ?? '';
      return title.isNotEmpty && rawData.isNotEmpty;
    }).toList();
    
    return selectedSongs.map((song) => parseSong(song)).toList();
  }
}
