import 'package:flutter/material.dart';
import '../../controllers/song_editor/song_editor_controller.dart';

/// Song settings widget for tags, time signature, and MIDI
class SongSettings extends StatelessWidget {
  final SongEditorController controller;

  const SongSettings({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTimeSignatureSection(),
        const SizedBox(height: 16),
        _buildTagsSection(),
        const SizedBox(height: 16),
        _buildMidiSection(),
      ],
    );
  }

  Widget _buildTimeSignatureSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time Signature',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButton<String>(
              value: controller.timeSignature,
              isExpanded: true,
              dropdownColor: const Color(0xFF0468cc),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items:
                  SongEditorController.availableTimeSignatures.map((timeSig) {
                return DropdownMenuItem(
                  value: timeSig,
                  child: Text(timeSig),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.setTimeSignature(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.tag,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tags',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          if (controller.tags.isEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'No tags added',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    controller.tags.map((tag) => _buildTagChip(tag)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeTag(tag),
            child: Icon(
              Icons.close,
              size: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMidiSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.piano,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'MIDI Profile',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: controller.selectedMidiProfile != null
                  ? Row(
                      children: [
                        Icon(
                          Icons.piano,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.selectedMidiProfile!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              controller.setSelectedMidiProfile(null),
                          child: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.piano_outlined,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No MIDI profile selected',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showMidiProfileSelector(),
                          child: const Text('Select'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

    // Implementation would show tag input dialog
    // For now, just a placeholder
  }

  void _removeTag(String tag) {
    final newTags = List<String>.from(controller.tags)..remove(tag);
    controller.setTags(newTags);
  }

  void _showMidiProfileSelector() {
    // Implementation would show MIDI profile selection dialog
    // For now, just a placeholder
  }
}
