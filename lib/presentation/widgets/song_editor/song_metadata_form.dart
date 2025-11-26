import 'package:flutter/material.dart';
import '../../../services/song_editor/transposition_service.dart';
import '../../controllers/song_editor/song_editor_controller.dart';
import 'package:flutter/services.dart';
import 'capo_icon_painter.dart';
import 'metronome_icon_painter.dart';

/// Form widget for song metadata fields (title, artist, key, BPM, capo, etc.)
class SongMetadataForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController bpmController;
  final TextEditingController durationController;
  final String selectedKey;
  final int selectedCapo;
  final String selectedTimeSignature;
  final Color textColor;
  final bool isDarkMode;
  final bool hasSetlistContext;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<int> onCapoChanged;
  final ValueChanged<String> onTimeSignatureChanged;
  final OnlineMetadataStatus onlineMetadataStatus;

  const SongMetadataForm({
    super.key,
    required this.titleController,
    required this.artistController,
    required this.bpmController,
    required this.durationController,
    required this.selectedKey,
    required this.selectedCapo,
    required this.selectedTimeSignature,
    required this.textColor,
    required this.isDarkMode,
    required this.hasSetlistContext,
    required this.onKeyChanged,
    required this.onCapoChanged,
    required this.onTimeSignatureChanged,
    this.onlineMetadataStatus = OnlineMetadataStatus.idle,
  });

  static const List<String> keys = [
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
    'B',
    'Cm',
    'C#m',
    'Dm',
    'D#m',
    'Em',
    'Fm',
    'F#m',
    'Gm',
    'G#m',
    'Am',
    'A#m',
    'Bm'
  ];

  static const List<String> timeSignatures = ['4/4', '3/4', '6/8', '2/4'];

  /// Normalize flat keys to sharp keys for dropdown compatibility
  static String _normalizeKey(String key) {
    // Convert Unicode sharp (♯) to ASCII sharp (#) first
    final asciiSharpKey = key.replaceAll('♯', '#');
    return TranspositionService.flatToSharpMap[asciiSharpKey] ?? asciiSharpKey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title field
        TextFormField(
          controller: titleController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Title',
            labelStyle: TextStyle(fontSize: 13),
            hintText: 'Enter song title',
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.music_note, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Title is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Artist field
        TextFormField(
          controller: artistController,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Artist',
            labelStyle: TextStyle(fontSize: 13),
            hintText: 'Enter artist name',
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Artist is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Single row with Key, BPM, Capo, Time Signature, Duration
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final availableWidth = constraints.maxWidth;
            final columns = availableWidth > 1100
                ? 5
                : availableWidth > 900
                    ? 4
                    : availableWidth > 650
                        ? 3
                        : 2;
            final fieldWidth =
                (availableWidth - spacing * (columns - 1)) / columns;

            final fields = <Widget>[
              _buildKeyDropdown(fieldWidth),
              _buildBpmField(fieldWidth),
              _buildCapoDropdown(fieldWidth),
              _buildTimeSignatureDropdown(fieldWidth),
              _buildDurationField(fieldWidth),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: fields
                  .map((field) => SizedBox(
                        width: fieldWidth,
                        child: field,
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),

        // Online metadata status message
        _buildOnlineMetadataStatus(),
      ],
    );
  }

  Widget _buildKeyDropdown(double width) {
    final normalizedKey = _normalizeKey(selectedKey);
    return DropdownButtonFormField<String>(
      initialValue: normalizedKey,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.piano, size: 18),
        suffixIcon: hasSetlistContext
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SET',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderSide: hasSetlistContext
              ? const BorderSide(color: Colors.blue, width: 1.5)
              : BorderSide(
                  color:
                      isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      items: keys.map((key) {
        return DropdownMenuItem(
          value: key,
          child: Text(key, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onKeyChanged(value);
        }
      },
    );
  }

  Widget _buildBpmField(double width) {
    return TextFormField(
      controller: bpmController,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: CustomPaint(
            size: const Size(18, 18),
            painter: MetronomeIconPainter(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        hintText: '120',
        hintStyle: const TextStyle(fontSize: 12),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        final bpm = int.tryParse(value.trim());
        if (bpm == null || bpm < 1 || bpm > 300) {
          return 'Invalid';
        }
        return null;
      },
    );
  }

  Widget _buildCapoDropdown(double width) {
    return DropdownButtonFormField<int>(
      value: selectedCapo,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: CustomPaint(
            size: const Size(18, 18),
            painter: CapoIconPainter(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        suffixIcon: hasSetlistContext
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SET',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderSide: hasSetlistContext
              ? const BorderSide(color: Colors.blue, width: 1.5)
              : BorderSide(
                  color:
                      isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      items: List.generate(13, (index) => index).map((capo) {
        return DropdownMenuItem(
          value: capo,
          child: Text(capo.toString(), style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onCapoChanged(value);
        }
      },
    );
  }

  Widget _buildTimeSignatureDropdown(double width) {
    return DropdownButtonFormField<String>(
      value: selectedTimeSignature,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.timer, size: 18),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      items: timeSignatures.map((sig) {
        return DropdownMenuItem(
          value: sig,
          child: Text(sig, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onTimeSignatureChanged(value);
        }
      },
    );
  }

  Widget _buildDurationField(double width) {
    final pattern = RegExp(r'^\d{1,3}:\d{2}$'); // MM:SS or M:SS format
    return TextFormField(
      controller: durationController,
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.play_arrow, size: 18),
        hintText: '3:00',
        hintStyle: TextStyle(fontSize: 12),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      keyboardType: TextInputType.text,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        if (!pattern.hasMatch(value.trim())) {
          return 'Invalid duration format (use M:SS or MM:SS)';
        }
        return null;
      },
    );
  }

  Widget _buildOnlineMetadataStatus() {
    String statusText;
    Color statusColor;
    IconData? statusIcon;

    switch (onlineMetadataStatus) {
      case OnlineMetadataStatus.idle:
        // Show nothing or subtle text for idle state
        return const SizedBox.shrink();

      case OnlineMetadataStatus.searching:
        statusText = 'Song info: searching online…';
        statusColor = isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600;
        statusIcon = Icons.search;
        break;

      case OnlineMetadataStatus.found:
        statusText = 'Song info: details imported from online sources.';
        statusColor =
            isDarkMode ? Colors.green.shade300 : Colors.green.shade600;
        statusIcon = Icons.check_circle;
        break;

      case OnlineMetadataStatus.notFound:
        statusText = 'Song info: no online match found.';
        statusColor =
            isDarkMode ? Colors.orange.shade300 : Colors.orange.shade600;
        statusIcon = Icons.info_outline;
        break;

      case OnlineMetadataStatus.error:
        statusText =
            'Song info: error retrieving data. You can continue editing manually.';
        statusColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade600;
        statusIcon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onlineMetadataStatus == OnlineMetadataStatus.searching) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
