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
  Widget _buildSectionHeader(ChordProLine line) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        line.section ?? '',
        style: TextStyle(
          fontSize: fontSize * 1.2,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.amber.shade400 : Colors.blue.shade800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Build a comment line
  Widget _buildComment(ChordProLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        line.text,
        style: TextStyle(
          fontSize: fontSize * 0.9,
          fontStyle: FontStyle.italic,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
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

    for (final chordPos in line.chords) {
      // Add spacing before this chord
      if (chordPos.position > lastPos) {
        final spaces = chordPos.position - lastPos;
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
}
