import 'dart:convert';
import 'package:http/http.dart' as http;

// Debug logging for metadata lookup
bool isDebug = true;
void myDebug(String message) {
  if (isDebug) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    print('[$timestamp] METADATA_DEBUG: $message');
  }
}

/// Result of an online song metadata lookup
class SongMetadataLookupResult {
  final double? tempoBpm;
  final String? key;
  final String? timeSignature;
  final int? durationMs;
  final String? correctedTitle;
  final String? correctedArtist;
  final String? source;
  final bool success;
  final bool partialSuccess;
  final String? error;
  final bool missingDuration;

  const SongMetadataLookupResult({
    this.tempoBpm,
    this.key,
    this.timeSignature,
    this.durationMs,
    this.correctedTitle,
    this.correctedArtist,
    this.source,
    required this.success,
    this.partialSuccess = false,
    this.error,
    this.missingDuration = false,
  });

  factory SongMetadataLookupResult.success({
    double? tempoBpm,
    String? key,
    String? timeSignature,
    int? durationMs,
    String? correctedTitle,
    String? correctedArtist,
    String? source,
    bool partialSuccess = false,
    bool missingDuration = false,
  }) {
    return SongMetadataLookupResult(
      tempoBpm: tempoBpm,
      key: key,
      timeSignature: timeSignature,
      durationMs: durationMs,
      correctedTitle: correctedTitle,
      correctedArtist: correctedArtist,
      source: source,
      success: true,
      partialSuccess: partialSuccess,
      error: null,
      missingDuration: missingDuration,
    );
  }

  factory SongMetadataLookupResult.error(String error) {
    return SongMetadataLookupResult(
      success: false,
      partialSuccess: false,
      error: error,
      missingDuration: false,
    );
  }

  factory SongMetadataLookupResult.noMatch() {
    return SongMetadataLookupResult(
      success: false,
      partialSuccess: false,
      error: null,
      missingDuration: false,
    );
  }

  /// Convert duration from milliseconds to MM:SS format
  static String? formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return null;

    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Service for fetching song metadata from online sources (SongBPM + MusicBrainz)
class SongMetadataService {
  static const String _songBpmBaseUrl = 'https://api.getsong.co';
  static const String _musicBrainzBaseUrl = 'https://musicbrainz.org/ws/2';

  // TODO: Move these to configuration following existing patterns
  static const String _songBpmApiKey = '0b0d119c98912195fa14e1153cbd79e6';

  /// Fetch metadata from both SongBPM and MusicBrainz APIs in parallel
  Future<SongMetadataLookupResult> fetchMetadata({
    required String title,
    required String artist,
  }) async {
    // Check if SongBPM API key is properly configured
    if (_songBpmApiKey.isEmpty) {
      return SongMetadataLookupResult.error('SongBPM API key not configured');
    }

    try {
      // Fire both requests in parallel
      final results = await Future.wait([
        _fetchFromSongBpm(title, artist),
        _fetchFromMusicBrainz(title, artist),
      ]);

      final songBpmResult = results[0] as _SongBpmResult?;
      final musicBrainzResult = results[1] as _MusicBrainzResult?;

      // Merge results
      return _mergeResults(songBpmResult, musicBrainzResult);
    } catch (e) {
      return SongMetadataLookupResult.error('Network error: $e');
    }
  }

  /// Fetch title-only metadata from SongBPM API for confirmation flow
  Future<SongMetadataLookupResult> fetchTitleOnlyMetadata({
    required String title,
  }) async {
    myDebug('Starting fetchTitleOnlyMetadata for title: "$title"');

    // Check if SongBPM API key is properly configured
    if (_songBpmApiKey.isEmpty) {
      return SongMetadataLookupResult.error('SongBPM API key not configured');
    }

    try {
      // Only fetch from SongBPM for title-only search
      final songBpmResult = await _fetchFromSongBpm(title, null);
      myDebug(
          'SongBPM title-only result: tempo=${songBpmResult?.tempo}, key=${songBpmResult?.key}');

      if (songBpmResult == null) {
        return SongMetadataLookupResult.error(
            'No results found for title: $title');
      }

      // Return partial result for user confirmation
      return SongMetadataLookupResult.success(
        tempoBpm: songBpmResult.tempo,
        key: songBpmResult.key,
        timeSignature: songBpmResult.timeSignature,
        durationMs: null, // Will be fetched from MusicBrainz after confirmation
        correctedTitle: songBpmResult.correctedTitle,
        correctedArtist: songBpmResult.correctedArtist,
        source: 'SongBPM (title-only)',
      );
    } catch (e) {
      myDebug('Error in fetchTitleOnlyMetadata: $e');
      return SongMetadataLookupResult.error('Network error: $e');
    }
  }

  /// Complete title-only lookup by fetching duration from MusicBrainz
  Future<SongMetadataLookupResult> completeTitleOnlyLookup({
    required String title,
    required String? artist,
    required int tempo,
    required String? key,
    required String? timeSignature,
  }) async {
    myDebug(
        'Starting completeTitleOnlyLookup for title: "$title", artist: "$artist", tempo: $tempo');

    try {
      // Fetch duration from MusicBrainz
      myDebug('Calling MusicBrainz API for duration lookup');
      final musicBrainzResult = await _fetchFromMusicBrainz(title, artist);

      myDebug(
          'MusicBrainz result: duration=${musicBrainzResult?.durationMs}, title="${musicBrainzResult?.correctedTitle}", artist="${musicBrainzResult?.correctedArtist}"');

      final result = SongMetadataLookupResult.success(
        tempoBpm: tempo.toDouble(),
        key: key,
        timeSignature: timeSignature,
        durationMs: musicBrainzResult?.durationMs,
        correctedTitle: musicBrainzResult?.correctedTitle ?? title,
        correctedArtist: musicBrainzResult?.correctedArtist ?? artist,
        source: 'SongBPM + MusicBrainz',
      );

      myDebug(
          'Created final result with tempo=${result.tempoBpm}, key=${result.key}, duration=${result.durationMs}');
      return result;
    } catch (e) {
      myDebug('Error in completeTitleOnlyLookup: $e');
      return SongMetadataLookupResult.error('Failed to fetch duration: $e');
    }
  }

  /// Fetch metadata from SongBPM API
  Future<_SongBpmResult?> _fetchFromSongBpm(
      String title, String? artist) async {
    try {
      String lookup;
      String type;

      if (artist != null && artist.isNotEmpty) {
        // Title + Artist: use both type with song: and artist: prefixes
        lookup =
            'song:${Uri.encodeComponent(title)} artist:${Uri.encodeComponent(artist)}';
        type = 'both';
      } else {
        // Title only: use song type without prefix (just the title)
        lookup = Uri.encodeComponent(title);
        type = 'song';
      }

      final url = Uri.parse(
          '$_songBpmBaseUrl/search/?api_key=$_songBpmApiKey&type=$type&lookup=$lookup&limit=1');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NextChord/1.0.0 ( tommy@antonovich.us )',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('SongBPM API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final search = data['search'] as List<dynamic>?;

      if (search == null || search.isEmpty) {
        return null; // No data found
      }

      // Parse the song object according to documentation
      final song = search.first as Map<String, dynamic>;
      final artistData = song['artist'] as Map<String, dynamic>?;

      return _SongBpmResult(
        tempo: _parseDouble(song['tempo']),
        key: song['key_of'] as String?,
        timeSignature: song['time_sig'] as String?,
        correctedTitle: song['title'] as String?,
        correctedArtist: artistData?['name'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch metadata from MusicBrainz API
  Future<_MusicBrainzResult?> _fetchFromMusicBrainz(
      String title, String? artist) async {
    try {
      final query = artist != null && artist.isNotEmpty
          ? 'recording:"$title" AND artist:"$artist"'
          : 'recording:"$title"';
      final url = Uri.parse(
          '$_musicBrainzBaseUrl/recording/?query=$query&fmt=json&limit=5');

      myDebug('MusicBrainz API query: $url');
      myDebug('MusicBrainz query string: "$query"');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NextChord/1.0.0 ( tommy@antonovich.us )',
        },
      );

      myDebug('MusicBrainz response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        myDebug(
            'MusicBrainz API error: Status ${response.statusCode}, body: ${response.body}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      myDebug('MusicBrainz response data: ${response.body}');

      final recordings = data['recordings'] as List<dynamic>?;

      if (recordings == null || recordings.isEmpty) {
        myDebug('No recordings found in MusicBrainz response');
        return null;
      }

      // Find the first recording with duration data, or use first recording if none have duration
      Map<String, dynamic>? bestRecording;
      Map<String, dynamic>? recordingWithDuration;
      int? durationMs;

      for (int i = 0; i < recordings.length; i++) {
        final recording = recordings[i] as Map<String, dynamic>;
        myDebug(
            'Checking recording ${i + 1}/${recordings.length}: ${recording['title']}');

        if (bestRecording == null) {
          bestRecording = recording; // Use first recording for metadata
        }

        if (recording.containsKey('length')) {
          durationMs = recording['length'] as int?;
          recordingWithDuration = recording;
          myDebug(
              'Found duration in MusicBrainz recording ${i + 1}: ${durationMs}ms');
          break; // Found duration, stop searching
        }
      }

      if (durationMs == null) {
        myDebug(
            'No duration found in any of ${recordings.length} MusicBrainz recordings');
      }

      // Use the first recording for metadata consistency, even if duration comes from a different one
      final finalRecording = recordingWithDuration ?? bestRecording!;
      myDebug('Selected recording for metadata: ${finalRecording['title']}');

      return _MusicBrainzResult(
        durationMs: durationMs,
        correctedTitle: bestRecording?['title'] as String?,
        correctedArtist: () {
          final artistCredit = bestRecording?['artist-credit'] as List?;
          if (artistCredit?.isNotEmpty == true) {
            final firstArtist = artistCredit![0] as Map<String, dynamic>?;
            return firstArtist?['name'] as String?;
          }
          return null;
        }(),
        missingDuration: durationMs == null && recordings.isNotEmpty,
      );
    } catch (e) {
      myDebug('Exception in MusicBrainz API call: $e');
      return null;
    }
  }

  /// Merge results from both APIs into a single lookup result
  SongMetadataLookupResult _mergeResults(
    _SongBpmResult? songBpmResult,
    _MusicBrainzResult? musicBrainzResult,
  ) {
    final hasAnyData = songBpmResult != null || musicBrainzResult != null;

    if (!hasAnyData) {
      // Both APIs returned nothing - likely spelling error or obscure song
      return SongMetadataLookupResult.error(
        'No matches found for this song title and artist.\n\n'
        'Please check:\n'
        '• Song title spelling (try the official title)\n'
        '• Artist name spelling\n'
        '• Song might not be in our databases yet',
      );
    }

    // Check if we have partial data (some fields missing)
    final hasPartialData =
        (songBpmResult != null && !songBpmResult.hasCompleteData()) ||
            (musicBrainzResult != null && !musicBrainzResult.hasCompleteData());

    return SongMetadataLookupResult.success(
      tempoBpm: songBpmResult?.tempo,
      key: songBpmResult?.key,
      timeSignature: songBpmResult?.timeSignature,
      durationMs: musicBrainzResult?.durationMs,
      correctedTitle: songBpmResult?.correctedTitle,
      correctedArtist: songBpmResult?.correctedArtist,
      partialSuccess: hasPartialData,
      missingDuration: musicBrainzResult?.missingDuration ?? false,
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Internal result class for SongBPM data
class _SongBpmResult {
  final double? tempo;
  final String? key;
  final String? timeSignature;
  final String? correctedTitle;
  final String? correctedArtist;

  _SongBpmResult({
    this.tempo,
    this.key,
    this.timeSignature,
    this.correctedTitle,
    this.correctedArtist,
  });

  bool hasCompleteData() =>
      tempo != null && key != null && timeSignature != null;
}

/// Internal result class for MusicBrainz data
class _MusicBrainzResult {
  final int? durationMs;
  final String? correctedTitle;
  final String? correctedArtist;
  final bool missingDuration;

  _MusicBrainzResult({
    this.durationMs,
    this.correctedTitle,
    this.correctedArtist,
    this.missingDuration = false,
  });

  bool hasCompleteData() => durationMs != null;
}
