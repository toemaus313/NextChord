/// Parser for Ultimate Guitar chord format
/// Converts Ultimate Guitar's format to ChordPro format
class UltimateGuitarParser {
  /// Converts Ultimate Guitar format to ChordPro format
  /// 
  /// Ultimate Guitar uses:
  /// - [ch]ChordName[/ch] for chords
  /// - [tab]...[/tab] for lines with chords and lyrics
  /// - [Verse], [Chorus], etc. for sections
  /// 
  /// ChordPro uses:
  /// - [ChordName] for chords
  /// - {start_of_verse}, {end_of_verse}, etc. for sections
  static String convertToChordPro(String ugContent) {
    if (ugContent.isEmpty) return '';

    String result = ugContent;

    // Remove carriage returns, normalize line endings
    result = result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Convert section markers to ChordPro format
    result = _convertSections(result);

    // Convert chord tags and tab blocks
    result = _convertChordsAndLyrics(result);

    // Clean up extra blank lines (more than 2 consecutive)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }

  /// Convert section markers like [Verse] to {start_of_verse}
  static String _convertSections(String content) {
    final sectionMap = {
      r'\[Intro\]': '{comment: Intro}',
      r'\[Verse\]': '{start_of_verse}',
      r'\[Verse 1\]': '{start_of_verse: Verse 1}',
      r'\[Verse 2\]': '{start_of_verse: Verse 2}',
      r'\[Verse 3\]': '{start_of_verse: Verse 3}',
      r'\[Chorus\]': '{start_of_chorus}',
      r'\[Bridge\]': '{start_of_bridge}',
      r'\[Pre-Chorus\]': '{comment: Pre-Chorus}',
      r'\[Outro\]': '{comment: Outro}',
      r'\[Solo\]': '{comment: Solo}',
      r'\[Interlude\]': '{comment: Interlude}',
    };

    String result = content;
    for (var entry in sectionMap.entries) {
      result = result.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }

    return result;
  }

  /// Convert Ultimate Guitar chord and lyric format to ChordPro
  static String _convertChordsAndLyrics(String content) {
    String result = content;

    // Process [tab]...[/tab] blocks
    // These contain chords positioned above lyrics
    final tabBlockRegex = RegExp(r'\[tab\](.*?)\[/tab\]', dotAll: true);
    result = result.replaceAllMapped(tabBlockRegex, (match) {
      String block = match.group(1) ?? '';
      return _processTabBlock(block);
    });

    // Convert standalone chord tags [ch]ChordName[/ch] to [ChordName]
    result = result.replaceAllMapped(
      RegExp(r'\[ch\](.*?)\[/ch\]'),
      (match) => '[${match.group(1)}]',
    );

    return result;
  }

  /// Process a [tab]...[/tab] block
  /// These blocks have chords positioned above lyrics using spacing
  static String _processTabBlock(String block) {
    final lines = block.split('\n');
    final processedLines = <String>[];

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      // Check if line contains chord tags
      if (line.contains('[ch]')) {
        // Extract chords and their positions
        final chords = <int, String>{};
        var cleanLine = line;
        
        // Find all chord positions
        final chordRegex = RegExp(r'\[ch\](.*?)\[/ch\]');
        var offset = 0;
        
        for (var match in chordRegex.allMatches(line)) {
          final chordName = match.group(1) ?? '';
          final position = match.start - offset;
          chords[position] = chordName;
          
          // Remove the chord tag from the line
          cleanLine = cleanLine.replaceFirst(match.group(0)!, '');
          offset += match.group(0)!.length;
        }

        // If there are lyrics after the chords, insert chords inline
        final lyrics = cleanLine.trim();
        if (lyrics.isNotEmpty && chords.isNotEmpty) {
          // Build line with inline chords
          final result = _insertChordsInline(lyrics, chords);
          processedLines.add(result);
        } else if (chords.isNotEmpty) {
          // Chord-only line
          final chordLine = chords.entries
              .map((e) => '[${e.value}]')
              .join(' ');
          processedLines.add(chordLine);
        }
      } else {
        // Regular lyric line without chords
        processedLines.add(line.trim());
      }
    }

    return processedLines.join('\n');
  }

  /// Insert chords inline at their approximate positions in the lyrics
  static String _insertChordsInline(String lyrics, Map<int, String> chords) {
    // Sort chords by position
    final sortedPositions = chords.keys.toList()..sort();
    
    final result = StringBuffer();
    var lastPos = 0;

    for (var pos in sortedPositions) {
      final chord = chords[pos]!;
      
      // Find the best insertion point in the lyrics
      // Try to insert before a word boundary
      var insertPos = pos;
      if (insertPos > lyrics.length) {
        insertPos = lyrics.length;
      }

      // Add lyrics up to this point
      if (insertPos > lastPos) {
        result.write(lyrics.substring(lastPos, insertPos));
      }

      // Add the chord
      result.write('[$chord]');
      lastPos = insertPos;
    }

    // Add remaining lyrics
    if (lastPos < lyrics.length) {
      result.write(lyrics.substring(lastPos));
    }

    return result.toString();
  }

  /// Extract song metadata from Ultimate Guitar content
  /// Returns a map with title and artist if found in the first line
  static Map<String, String> extractMetadata(String ugContent) {
    final metadata = <String, String>{};
    
    if (ugContent.isEmpty) return metadata;

    // First line often contains: "SongName - ArtistName (Album, Year)"
    final lines = ugContent.split('\n');
    if (lines.isEmpty) return metadata;

    final firstLine = lines.first.trim();
    
    // Try to parse "Title - Artist (Album, Year)" format
    final titleArtistRegex = RegExp(r'^(.+?)\s*-\s*(.+?)(?:\s*\(.*\))?$');
    final match = titleArtistRegex.firstMatch(firstLine);
    
    if (match != null) {
      metadata['title'] = match.group(2)?.trim() ?? '';
      metadata['artist'] = match.group(1)?.trim() ?? '';
    }

    return metadata;
  }
}
