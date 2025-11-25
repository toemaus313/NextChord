import 'package:nextchord/domain/entities/shared_import_payload.dart';
import 'package:nextchord/core/utils/ug_text_converter.dart';
import 'package:nextchord/domain/entities/song.dart';
import 'package:nextchord/data/database/app_database.dart';
import 'package:uuid/uuid.dart';
import '../../../main.dart' as main; // Import with prefix for main.myDebug
import 'content_type_detector.dart';

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
  /// Returns a Song entity ready for the editor (does NOT save to database)
  /// The UI layer should navigate to the editor with this Song for user review
  Future<Song?> handleSharedContent(SharedImportPayload payload) async {
    main.myDebug(
        'ShareImportService: handleSharedContent called with payload: $payload');
    try {
      final song = await importFromSharedContent(payload);
      main.myDebug(
          'ShareImportService: importFromSharedContent completed successfully');
      return song;
    } catch (e) {
      main.myDebug('ShareImportService: Error handling shared content: $e');
      return null;
    }
  }

  /// Route shared content to the correct parser
  /// Returns a Song entity (does NOT save to database)
  Future<Song?> importFromSharedContent(SharedImportPayload payload) async {
    main.myDebug('ShareImportService: importFromSharedContent starting');
    // 1) Identify UG vs non-UG
    if (!payload.isFromUltimateGuitar) {
      main.myDebug(
          'ShareImportService: Non-UG payload, handling generic import');
      // Use existing generic import behavior (no changes to current flows)
      return await _handleGenericImport(payload);
    }

    main.myDebug('ShareImportService: UG payload detected');

    // 2) For UG, decide tab vs chord-over-lyric using content analysis
    final contentText = payload.text ?? '';
    final isTab = ContentTypeDetector.isTabContent(contentText);

    if (isTab) {
      main.myDebug('ShareImportService: UG TAB import triggered');
      return await importUltimateGuitarTabSong(contentText,
          sourceUrl: payload.url);
    } else {
      main.myDebug('ShareImportService: UG chord-over-lyric import triggered');
      return await importUltimateGuitarChordSong(contentText,
          sourceUrl: payload.url);
    }
  }

  /// Import UG chord-over-lyric content using existing UGTextConverter
  /// Returns a Song entity (does NOT save to database)
  Future<Song> importUltimateGuitarChordSong(String rawText,
      {Uri? sourceUrl}) async {
    main.myDebug(
        'ShareImportService: Importing UG chord song, text length=${rawText.length}');
    try {
      final result = UGTextConverter.convertToChordPro(rawText);
      final chordProText = result['chordpro'] as String;
      final metadata = result['metadata'] as Map<String, String>;

      main.myDebug('ShareImportService: Extracted metadata: $metadata');
      main.myDebug(
          'ShareImportService: Converted to ChordPro, length=${chordProText.length}');

      // Create Song entity from parsed content
      final song = Song(
        id: const Uuid().v4(),
        title: metadata['title'] ?? 'Imported from Ultimate Guitar',
        artist: metadata['artist'] ?? '',
        body: chordProText,
        key: metadata['key'] ?? 'C',
        capo:
            metadata['capo'] != null ? int.tryParse(metadata['capo']!) ?? 0 : 0,
        bpm: metadata['bpm'] != null
            ? int.tryParse(metadata['bpm']!) ?? 120
            : 120,
        timeSignature: metadata['timeSignature'] ?? '4/4',
        tags: const ['Imported from Ultimate Guitar'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      main.myDebug(
          'ShareImportService: Created song entity: title="${song.title}", artist="${song.artist}"');
      main.myDebug(
          'ShareImportService: Returning song for editor (NOT saving to database)');

      return song;
    } catch (e) {
      main.myDebug('ShareImportService: Failed to import UG chord song: $e');
      throw Exception('Failed to import UG chord song: $e');
    }
  }

  /// Import UG tab content by wrapping tab blocks in {sot}/{eot} tags
  /// Returns a Song entity (does NOT save to database)
  Future<Song> importUltimateGuitarTabSong(String rawText,
      {Uri? sourceUrl}) async {
    main.myDebug(
        'ShareImportService: Importing UG tab song, text length=${rawText.length}');
    try {
      final chordProText = convertUltimateGuitarTabExportToChordPro(rawText);

      // Extract basic metadata from the raw text
      final metadata = _extractBasicMetadata(rawText);

      // Create Song entity from tab content
      final song = Song(
        id: const Uuid().v4(),
        title: metadata['title'] ?? 'Imported UG Tab',
        artist: metadata['artist'] ?? '',
        body: chordProText,
        tags: const ['Imported from Ultimate Guitar', 'Tab'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      main.myDebug(
          'ShareImportService: Created tab song entity: title="${song.title}", artist="${song.artist}"');
      main.myDebug(
          'ShareImportService: Returning tab song for editor (NOT saving to database)');

      return song;
    } catch (e) {
      main.myDebug('ShareImportService: Failed to import UG tab song: $e');
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

  /// Handle non-UG imports using existing generic behavior
  /// Returns a Song entity (does NOT save to database)
  Future<Song?> _handleGenericImport(SharedImportPayload payload) async {
    main.myDebug(
        'ShareImportService: Handling generic import (no changes to existing behavior)');
    // TODO: Route to existing generic import logic
    // For now, return null to indicate unsupported content
    return null;
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
