import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Simple standalone script to test importing Justchords songs
void main() async {
  // Path to the library.json file
  const libraryPath = 'examples/library.json';

  try {
    final file = File(libraryPath);
    if (!await file.exists()) {
      exit(1);
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final songsJson = data['songs'] as List<dynamic>?;
    if (songsJson == null || songsJson.isEmpty) {
      exit(1);
    }

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

      // Show a preview of the chord chart
      final lines = rawData.split('\n');
      final previewLines = lines.take(10).toList();
    }
  } catch (e, stackTrace) {
    exit(1);
  }
}
