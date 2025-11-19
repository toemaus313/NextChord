/// Represents a single line in a ChordPro song with chords and lyrics
class ChordProLine {
  /// The type of line (lyrics, section, comment, tablature, etc.)
  final ChordProLineType type;

  /// The raw text content of the line
  final String text;

  /// List of chord positions and their chord names
  /// Each entry contains the position (character index) and the chord
  final List<ChordPosition> chords;

  /// Section name if this is a section header (e.g., "Verse 1", "Chorus")
  final String? section;

  /// Section type if this is a section header (e.g., "verse", "chorus", "bridge")
  final String? sectionType;

  ChordProLine({
    required this.type,
    required this.text,
    this.chords = const [],
    this.section,
    this.sectionType,
  });

  @override
  String toString() {
    if (type == ChordProLineType.section) {
      return 'Section: $section ($sectionType)';
    }
    if (chords.isEmpty) {
      return text;
    }
    return '$text (${chords.length} chords)';
  }
}

/// Represents the position and name of a chord in a line
class ChordPosition {
  /// The character position where the chord should appear
  final int position;

  /// The chord name (e.g., "Cmaj7", "Am/G")
  final String chord;

  ChordPosition(this.position, this.chord);

  @override
  String toString() => '$chord@$position';
}

/// Types of lines in a ChordPro file
enum ChordProLineType {
  /// A line with lyrics and possibly chords
  lyrics,

  /// A section header like {chorus} or {verse: Verse 1}
  section,

  /// A comment line starting with #
  comment,

  /// A directive like {title: Song Name}
  directive,

  /// Tablature content between {sot} and {eot}
  tablature,

  /// Grid content between {sog} and {eog}
  grid,

  /// A chorus reference {chorus} or {chorus: Final}
  chorusRef,

  /// An empty line
  empty,
}

/// Represents parsed metadata from a ChordPro file
class ChordProMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? key;
  final int? capo;
  final String? tempo;
  final String? time;
  final String? duration;

  /// All other metadata fields not explicitly defined
  final Map<String, String> other;

  ChordProMetadata({
    this.title,
    this.artist,
    this.album,
    this.key,
    this.capo,
    this.tempo,
    this.time,
    this.duration,
    this.other = const {},
  });

  /// Parse duration string (e.g., "3:39", "2:45") into total seconds
  /// Returns null if duration is not set or cannot be parsed
  int? get durationInSeconds {
    if (duration == null) return null;

    try {
      final parts = duration!.split(':');
      if (parts.isEmpty) return null;

      if (parts.length == 2) {
        // Format: MM:SS
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return minutes * 60 + seconds;
      } else if (parts.length == 3) {
        // Format: HH:MM:SS
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return hours * 3600 + minutes * 60 + seconds;
      }
    } catch (e) {
      // Return null if parsing fails
      return null;
    }

    return null;
  }

  @override
  String toString() {
    final parts = <String>[];
    if (title != null) parts.add('Title: $title');
    if (artist != null) parts.add('Artist: $artist');
    if (key != null) parts.add('Key: $key');
    if (capo != null) parts.add('Capo: $capo');
    if (duration != null) parts.add('Duration: $duration');
    return parts.join(', ');
  }
}

/// ChordPro format parser and utilities
class ChordProParser {
  /// Regex to find chords in ChordPro format: [Cmaj7], [Am], etc.
  static final chordRegex = RegExp(r'\[([^\]]+)\]');

  /// Regex to find section headers: {chorus}, {verse: Verse 1}, {start_of_verse}, etc.
  /// Supports: start_of_verse (sov), start_of_chorus (soc), start_of_bridge (sob),
  /// start_of_tab (sot), start_of_grid (sog), and their end_ counterparts
  static final sectionRegex = RegExp(
      r'\{(start_of_verse|end_of_verse|sov|eov|start_of_chorus|end_of_chorus|soc|eoc|start_of_bridge|end_of_bridge|sob|eob|start_of_tab|end_of_tab|sot|eot|start_of_grid|end_of_grid|sog|eog|verse|chorus|bridge|intro|outro|v|c|b)(?::\s*([^}]+))?\}',
      caseSensitive: false);

  /// Regex to find chorus reference directive: {chorus} or {chorus: Final}
  static final chorusRefRegex = RegExp(
      r'^\s*\{chorus(?::\s*([^}]+))?\}\s*$',
      caseSensitive: false);

  /// Regex to find metadata directives: {title: Song Name}, {artist: Artist}
  static final metadataRegex = RegExp(r'\{(\w+):\s*([^}]+)\}');

  /// Regex to find comments: # This is a comment
  static final commentRegex = RegExp(r'^\s*#(.*)$');

  /// Regex to identify tablature markers
  static final tablatureStartRegex = RegExp(r'\{sot\}', caseSensitive: false);
  static final tablatureEndRegex = RegExp(r'\{eot\}', caseSensitive: false);

  /// Parse ChordPro text and extract all chords
  static List<String> extractChords(String text) {
    final matches = chordRegex.allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Transpose all chords in ChordPro text by a given number of semitones
  static String transposeChordProText(String text, int semitones) {
    return text.replaceAllMapped(chordRegex, (match) {
      final chord = match.group(1)!;
      final transposed = transposeChord(chord, semitones);
      return '[$transposed]';
    });
  }

  /// Transpose a single chord (handles complex chords like Cmaj7, Am/G, Dm7b5, etc.)
  /// This function preserves all chord modifiers like maj7, min7, b5, #9, sus4, etc.
  static String transposeChord(String chord, int semitones) {
    if (chord.isEmpty) return chord;

    // Handle slash chords (e.g., Am/G)
    // We need to transpose both the main chord and the bass note
    if (chord.contains('/')) {
      final parts = chord.split('/');
      if (parts.length == 2) {
        final mainChord = transposeChord(parts[0], semitones);
        final bassNote = transposeChord(parts[1], semitones);
        return '$mainChord/$bassNote';
      }
    }

    // Extract the root note (first 1-2 characters: C, C#, Db, etc.)
    String rootNote = '';
    int rootNoteLength = 1;

    // Check if the second character is a sharp or flat
    if (chord.length > 1 && (chord[1] == '#' || chord[1] == 'b')) {
      rootNoteLength = 2;
    }

    rootNote = chord.substring(0, rootNoteLength);

    // Everything after the root note is the modifier (maj7, m7b5, sus4, etc.)
    final modifier = chord.substring(rootNoteLength);

    // Transpose the root note
    final transposedRoot = _transposeSingleNote(rootNote, semitones);

    // Return the transposed root with the original modifier preserved
    return transposedRoot + modifier;
  }

  /// Transpose a single note (C, C#, Db, etc.)
  /// Handles both sharp and flat notation
  static String _transposeSingleNote(String note, int semitones) {
    // Define the chromatic scale using sharps
    const sharpNotes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];

    // Map flat notes to their sharp equivalents for transposition
    const flatToSharp = {
      'Db': 'C#',
      'Eb': 'D#',
      'Gb': 'F#',
      'Ab': 'G#',
      'Bb': 'A#',
      'db': 'C#',
      'eb': 'D#',
      'gb': 'F#',
      'ab': 'G#',
      'bb': 'A#',
    };

    // Normalize the note to uppercase for comparison
    String normalizedNote = note;
    bool isLowerCase = note.isNotEmpty && note[0] == note[0].toLowerCase();

    // Convert flat notation to sharp if needed
    if (flatToSharp.containsKey(note)) {
      normalizedNote = flatToSharp[note]!;
    } else {
      normalizedNote = note.toUpperCase();
    }

    // Find the note in the chromatic scale
    int index = sharpNotes.indexOf(normalizedNote);
    if (index == -1) return note; // Return original if not found

    // Apply the transposition
    index = (index + semitones) % 12;
    if (index < 0) index += 12;

    // Return the transposed note, preserving original case for single-letter notes
    String result = sharpNotes[index];
    if (isLowerCase && result.length == 1) {
      return result.toLowerCase();
    }
    // For multi-character notes (with #), always return uppercase
    return result;
  }

  /// Extract song metadata from ChordPro directives
  /// Returns a structured ChordProMetadata object
  static ChordProMetadata extractMetadata(String text) {
    final rawMetadata = <String, String>{};

    // Extract all metadata directives
    for (final match in metadataRegex.allMatches(text)) {
      final key = match.group(1)?.toLowerCase() ?? '';
      final value = match.group(2)?.trim() ?? '';
      if (key.isNotEmpty && value.isNotEmpty) {
        rawMetadata[key] = value;
      }
    }

    // Parse capo as integer if present
    int? capo;
    if (rawMetadata.containsKey('capo')) {
      capo = int.tryParse(rawMetadata['capo']!);
    }

    // Build the structured metadata object
    final otherMetadata = Map<String, String>.from(rawMetadata);
    otherMetadata.remove('title');
    otherMetadata.remove('artist');
    otherMetadata.remove('album');
    otherMetadata.remove('key');
    otherMetadata.remove('capo');
    otherMetadata.remove('tempo');
    otherMetadata.remove('time');
    otherMetadata.remove('duration');

    return ChordProMetadata(
      title: rawMetadata['title'],
      artist: rawMetadata['artist'] ??
          rawMetadata['subtitle'], // subtitle often contains artist
      album: rawMetadata['album'],
      key: rawMetadata['key'],
      capo: capo,
      tempo: rawMetadata['tempo'] ?? rawMetadata['metronome'],
      time: rawMetadata['time'],
      duration: rawMetadata['duration'],
      other: otherMetadata,
    );
  }

  /// Parse a ChordPro file into structured data
  /// Returns a list of ChordProLine objects representing the song structure
  static List<ChordProLine> parseToStructuredData(String text) {
    final lines = <ChordProLine>[];
    final textLines = text.split('\n');
    bool inTablature = false;
    bool inGrid = false;

    for (var line in textLines) {
      // Check for tablature markers
      if (tablatureStartRegex.hasMatch(line)) {
        inTablature = true;
        continue; // Don't include the {sot} marker itself
      }
      if (tablatureEndRegex.hasMatch(line)) {
        inTablature = false;
        continue; // Don't include the {eot} marker itself
      }

      // Check for grid markers
      if (RegExp(r'\{(start_of_grid|sog)\}', caseSensitive: false).hasMatch(line)) {
        inGrid = true;
        continue;
      }
      if (RegExp(r'\{(end_of_grid|eog)\}', caseSensitive: false).hasMatch(line)) {
        inGrid = false;
        continue;
      }

      // If we're in a tablature section, mark it as such
      if (inTablature) {
        lines.add(ChordProLine(
          type: ChordProLineType.tablature,
          text: line,
        ));
        continue;
      }

      // If we're in a grid section, mark it as such
      if (inGrid) {
        lines.add(ChordProLine(
          type: ChordProLineType.grid,
          text: line,
        ));
        continue;
      }

      // Check for comments (lines starting with #)
      final commentMatch = commentRegex.firstMatch(line);
      if (commentMatch != null) {
        lines.add(ChordProLine(
          type: ChordProLineType.comment,
          text: commentMatch.group(1)?.trim() ?? '',
        ));
        continue;
      }

      // Check for chorus reference directive (must be on its own line)
      final chorusRefMatch = chorusRefRegex.firstMatch(line);
      if (chorusRefMatch != null) {
        final label = chorusRefMatch.group(1)?.trim();
        lines.add(ChordProLine(
          type: ChordProLineType.chorusRef,
          text: line,
          section: label ?? 'Chorus',
          sectionType: 'chorus',
        ));
        continue;
      }

      // Check for section headers
      final sectionMatch = sectionRegex.firstMatch(line);
      if (sectionMatch != null) {
        final sectionType = sectionMatch.group(1)!.toLowerCase();
        final sectionName = sectionMatch.group(2)?.trim();

        // Skip end directives (they don't display)
        if (_isEndDirective(sectionType)) {
          continue;
        }

        // Map abbreviated section types to full names
        String fullSectionType = sectionType;
        String displayName = sectionName ?? _getDefaultSectionName(sectionType);

        // Only add if there's a display name
        if (displayName.isNotEmpty) {
          lines.add(ChordProLine(
            type: ChordProLineType.section,
            text: line,
            section: displayName,
            sectionType: fullSectionType,
          ));
        }
        continue;
      }

      // Check for metadata directives
      final metadataMatch = metadataRegex.firstMatch(line);
      if (metadataMatch != null) {
        lines.add(ChordProLine(
          type: ChordProLineType.directive,
          text: line,
        ));
        continue;
      }

      // Check for empty lines
      if (line.trim().isEmpty) {
        lines.add(ChordProLine(
          type: ChordProLineType.empty,
          text: '',
        ));
        continue;
      }

      // Parse lyrics with chords
      final chordPositions = <ChordPosition>[];
      String lyricsText = line;

      // Find all chords and their positions
      final matches = chordRegex.allMatches(line).toList();

      // We need to track position adjustments as we remove chord markers
      int positionOffset = 0;

      for (final match in matches) {
        final chordName = match.group(1)!;
        // The position where the chord appears in the original text
        final originalPosition = match.start;
        // Adjust for previously removed chord markers
        final adjustedPosition = originalPosition - positionOffset;

        chordPositions.add(ChordPosition(adjustedPosition, chordName));

        // Update offset for the next chord
        // +2 accounts for the [ and ] brackets
        positionOffset += chordName.length + 2;
      }

      // Remove chord markers from the lyrics text
      lyricsText = line.replaceAll(chordRegex, '');

      lines.add(ChordProLine(
        type: ChordProLineType.lyrics,
        text: lyricsText,
        chords: chordPositions,
      ));
    }

    return lines;
  }

  /// Get default section name based on section type
  static String _getDefaultSectionName(String sectionType) {
    switch (sectionType.toLowerCase()) {
      case 'start_of_verse':
      case 'sov':
      case 'verse':
      case 'v':
        return 'Verse';
      case 'start_of_chorus':
      case 'soc':
      case 'chorus':
      case 'c':
        return 'Chorus';
      case 'start_of_bridge':
      case 'sob':
      case 'bridge':
      case 'b':
        return 'Bridge';
      case 'start_of_tab':
      case 'sot':
        return 'Tab';
      case 'start_of_grid':
      case 'sog':
        return 'Grid';
      case 'intro':
        return 'Intro';
      case 'outro':
        return 'Outro';
      case 'end_of_verse':
      case 'eov':
      case 'end_of_chorus':
      case 'eoc':
      case 'end_of_bridge':
      case 'eob':
      case 'end_of_tab':
      case 'eot':
      case 'end_of_grid':
      case 'eog':
        // End directives don't display by default
        return '';
      default:
        return sectionType.toUpperCase();
    }
  }

  /// Check if a section type is an "end" directive
  static bool _isEndDirective(String sectionType) {
    final lower = sectionType.toLowerCase();
    return lower.startsWith('end_of_') || 
           lower == 'eov' || lower == 'eoc' || 
           lower == 'eob' || lower == 'eot' || lower == 'eog';
  }

  /// Render structured data back to ChordPro format
  /// Useful for saving edited songs or transposed versions
  static String renderToChordPro(List<ChordProLine> lines) {
    if (lines.isEmpty) return '';

    final buffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;

      switch (line.type) {
        case ChordProLineType.section:
          buffer.write('{${line.sectionType}: ${line.section}}');
          break;
        case ChordProLineType.comment:
          buffer.write('# ${line.text}');
          break;
        case ChordProLineType.directive:
          buffer.write(line.text);
          break;
        case ChordProLineType.tablature:
          buffer.write(line.text);
          break;
        case ChordProLineType.grid:
          buffer.write(line.text);
          break;
        case ChordProLineType.chorusRef:
          buffer.write(line.text);
          break;
        case ChordProLineType.empty:
          // For empty lines, just add newline if not last
          if (!isLastLine) {
            buffer.write('\n');
          }
          continue; // Skip the newline addition below
        case ChordProLineType.lyrics:
          // Reconstruct the line with chords
          if (line.chords.isEmpty) {
            buffer.write(line.text);
          } else {
            // Build the line with chords inserted at their positions
            final result = StringBuffer();
            int lastPos = 0;

            for (final chord in line.chords) {
              // Add text up to this chord position
              if (chord.position > lastPos) {
                result.write(line.text.substring(lastPos, chord.position));
              }
              // Add the chord
              result.write('[${chord.chord}]');
              lastPos = chord.position;
            }

            // Add remaining text
            if (lastPos < line.text.length) {
              result.write(line.text.substring(lastPos));
            }

            buffer.write(result.toString());
          }
          break;
      }

      // Add newline after each line except the last
      if (!isLastLine) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }

  /// Detect if a line looks like guitar tablature
  /// Tab lines typically contain: E|, A|, D|, G|, B|, e| followed by dashes and numbers
  static bool _looksLikeTabLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    
    // Check for standard guitar string notation (E|, A|, D|, G|, B|, e|)
    final tabLineRegex = RegExp(r'^[EADGBe]\|[\-0-9|]+', caseSensitive: true);
    if (tabLineRegex.hasMatch(trimmed)) return true;
    
    // Also check for lines that are mostly dashes, numbers, and pipes
    // (at least 50% of non-space characters should be tab-like)
    final tabChars = RegExp(r'[\-0-9|]');
    final nonSpaceChars = trimmed.replaceAll(' ', '');
    if (nonSpaceChars.length < 3) return false;
    
    final tabCharCount = tabChars.allMatches(nonSpaceChars).length;
    return tabCharCount / nonSpaceChars.length > 0.5;
  }

  /// Find the end position for a tab section starting at the given line index
  /// Returns the line index where {eot} should be inserted
  /// 
  /// Tab sections end when:
  /// 1. A ChordPro directive is encountered (lines starting with {)
  /// 2. A line with chords in brackets is encountered [C], [Am], etc.
  /// 3. Multiple consecutive empty lines (more than 2)
  /// 4. End of text
  static int findTabEndPosition(List<String> lines, int startIndex) {
    int consecutiveEmptyLines = 0;
    int lastTabLineIndex = startIndex;
    
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Check for empty line
      if (line.isEmpty) {
        consecutiveEmptyLines++;
        // If we hit more than 2 consecutive empty lines, check if next non-empty is tab
        if (consecutiveEmptyLines > 2) {
          // Look ahead to see if there's more tab content
          bool foundMoreTab = false;
          for (int j = i + 1; j < lines.length && j < i + 5; j++) {
            if (lines[j].trim().isNotEmpty) {
              if (_looksLikeTabLine(lines[j])) {
                foundMoreTab = true;
              }
              break;
            }
          }
          if (!foundMoreTab) {
            return lastTabLineIndex + 1;
          }
        }
        continue;
      }
      
      // Reset empty line counter when we find content
      consecutiveEmptyLines = 0;
      
      // Check for ChordPro directives (but not {sot} or {eot})
      if (line.startsWith('{')) {
        if (!line.toLowerCase().contains('sot') && !line.toLowerCase().contains('eot')) {
          return i;
        }
        continue;
      }
      
      // Check for chord notation [C], [Am], etc.
      // But be careful - tab lines can have brackets too
      if (chordRegex.hasMatch(line) && !_looksLikeTabLine(line)) {
        return i;
      }
      
      // Check if this line looks like tab
      if (_looksLikeTabLine(line)) {
        lastTabLineIndex = i;
      } else {
        // Non-tab content found (lyrics, etc.)
        return i;
      }
    }
    
    // Reached end of text
    return lastTabLineIndex + 1;
  }

  /// Auto-complete tab sections by adding {eot} after {sot}
  /// Returns the modified text with {eot} tags inserted where appropriate
  static String autoCompleteTabSections(String text) {
    final lines = text.split('\n');
    final result = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      result.add(line);
      
      // Check if this line contains {sot}
      if (tablatureStartRegex.hasMatch(line)) {
        // Check if there's already an {eot} nearby
        bool hasMatchingEot = false;
        for (int j = i + 1; j < lines.length && j < i + 50; j++) {
          if (tablatureEndRegex.hasMatch(lines[j])) {
            hasMatchingEot = true;
            break;
          }
          // Stop searching if we hit another {sot}
          if (tablatureStartRegex.hasMatch(lines[j])) {
            break;
          }
        }
        
        // If no {eot} found, insert one
        if (!hasMatchingEot) {
          final endPos = findTabEndPosition(lines, i + 1);
          // We'll insert the {eot} at the end position
          // Continue processing and insert it when we reach that position
          if (endPos <= lines.length) {
            // Mark this position for insertion
            // We'll handle this by inserting after processing all lines up to endPos
            final remainingLines = lines.sublist(i + 1, endPos);
            result.addAll(remainingLines);
            result.add('{eot}');
            i = endPos - 1; // Skip to the position after insertion
          }
        }
      }
    }
    
    return result.join('\n');
  }
}
