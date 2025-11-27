import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../core/utils/ultimate_guitar_parser.dart';

/// Result of an Ultimate Guitar import attempt
class ImportResult {
  final bool success;
  final String? title;
  final String? artist;
  final String? chordProContent;
  final String? rawContent;
  final String? errorMessage;

  ImportResult({
    required this.success,
    this.title,
    this.artist,
    this.chordProContent,
    this.rawContent,
    this.errorMessage,
  });

  ImportResult.success({
    required String title,
    required String artist,
    required String chordProContent,
    required String rawContent,
  }) : this(
          success: true,
          title: title,
          artist: artist,
          chordProContent: chordProContent,
          rawContent: rawContent,
        );

  ImportResult.error(String message)
      : this(
          success: false,
          errorMessage: message,
        );
}

/// Service for importing songs from Ultimate Guitar
class UltimateGuitarImportService {
  /// Check if running on desktop platform
  bool _isDesktop() {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Import a song from an Ultimate Guitar URL
  ///
  /// Example URL: https://tabs.ultimate-guitar.com/tab/icehouse/crazy-chords-125754
  Future<ImportResult> importFromUrl(String url) async {
    try {
      // Validate URL
      if (!_isValidUltimateGuitarUrl(url)) {
        return ImportResult.error(
          'Invalid Ultimate Guitar URL. Please use a URL like:\n'
          'https://tabs.ultimate-guitar.com/tab/artist/song-chords-123456',
        );
      }

      // Block official tab URLs on mobile devices
      if (!_isDesktop() && url.contains('-official-')) {
        return ImportResult.error(
          'Official tab URLs not supported with this import method - use "Open With..." option after pressing the Share button from Ultimate Guitar app instead',
        );
      }

      // Fetch the page
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return ImportResult.error(
          'Failed to fetch page. Status code: ${response.statusCode}',
        );
      }

      // Parse HTML
      final document = html_parser.parse(response.body);

      // Find the data store element
      final storeElement = document.querySelector('.js-store');
      if (storeElement == null) {
        return ImportResult.error(
          'Could not find song data on the page. The page format may have changed.',
        );
      }

      // Extract JSON data
      final dataContent = storeElement.attributes['data-content'];
      if (dataContent == null || dataContent.isEmpty) {
        return ImportResult.error(
          'Could not extract song data from the page.',
        );
      }

      // Parse JSON
      final jsonData = json.decode(dataContent) as Map<String, dynamic>;

      // Navigate to the tab content
      final store = jsonData['store'] as Map<String, dynamic>?;
      if (store == null) {
        return ImportResult.error('Invalid tab data: missing store');
      }

      final page = store['page'] as Map<String, dynamic>?;
      if (page == null) {
        return ImportResult.error('Invalid tab data: missing page');
      }

      final data = page['data'] as Map<String, dynamic>?;
      if (data == null) {
        return ImportResult.error('Invalid tab data: missing data');
      }

      // Try regular tab structure first (existing functionality)
      String? content;
      String? songName;
      String? artistName;

      final tab = data['tab'] as Map<String, dynamic>?;
      if (tab != null) {
        // Regular tab structure (existing code path)
        final tabView = data['tab_view'] as Map<String, dynamic>?;
        if (tabView == null) {
          return ImportResult.error('Invalid tab data: missing tab_view');
        }
        final wikiTab = tabView['wiki_tab'] as Map<String, dynamic>?;
        if (wikiTab == null) {
          return ImportResult.error('Invalid tab data: missing wiki_tab');
        }
        content = wikiTab['content'] as String?;
        songName = tab['song_name'] as String?;
        artistName = tab['artist_name'] as String?;
      } else {
        return ImportResult.error('Invalid tab data: missing tab');
      }

      if (content == null || content.isEmpty) {
        return ImportResult.error('No chord content found in the tab');
      }

      // Convert to ChordPro format
      final chordProContent = UltimateGuitarParser.convertToChordPro(content);

      if (chordProContent.isEmpty) {
        return ImportResult.error('Failed to convert tab content');
      }

      return ImportResult.success(
        title: songName ?? 'Unknown',
        artist: artistName ?? 'Unknown',
        chordProContent: chordProContent,
        rawContent: content,
      );
    } catch (e) {
      return ImportResult.error(
        'Error importing tab: ${e.toString()}',
      );
    }
  }

  /// Validate if the URL is a valid Ultimate Guitar tab URL
  bool _isValidUltimateGuitarUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.contains('ultimate-guitar.com') &&
          uri.path.contains('/tab/');
    } catch (e) {
      return false;
    }
  }
}
