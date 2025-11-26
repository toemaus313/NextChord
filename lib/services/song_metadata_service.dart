import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of an online song metadata lookup
class SongMetadataLookupResult {
  final double? tempoBpm;
  final String? key;
  final String? timeSignature;
  final int? durationMs;
  final String? correctedTitle;
  final String? correctedArtist;
  final bool success;
  final bool partialSuccess;
  final String? error;

  const SongMetadataLookupResult({
    this.tempoBpm,
    this.key,
    this.timeSignature,
    this.durationMs,
    this.correctedTitle,
    this.correctedArtist,
    required this.success,
    this.partialSuccess = false,
    this.error,
  });

  factory SongMetadataLookupResult.success({
    double? tempoBpm,
    String? key,
    String? timeSignature,
    int? durationMs,
    String? correctedTitle,
    String? correctedArtist,
    bool partialSuccess = false,
  }) {
    return SongMetadataLookupResult(
      tempoBpm: tempoBpm,
      key: key,
      timeSignature: timeSignature,
      durationMs: durationMs,
      correctedTitle: correctedTitle,
      correctedArtist: correctedArtist,
      success: true,
      partialSuccess: partialSuccess,
    );
  }

  factory SongMetadataLookupResult.error(String error) {
    return SongMetadataLookupResult(
      success: false,
      partialSuccess: false,
      error: error,
    );
  }

  factory SongMetadataLookupResult.noMatch() {
    return SongMetadataLookupResult(
      success: false,
      partialSuccess: false,
      error: null,
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

  /// Fetch metadata from SongBPM API
  Future<_SongBpmResult?> _fetchFromSongBpm(String title, String artist) async {
    try {
      final lookup =
          'song:${Uri.encodeComponent(title)} artist:${Uri.encodeComponent(artist)}';
      final url = Uri.parse(
          '$_songBpmBaseUrl/search/?api_key=$_songBpmApiKey&type=both&lookup=$lookup&limit=1');

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
      String title, String artist) async {
    try {
      final query = 'recording:"$title" AND artist:"$artist"';
      final url = Uri.parse(
          '$_musicBrainzBaseUrl/recording/?query=$query&fmt=json&limit=5');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NextChord/1.0.0 ( tommy@antonovich.us )',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final recordings = data['recordings'] as List<dynamic>?;

      if (recordings == null || recordings.isEmpty) {
        return null;
      }

      // Find the best matching recording (highest score or first match)
      final bestRecording = recordings.first as Map<String, dynamic>;

      return _MusicBrainzResult(
        durationMs: _parseInt(bestRecording['length']),
      );
    } catch (e) {
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
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
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

  _MusicBrainzResult({
    this.durationMs,
  });

  bool hasCompleteData() => durationMs != null;
}
