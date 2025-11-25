/// Represents shared content received from other apps (e.g., Ultimate Guitar)
/// Unified model for cross-platform share handling
class SharedImportPayload {
  /// The shared text content (song chords, tab, etc.)
  final String? text;

  /// The shared URL if any (e.g., ultimate-guitar.com link)
  final Uri? url;

  /// The content type (text, url, or both)
  final SharedImportType type;

  /// Source app name if available
  final String? sourceApp;

  const SharedImportPayload({
    this.text,
    this.url,
    required this.type,
    this.sourceApp,
  });

  /// Create payload from text-only share
  factory SharedImportPayload.text(String text, {String? sourceApp}) =>
      SharedImportPayload(
        text: text,
        type: SharedImportType.text,
        sourceApp: sourceApp,
      );

  /// Create payload from URL-only share
  factory SharedImportPayload.url(Uri url, {String? sourceApp}) =>
      SharedImportPayload(
        url: url,
        type: SharedImportType.url,
        sourceApp: sourceApp,
      );

  /// Create payload from combined text + URL share
  factory SharedImportPayload.combined(String text, Uri url,
          {String? sourceApp}) =>
      SharedImportPayload(
        text: text,
        url: url,
        type: SharedImportType.combined,
        sourceApp: sourceApp,
      );

  /// Check if this payload appears to be from Ultimate Guitar
  bool get isFromUltimateGuitar {
    final urlHost = url?.host.toLowerCase();
    final textLower = text?.toLowerCase();

    // Check URL
    if (urlHost?.contains('ultimate-guitar.com') == true) {
      return true;
    }

    // Check text content for UG markers
    if (textLower != null) {
      // Common UG markers in shared content
      if (textLower.contains('ultimate-guitar.com') ||
          textLower.contains('ultimate guitar') ||
          textLower.contains('www.ultimate-guitar.com') ||
          textLower.contains('tabs.ultimate-guitar.com')) {
        return true;
      }

      // If text looks like a song with chords or tabs, treat it as UG content
      // (UG exports often don't include the URL in the text)
      if (_looksLikeGuitarContent(textLower)) {
        return true;
      }
    }

    return false;
  }

  /// Helper to detect if text looks like guitar chords or tabs
  bool _looksLikeGuitarContent(String text) {
    // Check for common chord patterns
    final hasChordPattern = text.contains(RegExp(r'\[([A-G][#b]?m?[0-9]?)\]'));

    // Check for tab notation (e|B|G|D|A|E strings)
    final hasTabPattern = text.contains(RegExp(r'[eEbBgGdDaA]\|'));

    // Check for "Capo", "Tuning", etc.
    final hasGuitarTerms = text.contains('capo') ||
        text.contains('tuning') ||
        text.contains('intro:') ||
        text.contains('verse:') ||
        text.contains('chorus:');

    return hasChordPattern || hasTabPattern || hasGuitarTerms;
  }

  /// Check if the URL indicates a tab page (vs chord/pro page)
  bool get isUltimateGuitarTab {
    if (!isFromUltimateGuitar || url == null) return false;

    final path = url!.path.toLowerCase();
    return path.contains('/tab') || path.startsWith('/tab');
  }

  @override
  String toString() {
    return 'SharedImportPayload(type: $type, url: $url, textLength: ${text?.length}, source: $sourceApp)';
  }
}

/// Types of shared content
enum SharedImportType {
  text,
  url,
  combined,
}
