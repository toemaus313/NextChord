import 'dart:convert';
import 'package:http/http.dart' as http;
import '../song_metadata_service.dart';

/// Service for identifying songs from lyrics using Genius API + existing metadata services
class SongIdentificationService {
  static const String _geniusApiUrl = 'https://api.genius.com/search';
  static const String _geniusAccessToken =
      'B1HC0WZSUdQ4OgH5M5WtOTJg7Wz94tmtcMm5PpdmzJjICDxzA9l6ErAdVQSQLXWy';
  static final SongMetadataService _metadataService = SongMetadataService();

  /// Attempts to identify a song from the given chord chart text
  /// Returns a map with rich metadata if found, null otherwise
  static Future<Map<String, dynamic>?> identifySong(String chordChart) async {
    try {
      // Step 1: Extract up to 3 lines of lyrics from chorus (most distinctive)
      final chorusLyrics = _extractFirstLyricLine(chordChart);

      if (chorusLyrics == null || chorusLyrics.trim().isEmpty) {
        return null;
      }

      // Step 2: Search Genius API for title/artist
      final geniusResult = await _searchGenius(chorusLyrics);

      if (geniusResult == null) {
        return null;
      }

      final title = geniusResult['title'];
      final artist = geniusResult['artist'];

      if (title == null || artist == null) {
        return null;
      }

      // Step 3: Fetch metadata from existing SongBPM + MusicBrainz pipeline
      final metadataResult = await _metadataService.fetchMetadata(
        title: title,
        artist: artist,
      );

      if (!metadataResult.success) {
        // Return just title/artist if metadata fetch fails
        return {
          'title': title,
          'artist': artist,
          'tempo_bpm': null,
          'key': null,
          'duration_seconds': null,
          'time_signature': null,
        };
      }

      // Step 4: Combine all results
      final combinedResult = {
        'title': metadataResult.correctedTitle ?? title,
        'artist': metadataResult.correctedArtist ?? artist,
        'tempo_bpm': metadataResult.tempoBpm?.round(),
        'key': metadataResult.key,
        'duration_seconds': metadataResult.durationMs != null
            ? (metadataResult.durationMs! / 1000).round()
            : null,
        'time_signature': metadataResult.timeSignature,
      };
      return combinedResult;
    } catch (e) {
      // Silently fail - song identification is optional
      return null;
    }
  }

  /// Extracts up to 3 meaningful lyric lines from chorus (most distinctive)
  static String? _extractFirstLyricLine(String chordChart) {
    final lines = chordChart.split('\n');

    bool foundChorusMarker = false;
    List<String> chorusLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check for chorus markers (case insensitive)
      if (line.toLowerCase().contains('[chorus') ||
          line.toLowerCase().contains('[refrain')) {
        foundChorusMarker = true;
        continue;
      }

      // If we found another section marker, stop collecting chorus lines
      if (foundChorusMarker && line.startsWith('[')) {
        break;
      }

      // If we found a chorus marker, collect up to 3 lines with actual words
      if (foundChorusMarker && line.isNotEmpty) {
        // If line contains multiple actual words (not just chord names)
        // Real lyrics have multiple words like "You are the only"
        // Chord lines have isolated patterns like "G  Dm  Cmaj7"
        final wordPattern = RegExp(r'\b[a-z]{3,}\s+[a-z]{3,}');
        if (wordPattern.hasMatch(line)) {
          chorusLines.add(line);

          // Stop after collecting 3 lines
          if (chorusLines.length >= 3) {
            break;
          }
        } else {}
      }
    }

    if (chorusLines.isEmpty) {
      return null;
    }

    // Join the collected chorus lines with newlines
    final fullChorus = chorusLines.join('\n');
    return fullChorus;
  }

  /// Searches Genius API for the given chorus lyrics
  static Future<Map<String, String>?> _searchGenius(String chorusLyrics) async {
    try {
      // Concatenate all chorus lines into one search query
      final searchQuery = chorusLyrics.replaceAll('\n', ' ').trim();

      final response = await http.get(
        Uri.parse('$_geniusApiUrl?q=${Uri.encodeComponent(searchQuery)}'),
        headers: {
          'Authorization': 'Bearer $_geniusAccessToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final hits = data['response']['hits'] as List<dynamic>?;

        if (hits == null || hits.isEmpty) {
          return null;
        }

        // Take first result
        final firstResult = hits[0]['result'] as Map<String, dynamic>;
        final title = firstResult['title'] as String?;
        final artist = firstResult['primary_artist']['name'] as String?;

        if (title != null && artist != null) {
          // Clean up title by removing parenthetical content
          final cleanTitle = _cleanTitle(title);

          return {
            'title': cleanTitle,
            'artist': artist,
          };
        }
      } else {}
    } catch (e) {
      // Silently fail on network errors
    }
    return null;
  }

  /// Cleans up song title by removing parenthetical content
  static String _cleanTitle(String title) {
    // Remove anything in parentheses including the parentheses
    final cleaned = title.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    return cleaned;
  }
}
