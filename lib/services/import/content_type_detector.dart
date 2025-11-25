/// Service to detect the type of guitar content (tab vs chord-over-lyric)
/// Used to route imported content to the appropriate parser
class ContentTypeDetector {
  /// Detect if content is guitar tablature notation
  /// Returns true if the content contains ASCII tab patterns
  ///
  /// NOTE: This analysis is performed on "naked" tab content (without {sot}/{eot} tags).
  /// Our importers add those tags during conversion. Mixed content (mostly chords with
  /// some inline tab snippets) will be classified as CHORD format, which is correct.
  static bool isTabContent(String content) {
    if (content.isEmpty) {
      return false;
    }

    final lines = content.split('\n');
    int tabLineCount = 0;
    int totalLines = lines.length;

    // Look for classic guitar tab string indicators
    // Tab lines typically look like: e|---5---7---|
    // Note: Incoming content won't have {sot}/{eot} tags yet - those are added during conversion
    final tabStringPattern =
        RegExp(r'^[eEbBgGdDaA]\s*\|[\d\-\|pshmr/\\~xXoO ]+');

    // Look for multiple pipes in sequence (common in tabs)
    final multiplePipesPattern = RegExp(r'\|.*\|.*\|');

    for (final line in lines) {
      final trimmed = line.trim();

      // Skip empty lines and section markers
      if (trimmed.isEmpty || trimmed.startsWith('[')) {
        continue;
      }

      // Check for explicit tab string notation (e|B|G|D|A|E format)
      if (tabStringPattern.hasMatch(trimmed)) {
        tabLineCount++;
      }

      // Check for lines with multiple pipes (very common in tabs, rare in chords)
      if (multiplePipesPattern.hasMatch(trimmed) &&
          trimmed.split('|').length > 3) {
        tabLineCount++;
      }
    }

    // THRESHOLD CONFIGURATION:
    // If more than 20% of non-empty lines look like tab notation, classify as TAB.
    // This allows for mixed content (chords with some tab snippets) to be classified as CHORD.
    // To adjust sensitivity:
    //   - Increase threshold (e.g., 0.3 = 30%) to require more tab content before classifying as TAB
    //   - Decrease threshold (e.g., 0.1 = 10%) to classify as TAB more aggressively
    final threshold = (totalLines * 0.2).round();
    final isTab = tabLineCount >= threshold && tabLineCount >= 3;

    return isTab;
  }

  /// Detect if content is chord-over-lyric notation
  /// This is the default format if it's not tab
  static bool isChordOverLyricContent(String content) {
    return !isTabContent(content);
  }
}
