import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart';

/// Result of an online song metadata lookup
class SongMetadataLookupResult {
  final double? tempoBpm;
  final String? key;
  final String? timeSignature;
  final int? durationMs;
  final bool success;
  final bool partialSuccess;
  final String? error;

  const SongMetadataLookupResult({
    this.tempoBpm,
    this.key,
    this.timeSignature,
    this.durationMs,
    required this.success,
    required this.partialSuccess,
    this.error,
  });

  factory SongMetadataLookupResult.success({
    double? tempoBpm,
    String? key,
    String? timeSignature,
    int? durationMs,
    bool partialSuccess = false,
  }) {
    return SongMetadataLookupResult(
      tempoBpm: tempoBpm,
      key: key,
      timeSignature: timeSignature,
      durationMs: durationMs,
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
  static const String _songBpmBaseUrl = 'https://api.getsongbpm.com/v1';
  static const String _musicBrainzBaseUrl = 'https://musicbrainz.org/ws/2';

  // TODO: Move these to configuration following existing patterns
  static const String _songBpmApiKey = 'YOUR_SONGBPM_API_KEY';

  /// Fetch metadata from both SongBPM and MusicBrainz APIs in parallel
  Future<SongMetadataLookupResult> fetchMetadata({
    required String title,
    required String artist,
  }) async {
    // Check if SongBPM API key is properly configured
    if (_songBpmApiKey == 'YOUR_SONGBPM_API_KEY' || _songBpmApiKey.isEmpty) {
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
      final query = 'song:"$title" artist:"$artist"';
      final url = Uri.parse(
          '$_songBpmBaseUrl/search/?type=songs&query=$query&api_key=$_songBpmApiKey');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NextChord/1.0 (https://nextchord.app)',
        },
      );

      if (response.statusCode != 200) {
        myDebug('SongBPM API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final songs = data['songs'] as List<dynamic>?;

      if (songs == null || songs.isEmpty) {
        return null;
      }

      // Find the best matching song (highest relevance score or first match)
      final bestSong = songs.first as Map<String, dynamic>;

      return _SongBpmResult(
        tempo: _parseDouble(bestSong['tempo']),
        key: bestSong['key_of'] as String?,
        timeSignature: bestSong['time_sig'] as String?,
      );
    } catch (e) {
      myDebug('SongBPM fetch error: $e');
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
          'User-Agent': 'NextChord/1.0 (https://nextchord.app)',
        },
      );

      if (response.statusCode != 200) {
        myDebug('MusicBrainz API error: ${response.statusCode}');
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
      myDebug('MusicBrainz fetch error: $e');
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
      return SongMetadataLookupResult.noMatch();
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

  _SongBpmResult({
    this.tempo,
    this.key,
    this.timeSignature,
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
