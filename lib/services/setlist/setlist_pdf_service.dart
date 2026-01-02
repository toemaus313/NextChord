import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/entities/setlist.dart';
import '../../domain/entities/song.dart';
import 'dart:async';

class SetlistPdfService {
  Future<void> generateAndSaveSetlistPdf({
    required Setlist setlist,
    required Map<String, Song> songsMap,
  }) async {
    // Create PDF with proper font handling
    final pdf = pw.Document();

    // Load fonts
    final font = await _loadFont();
    final fontBold = await _loadFontBold();

    // Calculate pagination
    const double pageHeight = 792; // Letter page height in points
    const double margin = 72; // 1 inch margins
    const double titleHeight = 60;
    const double totalHeight = 40;
    const double itemHeight = 20; // Approximate height per item
    const double availableHeight = pageHeight - (margin * 2) - titleHeight - totalHeight;

    final maxItemsPerPage = (availableHeight / itemHeight).floor();

    // Split items into pages
    final pages = _splitItemsIntoPages(setlist, maxItemsPerPage);

    // Create pages
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageItems = pages[pageIndex];
      final isLastPage = pageIndex == pages.length - 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title (only on first page)
                if (pageIndex == 0) ...[
                  pw.Text(
                    setlist.name,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                // Page items
                ..._buildSetlistItems(pageItems, songsMap, font),
                // Total duration (only on last page)
                if (isLastPage) ...[
                  pw.SizedBox(height: 20),
                  _buildTotalDuration(setlist, songsMap, fontBold),
                ],
                // Page number
                pw.Spacer(),
                pw.Text(
                  'Page ${pageIndex + 1} of ${pages.length}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Use Printing.sharePdf which may have better threading behavior
    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${setlist.name}_setlist.pdf',
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('PDF generation timed out. Please try again.');
        },
      );
    } catch (e) {
      // If sharePdf fails, try layoutPdf as fallback
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: '${setlist.name}_setlist.pdf',
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('PDF generation timed out. Please try again.');
          },
        );
      } catch (layoutError) {
        throw Exception('Failed to generate PDF: $e. Fallback also failed: $layoutError');
      }
    }
  }

  List<List<SetlistItem>> _splitItemsIntoPages(Setlist setlist, int maxItemsPerPage) {
    final List<List<SetlistItem>> pages = [];
    final List<SetlistItem> currentPage = [];

    for (final item in setlist.items) {
      currentPage.add(item);

      // If we've reached the max items per page, start a new page
      if (currentPage.length >= maxItemsPerPage) {
        pages.add(List.from(currentPage));
        currentPage.clear();
      }
    }

    // Add any remaining items to the last page
    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    // Ensure we have at least one page
    if (pages.isEmpty) {
      pages.add([]);
    }

    return pages;
  }

  Future<pw.Font> _loadFont() async {
    // Use built-in Helvetica font to avoid network issues
    return pw.Font.helvetica();
  }

  Future<pw.Font> _loadFontBold() async {
    // Use built-in Helvetica Bold font to avoid network issues
    return pw.Font.helveticaBold();
  }

  List<pw.Widget> _buildSetlistItems(
      List<SetlistItem> items, Map<String, Song> songsMap, pw.Font font) {
    final List<pw.Widget> widgets = [];

    for (final item in items) {
      if (item is SetlistDividerItem) {
        final displayText = item.label;

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              displayText,
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (item is SetlistSongItem) {
        final song = songsMap[item.songId];
        if (song != null) {
          String displayKey = song.key;
          int capo = song.capo;

          if (item.transposeSteps != 0) {
            displayKey = _transposeKey(displayKey, item.transposeSteps);
          }
          if (item.capo != song.capo) {
            capo = item.capo;
          }

          final parts = <String>[
            song.title,
            song.artist,
            displayKey,
          ];

          if (capo > 0) {
            parts.add('Capo $capo');
          }

          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                parts.join(' - '),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  pw.Widget _buildTotalDuration(Setlist setlist, Map<String, Song> songsMap, pw.Font fontBold) {
    final totalDuration = _calculateTotalSetlistDuration(setlist, songsMap);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        'Total - $totalDuration',
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  int _parseDurationToSeconds(String duration) {
    final parts = duration.split(':');
    if (parts.length != 2) return 0;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;

    return (minutes * 60) + seconds;
  }

  String _calculateTotalSetlistDuration(Setlist setlist, Map<String, Song> songsMap) {
    int totalSeconds = 0;
    for (final item in setlist.items) {
      if (item is SetlistSongItem) {
        final song = songsMap[item.songId];
        if (song?.duration != null) {
          totalSeconds += _parseDurationToSeconds(song!.duration!);
        }
      }
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _transposeKey(String key, int steps) {
    const keys = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];

    if (key.isEmpty) return key;

    String baseKey = key.endsWith('m') ? key.substring(0, key.length - 1) : key;
    bool isMinor = key.endsWith('m');

    int? currentIndex = keys.indexOf(baseKey);
    if (currentIndex == -1) return key;

    int newIndex = (currentIndex + steps) % 12;
    if (newIndex < 0) newIndex += 12;

    String transposedKey = keys[newIndex];
    return isMinor ? '${transposedKey}m' : transposedKey;
  }
}
