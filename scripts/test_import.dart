// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Simple standalone script to test importing Justchords songs
void main() async {
  print('🎵 Justchords Song Importer Test\n');

  // Path to the library.json file
  const libraryPath = 'examples/library.json';

  print('📂 Reading from: $libraryPath');

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

    print('✅ Selected ${selectedSongs.length} random songs:\n');
    print('=' * 80);

    // Display the selected songs
    for (var i = 0; i < selectedSongs.length; i++) {
      final song = selectedSongs[i];
      final title = song['title'] as String? ?? 'Untitled';
      final artist =
          song['subtitle'] as String? ?? song['artist'] as String? ?? 'Unknown';
      final rawData = song['rawData'] as String? ?? '';
      final timeSignature =
          (song['timeSignature'] as String? ?? '4/4').replaceAll(r'\/', '/');
      final tempo = song['tempo'] as String? ?? 'N/A';
      final duration = song['duration'] as String? ?? 'N/A';

      // Extract key
      String key = 'C';
      if (song['keyChord'] != null) {
        final keyChord = song['keyChord'] as Map<String, dynamic>;
        key = keyChord['key'] as String? ?? 'C';
        final isMinor = keyChord['minor'] as bool? ?? false;
        if (isMinor) {
          key = '$key minor';
        }
      }

      print('\n${i + 1}. "$title" by $artist');
      print(
          '   Key: $key | Tempo: $tempo BPM | Time: $timeSignature | Duration: $duration');
      print('   Raw data length: ${rawData.length} characters');

      // Show a preview of the chord chart
      final lines = rawData.split('\n');
      final previewLines = lines.take(10).toList();
      print('   Preview (first 10 lines):');
      for (final line in previewLines) {
        final displayLine =
            line.length > 70 ? '${line.substring(0, 70)}...' : line;
        print('   | $displayLine');
      }
      if (lines.length > 10) {
        print('   | ... (${lines.length - 10} more lines)');
      }
      print('   ${'-' * 76}');
    }

    print('\n${'=' * 80}');
    print('\n✅ Import test completed successfully!');
    print(
        '\n📝 These songs can be imported into NextChord with the following structure:');
    print('   - Title and Artist from the JSON');
    print('   - Key from keyChord.key field');
    print('   - BPM from tempo field');
    print('   - Time signature from timeSignature field');
    print('   - Chord chart from rawData field (needs ChordPro conversion)');
    print('   - Tags: ["imported", "justchords"]');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
