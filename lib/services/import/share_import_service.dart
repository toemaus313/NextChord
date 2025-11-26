import 'package:nextchord/domain/entities/shared_import_payload.dart';
import 'package:nextchord/core/utils/ug_text_converter.dart';
import 'package:nextchord/domain/entities/song.dart';
import 'package:nextchord/data/database/app_database.dart';
import 'package:nextchord/services/import/song_identification_service.dart';

/// Service for handling shared content from other apps (e.g., Ultimate Guitar)
/// Routes content to appropriate parsers based on source and type detection
class ShareImportService {
  static final ShareImportService _instance = ShareImportService._internal();
  factory ShareImportService() => _instance;
  ShareImportService._internal();

  // Note: Service no longer saves to database - it returns Song entities
  // for the UI layer to handle. No database dependency needed.
  void initialize(AppDatabase database) {
    // Kept for backwards compatibility but no longer needed
  }

  /// Main entry point for handling shared content
  /// Returns a Song entity with EMPTY ID and raw text in body
  /// This follows the exact same flow as creating a new song
  Future<Song?> handleSharedContent(SharedImportPayload payload) async {
    try {
      print("📥 ShareImportService: handleSharedContent called");
      print("📥 ShareImportService: sourceApp = '${payload.sourceApp}'");
      print(
          "📥 ShareImportService: text length = ${payload.text?.length ?? 0}");

      if (payload.text != null && payload.text!.isNotEmpty) {
        // Try to identify song from lyrics and fetch metadata
        String title = '';
        String artist = '';
        String? key;
        int? bpm;
        String? duration;
        String? timeSignature;

        if (payload.sourceApp == 'Ultimate Guitar') {
          print(
              "📥 ShareImportService: Source is Ultimate Guitar, attempting song identification");
          final identification =
              await SongIdentificationService.identifySong(payload.text!);
          print(
              "📥 ShareImportService: Identification result: $identification");
          if (identification != null) {
            title = identification['title'] ?? '';
            artist = identification['artist'] ?? '';
            bpm = identification['tempo_bpm'] as int?;
            key = identification['key'] as String?;
            final durationSeconds = identification['duration_seconds'] as int?;
            if (durationSeconds != null) {
              final minutes = durationSeconds ~/ 60;
              final seconds = durationSeconds % 60;
              duration = '$minutes:${seconds.toString().padLeft(2, '0')}';
            }
            timeSignature = identification['time_signature'] as String?;
            print(
                "📥 ShareImportService: Extracted metadata - Title: '$title', Artist: '$artist', BPM: $bpm, Key: $key, Duration: $duration, Time Sig: $timeSignature");
          }
        } else {
          print(
              "📥 ShareImportService: Source is not Ultimate Guitar, skipping identification");
        }

        // Step 4: Convert raw UG text to ChordPro format
        print("📥 ShareImportService: Converting to ChordPro format...");
        final conversionResult =
            UGTextConverter.convertToChordPro(payload.text!);
        final chordProText = conversionResult['chordpro'] as String;
        print("📥 ShareImportService: ChordPro conversion complete");

        // Create song with identified metadata and converted ChordPro body
        print(
            "📥 ShareImportService: Creating Song with title: '$title', artist: '$artist'");
        return Song(
          id: '', // EMPTY ID - insertSong will generate it
          title: title, // Auto-populated if identified, otherwise empty
          artist: artist, // Auto-populated if identified, otherwise empty
          body: chordProText, // Converted ChordPro format text
          key: key ?? 'C', // Use identified key or default to C
          bpm: bpm ?? 120, // Use identified BPM or default to 120
          duration: duration, // Use identified duration or null
          timeSignature:
              timeSignature ?? '4/4', // Use identified or default to 4/4
          tags: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        throw Exception('No text content in shared data');
      }
    } catch (e) {
      print("📥 ShareImportService: Error: $e");
      throw Exception('Failed to handle shared content: $e');
    }
  }

  /// Import UG chord-over-lyric content using existing UGTextConverter
  /// Returns a Song entity (does NOT save to database)
  Future<Song> importUltimateGuitarChordSong(String rawText,
      {Uri? sourceUrl}) async {
    try {
      final result = UGTextConverter.convertToChordPro(rawText);
      final chordProText = result['chordpro'] as String;
      final metadata = result['metadata'] as Map<String, String>;

      // Create Song entity from parsed content
      // Leave title blank if not in ChordPro metadata - user must fill it in
      final song = Song(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: metadata['title'] ?? '',
        artist: metadata['artist'] ?? '',
        body: chordProText,
        key: metadata['key'] ?? 'C',
        capo:
            metadata['capo'] != null ? int.tryParse(metadata['capo']!) ?? 0 : 0,
        bpm: metadata['bpm'] != null
            ? int.tryParse(metadata['bpm']!) ?? 120
            : 120,
        timeSignature: metadata['timeSignature'] ?? '4/4',
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return song;
    } catch (e) {
      throw Exception('Failed to import UG chord song: $e');
    }
  }

  /// Import UG tab content by wrapping tab blocks in {sot}/{eot} tags
  /// Returns a Song entity (does NOT save to database)
  Future<Song> importUltimateGuitarTabSong(String rawText,
      {Uri? sourceUrl}) async {
    try {
      final chordProText = convertUltimateGuitarTabExportToChordPro(rawText);

      // Extract basic metadata from the raw text
      final metadata = _extractBasicMetadata(rawText);

      // Create Song entity from tab content
      // Leave title blank if not in metadata - user must fill it in
      final song = Song(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: metadata['title'] ?? '',
        artist: metadata['artist'] ?? '',
        body: chordProText,
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return song;
    } catch (e) {
      throw Exception('Failed to import UG tab song: $e');
    }
  }

  /// Convert UG tab export to ChordPro format with {sot}/{eot} tags
  /// Reuses existing tab detection from UGTextConverter
  String convertUltimateGuitarTabExportToChordPro(String rawText) {
    final lines = rawText.split('\n');
    final result = <String>[];

    bool insideTabBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Skip empty lines initially
      if (trimmedLine.isEmpty) {
        if (insideTabBlock) {
          result.add('');
        }
        continue;
      }

      // Check if this line looks like tab content (simple inline check)
      // Tab lines typically start with string notation (e|, B|, etc.) and contain numbers/dashes
      final isTabLine = trimmedLine.contains(RegExp(r'^[eEbBgGdDaA]\s*\|')) ||
          (trimmedLine.contains('|') &&
              trimmedLine.contains(RegExp(r'[\d\-]{3,}')));

      if (isTabLine) {
        // Start a tab block if we're not already in one
        if (!insideTabBlock) {
          result.add('{sot}');
          insideTabBlock = true;
        }
        result.add(line);
      } else {
        // End tab block if we were in one
        if (insideTabBlock) {
          result.add('{eot}');
          insideTabBlock = false;
        }
        result.add(line);
      }
    }

    // Close any open tab block at the end
    if (insideTabBlock) {
      result.add('{eot}');
    }

    return result.join('\n');
  }

  /// Extract basic metadata from raw UG text (simplified version)
  Map<String, String> _extractBasicMetadata(String rawText) {
    final metadata = <String, String>{};
    final lines = rawText.split('\n');

    for (int i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Check for "Title by Artist" pattern
      final byPattern = RegExp(r'\s+by\s+', caseSensitive: false);
      if (byPattern.hasMatch(line) && metadata['title'] == null) {
        final parts = line.split(byPattern);
        if (parts.length >= 2) {
          final title = parts[0]
              .replaceAll(RegExp(r'\s+Official', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s+Tab', caseSensitive: false), '')
              .trim();
          final artist = parts[1].trim();
          if (title.isNotEmpty && artist.isNotEmpty) {
            metadata['title'] = title;
            metadata['artist'] = artist;
            continue;
          }
        }
      }

      // Check for "by Artist" as separate line
      if (line.toLowerCase().startsWith('by ') && metadata['artist'] == null) {
        metadata['artist'] = line.substring(3).trim();
        continue;
      }

      // First non-empty line as title if not found yet
      if (metadata['title'] == null && !line.toLowerCase().startsWith('by')) {
        final title = line
            .replaceAll(RegExp(r'\s+Official', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+Tab', caseSensitive: false), '')
            .trim();
        if (title.isNotEmpty) {
          metadata['title'] = title;
        }
      }
    }

    return metadata;
  }
}
