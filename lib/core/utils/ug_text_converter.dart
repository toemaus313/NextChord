/// Converter for Ultimate Guitar pasted text to ChordPro format
/// Parses metadata and converts chord/lyric format to ChordPro
class UGTextConverter {
  /// Convert Ultimate Guitar pasted text to ChordPro format
  /// Returns a map with 'chordpro' content and extracted metadata
  static Map<String, dynamic> convertToChordPro(String ugText) {
    final metadata = <String, String>{};
    final lines = ugText.split('\n');
    final chordProLines = <String>[];
    
    // Track what we've found
    String? title;
    String? artist;
    String? key;
    int? capo;
    int? bpm;
    String? timeSignature;
    
    // Parse metadata from the beginning
    int contentStartIndex = 0;
    
    bool contentStartFound = false;
    for (int i = 0; i < lines.length && i < 30; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) continue;
      if (_isPageMarker(line)) continue;
      
      // Extract title and artist (check for "Title by Artist" pattern on first line)
      if (title == null && artist == null && line.isNotEmpty) {
        // Check if line contains " by " pattern (e.g., "Whitehouse Road Official by Tyler Childers")
        final byPattern = RegExp(r'\s+by\s+', caseSensitive: false);
        if (byPattern.hasMatch(line)) {
          final parts = line.split(byPattern);
          if (parts.length >= 2) {
            // First part is title, second part is artist
            final titlePart = parts[0]
                .replaceAll(RegExp(r'\s+Official', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s+Tab', caseSensitive: false), '')
                .trim();
            final artistPart = parts[1].trim();
            
            if (titlePart.isNotEmpty && artistPart.isNotEmpty) {
              title = titlePart;
              artist = artistPart;
              continue;
            }
          }
        }
        
        // Otherwise, check if line looks like a title (no "by" pattern found)
        if (line.toLowerCase().contains('official') || 
            line.toLowerCase().contains('tab') ||
            (!line.toLowerCase().startsWith('by') && !line.contains(':'))) {
          final cleanTitle = line
              .replaceAll(RegExp(r'\s+Official', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s+Tab', caseSensitive: false), '')
              .trim();
          if (cleanTitle.isNotEmpty && cleanTitle.length > 2) {
            title = cleanTitle;
            continue;
          }
        }
      }
      
      // Extract artist (line starting with "by" as a separate line)
      if (artist == null && line.toLowerCase().startsWith('by ')) {
        artist = line.substring(3).trim();
        continue;
      }
      
      // Extract tuning (skip it, we don't need it)
      if (line.toLowerCase().startsWith('tuning:')) {
        continue;
      }
      
      // Extract capo
      if (line.toLowerCase().startsWith('capo:')) {
        final capoMatch = RegExp(r'(\d+)').firstMatch(line);
        if (capoMatch != null) {
          capo = int.tryParse(capoMatch.group(1)!);
        }
        continue;
      }
      
      // Extract key
      if (line.toLowerCase().startsWith('key:')) {
        // Extract everything after "Key:" and trim
        final keyPart = line.substring(line.indexOf(':') + 1).trim();
        if (keyPart.isNotEmpty) {
          // Match key pattern: root note + optional sharp/flat + optional minor/major
          final keyMatch = RegExp(r'^([A-G][#b]?)(m|min|maj|major)?', caseSensitive: false).firstMatch(keyPart);
          if (keyMatch != null) {
            // Get root note and modifier
            String rootNote = keyMatch.group(1)!;
            String? modifier = keyMatch.group(2);
            
            // Normalize: uppercase root, lowercase/simplified modifier
            rootNote = rootNote[0].toUpperCase() + (rootNote.length > 1 ? rootNote.substring(1).toLowerCase() : '');
            
            // Convert flats to sharps (enharmonic equivalents)
            // Our app only uses sharps in the key dropdown
            const flatToSharp = {
              'Db': 'C#',
              'Eb': 'D#',
              'Gb': 'F#',
              'Ab': 'G#',
              'Bb': 'A#',
            };
            if (flatToSharp.containsKey(rootNote)) {
              rootNote = flatToSharp[rootNote]!;
            }
            
            // Simplify modifier
            if (modifier != null) {
              modifier = modifier.toLowerCase();
              if (modifier == 'min') {
                modifier = 'm';
              } else if (modifier == 'maj' || modifier == 'major') {
                modifier = ''; // Remove major designation
              }
            }
            
            key = rootNote + (modifier ?? '');
          }
        }
        continue;
      }
      
      // Extract BPM (tempo)
      if (line.toLowerCase().contains('bpm') || line.toLowerCase().contains('tempo')) {
        // Match patterns like "90 bpm", "Whole song 90 bpm", "tempo: 120"
        final bpmMatch = RegExp(r'(\d+)\s*(?:bpm|beats)', caseSensitive: false).firstMatch(line);
        if (bpmMatch != null) {
          bpm = int.tryParse(bpmMatch.group(1)!);
        }
        continue;
      }
      
      // Extract time signature
      if (line.toLowerCase().contains('time') && line.contains('/')) {
        final timeMatch = RegExp(r'(\d+/\d+)').firstMatch(line);
        if (timeMatch != null) {
          timeSignature = timeMatch.group(1);
        }
        continue;
      }
      
      // Skip chord chart labels (but continue processing lines for metadata)
      if (line.toLowerCase() == 'chords' || 
          line.toLowerCase() == 'strumming pattern') {
        // Just skip this label line and continue processing subsequent lines
        continue;
      }
      
      // Skip chord diagrams and strumming pattern numbers
      // (single chord names or single digits/symbols on their own line)
      if (line.length <= 6 && 
          (_looksLikeChord(line) || RegExp(r'^[\d&]+$').hasMatch(line))) {
        continue;
      }
      
      // Check if we've reached content (section markers or chord lines)
      if (line.startsWith('[') && line.contains(']')) {
        contentStartIndex = i;
        contentStartFound = true;
        break;
      }

      // First non-metadata content line encountered
      contentStartIndex = i;
      contentStartFound = true;
      break;
    }

    if (!contentStartFound) {
      contentStartIndex = 0;
    }
    
    // Build ChordPro metadata directives
    if (title != null && title.isNotEmpty) {
      chordProLines.add('{title: $title}');
      metadata['title'] = title;
    }
    if (artist != null && artist.isNotEmpty) {
      chordProLines.add('{artist: $artist}');
      metadata['artist'] = artist;
    }
    if (key != null && key.isNotEmpty) {
      chordProLines.add('{key: $key}');
      metadata['key'] = key;
    }
    if (capo != null) {
      chordProLines.add('{capo: $capo}');
      metadata['capo'] = capo.toString();
    }
    if (bpm != null) {
      chordProLines.add('{tempo: $bpm}');
      metadata['bpm'] = bpm.toString();
    }
    if (timeSignature != null && timeSignature.isNotEmpty) {
      chordProLines.add('{time: $timeSignature}');
      metadata['timeSignature'] = timeSignature;
    }
    
    chordProLines.add(''); // Empty line after metadata
    
    // Parse the song content starting from contentStartIndex
    bool insideExplicitTabBlock = false;
    for (int i = contentStartIndex; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      // Skip page markers like "Page 1/4"
      if (_isPageMarker(trimmedLine)) {
        continue;
      }
      
      // Skip empty lines initially
      if (trimmedLine.isEmpty) {
        if (insideExplicitTabBlock) {
          chordProLines.add('');
        } else if (chordProLines.length > 5) { // Only add after we have content
          chordProLines.add('');
        }
        continue;
      }

      final lowerTrimmed = trimmedLine.toLowerCase();
      if (lowerTrimmed == '{sot}') {
        insideExplicitTabBlock = true;
        chordProLines.add('{sot}');
        continue;
      }
      if (lowerTrimmed == '{eot}') {
        insideExplicitTabBlock = false;
        chordProLines.add('{eot}');
        continue;
      }

      if (!insideExplicitTabBlock && _looksLikeTabLine(trimmedLine)) {
        final tabLines = <String>[];
        final nextIndex = _collectTabBlock(lines, i, tabLines);
        if (tabLines.isNotEmpty) {
          chordProLines.add('{sot}');
          chordProLines.addAll(tabLines);
          chordProLines.add('{eot}');
          i = nextIndex - 1;
          continue;
        }
      }

      // Normalize comment directives like {comment: Verse}
      final commentDirectiveMatch = RegExp(r'^\{comment:\s*([^}]+)\}\s*$', caseSensitive: false)
          .firstMatch(trimmedLine);
      if (commentDirectiveMatch != null) {
        final commentText = commentDirectiveMatch.group(1)?.trim() ?? '';
        if (commentText.isNotEmpty) {
          final convertedDirective = _convertSectionToChordPro(commentText);
          if (convertedDirective != '{comment: $commentText}') {
            chordProLines.add(convertedDirective);
            continue;
          }
        }
        chordProLines.add(trimmedLine);
        continue;
      }
      
      // Detect section markers: [Intro], [Verse 1], [Chorus], etc.
      final sectionMatch = RegExp(r'^\[([^\]]+)\](.*)$').firstMatch(trimmedLine);
      if (sectionMatch != null) {
        final sectionName = sectionMatch.group(1)!.trim();
        final restOfLine = sectionMatch.group(2) ?? '';

        // If the bracket contents look like a chord, this is actually a chord/lyric line
        if (_looksLikeChord(sectionName)) {
          chordProLines.add(_processChordLine(line));
          continue;
        }

        // Convert to ChordPro section directive
        final chordProSection = _convertSectionToChordPro(sectionName);
        chordProLines.add(chordProSection);

        // If there's content after the section marker, process it
        if (restOfLine.trim().isNotEmpty) {
          chordProLines.add(_processChordLine(restOfLine.trimLeft()));
        }
        continue;
      }
      
      // Process chord/lyric lines
      // Check if this is a chord-only line followed by lyrics
      if (_isChordOnlyLine(trimmedLine)) {
        // Look ahead to see if next line is lyrics
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.isNotEmpty && !_isChordOnlyLine(nextLine) && !nextLine.startsWith('[')) {
            // Merge chord line with lyric line
            final mergedLine = _mergeChordsWithLyrics(line, lines[i + 1]);
            chordProLines.add(mergedLine);
            i++; // Skip the next line since we merged it
            continue;
          }
        }
        // Standalone chord line (no lyrics following)
        chordProLines.add(_processChordLine(trimmedLine));
      } else {
        // Regular lyric line or mixed content
        chordProLines.add(_processChordLine(trimmedLine));
      }
    }
    
    return {
      'chordpro': chordProLines.join('\n'),
      'metadata': metadata,
    };
  }
  
  /// Convert section name to ChordPro directive
  static String _convertSectionToChordPro(String sectionName) {
    final lower = sectionName.toLowerCase();
    final normalized = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    
    // Check for post-chorus FIRST (before checking for "chorus" alone)
    if (normalized.contains('postchorus')) {
      return '{comment: Post-Chorus}';
    }
    
    // Check for pre-chorus (before checking for "chorus" alone)
    if (normalized.contains('prechorus')) {
      return '{comment: Pre-Chorus}';
    }
    
    // Check for verse variations
    if (normalized.contains('verse')) {
      if (sectionName.contains(RegExp(r'\d'))) {
        return '{verse: $sectionName}';
      }
      return '{verse}';
    }

    // Check for chorus
    if (normalized.contains('chorus')) {
      if (sectionName.contains(RegExp(r'\d'))) {
        return '{chorus: $sectionName}';
      }
      return '{chorus}';
    }

    // Check for bridge
    if (normalized.contains('bridge')) {
      if (sectionName.contains(RegExp(r'\d'))) {
        return '{bridge: $sectionName}';
      }
      return '{bridge}';
    }

    // Check for intro
    if (normalized.contains('intro')) {
      if (sectionName.contains(RegExp(r'\d'))) {
        return '{intro: $sectionName}';
      }
      return '{intro}';
    }

    // Check for outro
    if (normalized.contains('outro')) {
      if (sectionName.contains(RegExp(r'\d'))) {
        return '{outro: $sectionName}';
      }
      return '{outro}';
    }

    // Check for solo
    if (normalized.contains('solo')) {
      return '{comment: Solo}';
    }

    // Check for interlude
    if (normalized.contains('interlude')) {
      return '{comment: Interlude}';
    }

    // Check for fade-out
    if (normalized.contains('fade')) {
      return '{comment: Fade-Out}';
    }
    
    // Default: use as comment
    return '{comment: $sectionName}';
  }
  
  /// Process a line that may contain chords
  /// Ultimate Guitar format: chords are already inline or the line is just chords
  static String _processChordLine(String line) {
    // First check if line contains any chords at all
    final words = line.split(RegExp(r'\s+'));
    final hasChords = words.any((word) => _looksLikeChord(word));
    
    // If no chords found, return the line as-is (plain lyrics)
    if (!hasChords) {
      return line;
    }
    
    final tokenRegex = RegExp(r'\S+|\s+');
    final buffer = StringBuffer();
    for (final match in tokenRegex.allMatches(line)) {
      final token = match.group(0)!;
      if (token.trim().isEmpty) {
        buffer.write(token);
      } else if (_looksLikeChord(token)) {
        buffer.write('[$token]');
      } else {
        buffer.write(token);
      }
    }
    
    return buffer.toString();
  }
  
  /// Check if a token looks like a chord
  static bool _looksLikeChord(String token) {
    if (token.isEmpty || token.length > 10) return false;
    
    // Must start with A-G
    if (!RegExp(r'^[A-G]').hasMatch(token)) return false;
    
    // Common chord patterns
    final chordPattern = RegExp(
      r'^[A-G][#b]?'  // Root note with optional sharp/flat
      r'(?:sus[24]?|maj|min|dim|aug|add|m)?'  // Optional quality
      r'(?:\d+)?'  // Optional number (7, 9, etc.)
      r'(?:/[A-G][#b]?)?$',  // Optional slash chord
      caseSensitive: true
    );
    
    return chordPattern.hasMatch(token);
  }
  
  /// Check if a line contains only chords (no lyrics)
  static bool _isChordOnlyLine(String line) {
    if (line.isEmpty) return false;
    
    // Split into non-whitespace tokens
    final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    
    if (tokens.isEmpty) return false;
    
    // Check if all tokens are chords
    for (final token in tokens) {
      if (!_looksLikeChord(token)) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Merge a chord line with its corresponding lyric line
  /// Uses column positions to place chords correctly
  static String _mergeChordsWithLyrics(String chordLine, String lyricLine) {
    // Find chord positions in the chord line
    final chordMatches = <int, String>{};
    
    for (int i = 0; i < chordLine.length; i++) {
      // Skip whitespace
      if (chordLine[i] == ' ' || chordLine[i] == '\t') {
        continue;
      }
      
      // Start of a chord
      final chordStart = i;
      // Find the end of the chord (next whitespace or end of line)
      int chordEnd = i;
      while (chordEnd < chordLine.length && 
             chordLine[chordEnd] != ' ' && 
             chordLine[chordEnd] != '\t') {
        chordEnd++;
      }
      
      final chord = chordLine.substring(chordStart, chordEnd);
      if (_looksLikeChord(chord)) {
        chordMatches[chordStart] = chord;
      }
      
      i = chordEnd - 1; // Continue from end of chord
    }
    
    // Insert chords into lyrics at their column positions
    final result = StringBuffer();
    final sortedPositions = chordMatches.keys.toList()..sort();
    
    int lastPos = 0;
    for (final pos in sortedPositions) {
      final chord = chordMatches[pos]!;
      
      // Determine insertion position in lyrics
      // If position is beyond lyrics length, append at end
      final insertPos = pos < lyricLine.length ? pos : lyricLine.length;
      
      // Add lyrics up to this position
      if (insertPos > lastPos && lastPos < lyricLine.length) {
        final endPos = insertPos < lyricLine.length ? insertPos : lyricLine.length;
        result.write(lyricLine.substring(lastPos, endPos));
      }
      
      // Add the chord
      result.write('[$chord]');
      lastPos = insertPos;
    }
    
    // Add remaining lyrics
    if (lastPos < lyricLine.length) {
      result.write(lyricLine.substring(lastPos));
    }
    
    return result.toString().trim();
  }
}

int _collectTabBlock(List<String> lines, int startIndex, List<String> tabLines) {
  int consecutiveEmptyLines = 0;
  int consumed = startIndex;

  for (; consumed < lines.length && consumed - startIndex < 20; consumed++) {
    final rawLine = lines[consumed];
    final trimmed = rawLine.trim();

    if (trimmed.isEmpty) {
      if (tabLines.isEmpty) {
        break;
      }
      consecutiveEmptyLines++;
      if (consecutiveEmptyLines > 2) {
        break;
      }
      tabLines.add('');
      continue;
    }

    if (trimmed.startsWith('{') && (trimmed.toLowerCase().contains('sot') || trimmed.toLowerCase().contains('eot'))) {
      break;
    }

    if (_looksLikeTabLine(trimmed)) {
      consecutiveEmptyLines = 0;
      tabLines.add(rawLine.trimRight());
      continue;
    }

    break;
  }

  return consumed;
}

bool _looksLikeTabLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;

  final tabLineRegex = RegExp(r'^[EADGBe]\|[\-0-9|]+', caseSensitive: true);
  if (tabLineRegex.hasMatch(trimmed)) return true;

  final nonSpaceChars = trimmed.replaceAll(' ', '');
  if (nonSpaceChars.length < 3) return false;

  final tabChars = RegExp(r'[\-0-9|]');
  final tabCharCount = tabChars.allMatches(nonSpaceChars).length;
  return tabCharCount / nonSpaceChars.length > 0.5;
}

bool _isPageMarker(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^Page\s+\d+\s*/\s*\d+$', caseSensitive: false).hasMatch(trimmed);
}
