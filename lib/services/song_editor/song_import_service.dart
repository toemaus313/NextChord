import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/chordpro_parser.dart';
import '../../core/utils/ug_text_converter.dart';
import '../import/ultimate_guitar_import_service.dart';

/// Service for importing songs from various sources (files, Ultimate Guitar, text conversion)
class SongImportService {
  static const List<String> allowedExtensions = [
    'pro',
    'cho',
    'crd',
    'chopro',
    'chordpro',
    'txt'
  ];

  /// Import song data from a ChordPro file
  static Future<SongImportResult?> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // Parse as ChordPro text file
        final file = File(filePath);
        final content = await file.readAsString();

        // Extract metadata from ChordPro
        final metadata = ChordProParser.extractMetadata(content);

        return SongImportResult(
          success: true,
          title: metadata.title,
          artist: metadata.artist,
          key: metadata.key,
          capo: metadata.capo,
          tempo: metadata.tempo,
          timeSignature: metadata.time,
          duration: metadata.duration,
          body: content,
          fileName: fileName,
        );
      }
    } catch (e) {
      return SongImportResult(
        success: false,
        error: 'Error importing file: $e',
      );
    }

    return null;
  }

  /// Import song from Ultimate Guitar URL
  static Future<SongImportResult> importFromUltimateGuitar(String url) async {
    try {
      final importService = UltimateGuitarImportService();
      final result = await importService.importFromUrl(url);

      if (result.success) {
        final metadata =
            ChordProParser.extractMetadata(result.chordProContent!);

        return SongImportResult(
          success: true,
          title: result.title,
          artist: result.artist,
          key: metadata.key,
          capo: metadata.capo,
          tempo: metadata.tempo,
          timeSignature: metadata.time,
          duration: metadata.duration,
          body: result.chordProContent!,
          rawContent: result.rawContent,
        );
      } else {
        return SongImportResult(
          success: false,
          error: result.errorMessage ?? 'Unknown error',
        );
      }
    } catch (e) {
      return SongImportResult(
        success: false,
        error: 'Failed to import: $e',
      );
    }
  }

  /// Convert Ultimate Guitar text to ChordPro format
  static SongImportResult convertToChordPro(String ugText) {
    try {
      if (ugText.trim().isEmpty) {
        return SongImportResult(
          success: false,
          error: 'Paste some Ultimate Guitar text first',
        );
      }

      // Convert the text
      final result = UGTextConverter.convertToChordPro(ugText);
      final chordProContent = result['chordpro'] as String;
      final metadata = result['metadata'] as Map<String, String>;

      return SongImportResult(
        success: true,
        title: metadata['title'],
        artist: metadata['artist'],
        key: metadata['key'],
        capo: metadata['capo'] != null ? int.tryParse(metadata['capo']!) : null,
        tempo: metadata['bpm'],
        timeSignature: metadata['timeSignature'],
        body: chordProContent,
      );
    } catch (e) {
      return SongImportResult(
        success: false,
        error: 'Error converting text: $e',
      );
    }
  }

  /// Extract metadata from ChordPro content
  static SongMetadata extractMetadata(String chordProContent) {
    final metadata = ChordProParser.extractMetadata(chordProContent);

    return SongMetadata(
      title: metadata.title,
      artist: metadata.artist,
      key: metadata.key,
      capo: metadata.capo,
      tempo: metadata.tempo,
      timeSignature: metadata.time,
      duration: metadata.duration,
    );
  }
}

/// Result of a song import operation
class SongImportResult {
  final bool success;
  final String? title;
  final String? artist;
  final String? key;
  final int? capo;
  final String? tempo;
  final String? timeSignature;
  final String? duration;
  final String? body;
  final String? rawContent;
  final String? fileName;
  final String? error;

  const SongImportResult({
    required this.success,
    this.title,
    this.artist,
    this.key,
    this.capo,
    this.tempo,
    this.timeSignature,
    this.duration,
    this.body,
    this.rawContent,
    this.fileName,
    this.error,
  });
}

/// Song metadata extracted from import operations
class SongMetadata {
  final String? title;
  final String? artist;
  final String? key;
  final int? capo;
  final String? tempo;
  final String? timeSignature;
  final String? duration;

  const SongMetadata({
    this.title,
    this.artist,
    this.key,
    this.capo,
    this.tempo,
    this.timeSignature,
    this.duration,
  });
}
