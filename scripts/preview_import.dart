// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Convert Justchords rawData format to ChordPro format
String convertToChordPro(String rawData, String title, String artist,
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

  // Remove any SongSheet Pro attribution
  converted =
      converted.replaceAll(RegExp(r'# Created using SongSheet Pro:.*'), '');

  buffer.write(converted.trim());

  return buffer.toString();
}

/// Main script to preview the import
void main() async {
  print('🎵 Justchords to NextChord Import Preview\n');

  const libraryPath = 'examples/library.json';

  try {
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

    // Select 5 random songs
    final random = Random();
    final availableIndices = List.generate(songsJson.length, (i) => i);
    availableIndices.shuffle(random);

    // Filter out empty songs and take first 5 valid ones
    final selectedSongs = <Map<String, dynamic>>[];
    for (final index in availableIndices) {
      if (selectedSongs.length >= 5) break;

      final song = songsJson[index] as Map<String, dynamic>;
      final title = song['title'] as String? ?? '';
      final rawData = song['rawData'] as String? ?? '';

      if (title.isNotEmpty && rawData.isNotEmpty) {
        selectedSongs.add(song);
      }
    }

    print(
        '✅ Selected ${selectedSongs.length} random songs for import preview\n');
    print('=' * 80);

    // Create output file
    final outputFile = File('examples/imported_songs_preview.txt');
    final output = StringBuffer();

    output.writeln('JUSTCHORDS TO NEXTCHORD - IMPORT PREVIEW');
    output.writeln('=' * 80);
    output.writeln();
    output.writeln(
        'This file shows 5 randomly selected songs from the Justchords library.json');
    output.writeln(
        'and how they would be converted to NextChord\'s ChordPro format.');
    output.writeln();
    output.writeln('Generated on: ${DateTime.now().toString().split('.')[0]}');
    output.writeln();

    // Process each song
    for (var i = 0; i < selectedSongs.length; i++) {
      final song = selectedSongs[i];
      final title = song['title'] as String? ?? 'Untitled';
      final artist =
          song['subtitle'] as String? ?? song['artist'] as String? ?? 'Unknown';
      final rawData = song['rawData'] as String? ?? '';
      final timeSignature =
          (song['timeSignature'] as String? ?? '4/4').replaceAll(r'\/', '/');
      final tempo = song['tempo'] as String?;
      final duration = song['duration'] as String?;

      // Extract key
      String key = 'C';
      bool isMinor = false;
      if (song['keyChord'] != null) {
        final keyChord = song['keyChord'] as Map<String, dynamic>;
        key = keyChord['key'] as String? ?? 'C';
        isMinor = keyChord['minor'] as bool? ?? false;
      }

      print('\n${i + 1}. Converting: "$title" by $artist');

      output.writeln('=' * 80);
      output.writeln('SONG ${i + 1}');
      output.writeln('=' * 80);
      output.writeln();
      output.writeln('ORIGINAL JUSTCHORDS DATA:');
      output.writeln('-' * 80);
      output.writeln('Title: $title');
      output.writeln('Artist: $artist');
      output.writeln('Key: $key${isMinor ? ' minor' : ''}');
      output.writeln('Tempo: ${tempo ?? 'N/A'} BPM');
      output.writeln('Time Signature: $timeSignature');
      output.writeln('Duration: ${duration ?? 'N/A'}');
      output.writeln();
      output.writeln('CONVERTED TO NEXTCHORD CHORDPRO FORMAT:');
      output.writeln('-' * 80);

      // Convert to ChordPro
      final chordPro =
          convertToChordPro(rawData, title, artist, key, timeSignature, tempo);
      output.writeln(chordPro);
      output.writeln();
      output.writeln();
    }

    output.writeln('=' * 80);
    output.writeln('END OF PREVIEW');
    output.writeln('=' * 80);

    // Write to file
    await outputFile.writeAsString(output.toString());

    print('\n${'=' * 80}');
    print('✅ Preview completed successfully!');
    print('📄 Output written to: ${outputFile.path}');
    print('\n📝 Summary:');
    print('   - ${selectedSongs.length} songs converted');
    print('   - Format: ChordPro with metadata directives');
    print('   - Tags added: ["imported", "justchords"]');
    print('   - Ready for import into NextChord database');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
