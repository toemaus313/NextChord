import 'package:flutter/material.dart';
import '../../core/utils/chordpro_parser.dart';

/// A widget that renders ChordPro formatted text with chords highlighted
/// Uses the enhanced ChordPro parser for proper section headers, comments, and structure
class ChordRenderer extends StatelessWidget {
  final String chordProText;
  final double fontSize;
  final bool isDarkMode;
  final int? transposeSteps; // Optional: transpose chords by semitones

  const ChordRenderer({
    Key? key,
    required this.chordProText,
    this.fontSize = 16.0,
    this.isDarkMode = false,
    this.transposeSteps,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Parse the ChordPro text into structured data
    String processedText = chordProText;

    // Apply transposition if requested
    if (transposeSteps != null && transposeSteps != 0) {
      processedText = ChordProParser.transposeChordProText(
        chordProText,
        transposeSteps!,
      );
    }

    final lines = ChordProParser.parseToStructuredData(processedText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _buildStructuredLine(line)).toList(),
    );
  }

  /// Build a widget for a structured ChordPro line
  Widget _buildStructuredLine(ChordProLine line) {
    switch (line.type) {
      case ChordProLineType.section:
        return _buildSectionHeader(line);

      case ChordProLineType.comment:
        return _buildComment(line);

      case ChordProLineType.tablature:
        return _buildTablature(line);

      case ChordProLineType.grid:
        return _buildGrid(line);

      case ChordProLineType.chorusRef:
        return _buildChorusReference(line);

      case ChordProLineType.directive:
        // Skip metadata directives (already shown in header)
        return const SizedBox.shrink();

      case ChordProLineType.empty:
        return const SizedBox(height: 12);

      case ChordProLineType.lyrics:
        return _buildLyricsLine(line);
    }
  }

  /// Build a section header (e.g., "Verse 1", "Chorus")
  /// Displays with distinctive styling based on section type
  Widget _buildSectionHeader(ChordProLine line) {
    // Get color and icon based on section type
    final sectionInfo = _getSectionStyle(line.sectionType ?? '');
    
    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: sectionInfo.backgroundColor.withValues(alpha: isDarkMode ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: sectionInfo.borderColor.withValues(alpha: isDarkMode ? 0.5 : 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sectionInfo.icon,
            size: fontSize * 1.1,
            color: sectionInfo.textColor,
          ),
          const SizedBox(width: 8),
          Text(
            line.section ?? '',
            style: TextStyle(
              fontSize: fontSize * 1.15,
              fontWeight: FontWeight.bold,
              color: sectionInfo.textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a comment line (rendered as section header with cyan color)
  Widget _buildComment(ChordProLine line) {
    final commentColor = isDarkMode ? Colors.cyan.shade300 : Colors.cyan.shade800;
    
    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: isDarkMode ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.cyan.shade600.withValues(alpha: isDarkMode ? 0.5 : 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: fontSize * 1.1,
            color: commentColor,
          ),
          const SizedBox(width: 8),
          Text(
            line.text,
            style: TextStyle(
              fontSize: fontSize * 1.15,
              fontWeight: FontWeight.bold,
              color: commentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a tablature line (monospace font)
  Widget _buildTablature(ChordProLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Text(
        line.text,
        style: TextStyle(
          fontSize: fontSize * 0.85,
          fontFamily: 'Courier',
          color: isDarkMode ? Colors.green.shade300 : Colors.green.shade700,
          height: 1.2,
        ),
      ),
    );
  }

  /// Build a grid line (monospace font, similar to tablature)
  Widget _buildGrid(ChordProLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Text(
        line.text,
        style: TextStyle(
          fontSize: fontSize * 0.9,
          fontFamily: 'Courier',
          color: isDarkMode ? Colors.cyan.shade300 : Colors.cyan.shade700,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build a chorus reference (e.g., {chorus} or {chorus: Final})
  Widget _buildChorusReference(ChordProLine line) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.purple.shade900.withValues(alpha: 0.3)
            : Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.purple.shade400 : Colors.purple.shade300,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: fontSize * 1.1,
            color: isDarkMode ? Colors.purple.shade300 : Colors.purple.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            '↻ ${line.section}',
            style: TextStyle(
              fontSize: fontSize * 1.05,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.purple.shade300 : Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a lyrics line with chords positioned above the text
  Widget _buildLyricsLine(ChordProLine line) {
    if (line.chords.isEmpty) {
      // No chords, just render lyrics
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Text(
          line.text.isEmpty ? ' ' : line.text, // Preserve empty lines
          style: TextStyle(
            fontSize: fontSize,
            color: isDarkMode ? Colors.white : Colors.black87,
            height: 1.8,
          ),
        ),
      );
    }

    // Build chords and lyrics on separate lines
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chord line
          _buildChordLine(line),
          // Lyrics line
          Text(
            line.text.isEmpty ? ' ' : line.text,
            style: TextStyle(
              fontSize: fontSize,
              color: isDarkMode ? Colors.white : Colors.black87,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the chord line positioned above lyrics
  Widget _buildChordLine(ChordProLine line) {
    final spans = <InlineSpan>[];
    int lastPos = 0;
    
    // Check if this is a chord-only line (no lyrics text)
    final hasLyrics = line.text.trim().isNotEmpty;
    // Use 3x spacing for chord-only lines, 1x for lines with lyrics
    final spacingMultiplier = hasLyrics ? 1 : 3;

    for (int i = 0; i < line.chords.length; i++) {
      final chordPos = line.chords[i];
      
      // Calculate spacing before this chord
      int spaces = 0;
      if (chordPos.position > lastPos) {
        // Normal spacing based on position difference
        spaces = (chordPos.position - lastPos) * spacingMultiplier;
      } else if (i > 0 && !hasLyrics) {
        // If chords are at same position on a chord-only line,
        // add minimum spacing of 3 spaces between chords
        spaces = 3;
      }
      
      if (spaces > 0) {
        spans.add(TextSpan(
          text: ' ' * spaces,
          style: TextStyle(fontSize: fontSize),
        ));
      }

      // Add the chord
      spans.add(TextSpan(
        text: chordPos.chord,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.amber.shade300 : Colors.blue.shade700,
        ),
      ));

      lastPos = chordPos.position + chordPos.chord.length;
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Get styling information for a section based on its type
  _SectionStyle _getSectionStyle(String sectionType) {
    final lower = sectionType.toLowerCase();
    
    // Determine section category
    if (lower.contains('verse') || lower == 'sov' || lower == 'v') {
      return _SectionStyle(
        icon: Icons.format_list_numbered,
        textColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade800,
        backgroundColor: Colors.blue,
        borderColor: Colors.blue.shade600,
      );
    } else if (lower.contains('chorus') || lower == 'soc' || lower == 'c') {
      return _SectionStyle(
        icon: Icons.music_note,
        textColor: isDarkMode ? Colors.amber.shade300 : Colors.amber.shade900,
        backgroundColor: Colors.amber,
        borderColor: Colors.amber.shade700,
      );
    } else if (lower.contains('bridge') || lower == 'sob' || lower == 'b') {
      return _SectionStyle(
        icon: Icons.link,
        textColor: isDarkMode ? Colors.purple.shade300 : Colors.purple.shade800,
        backgroundColor: Colors.purple,
        borderColor: Colors.purple.shade600,
      );
    } else if (lower.contains('intro')) {
      return _SectionStyle(
        icon: Icons.play_circle_outline,
        textColor: isDarkMode ? Colors.green.shade300 : Colors.green.shade800,
        backgroundColor: Colors.green,
        borderColor: Colors.green.shade600,
      );
    } else if (lower.contains('outro')) {
      return _SectionStyle(
        icon: Icons.stop_circle_outlined,
        textColor: isDarkMode ? Colors.red.shade300 : Colors.red.shade800,
        backgroundColor: Colors.red,
        borderColor: Colors.red.shade600,
      );
    } else if (lower.contains('tab') || lower == 'sot') {
      return _SectionStyle(
        icon: Icons.grid_on,
        textColor: isDarkMode ? Colors.teal.shade300 : Colors.teal.shade800,
        backgroundColor: Colors.teal,
        borderColor: Colors.teal.shade600,
      );
    } else if (lower.contains('grid') || lower == 'sog') {
      return _SectionStyle(
        icon: Icons.grid_4x4,
        textColor: isDarkMode ? Colors.cyan.shade300 : Colors.cyan.shade800,
        backgroundColor: Colors.cyan,
        borderColor: Colors.cyan.shade600,
      );
    }
    
    // Default style for unknown section types
    return _SectionStyle(
      icon: Icons.label,
      textColor: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
      backgroundColor: Colors.grey,
      borderColor: Colors.grey.shade600,
    );
  }
}

/// Helper class to hold section styling information
class _SectionStyle {
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  _SectionStyle({
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
