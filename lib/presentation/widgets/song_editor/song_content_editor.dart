import 'package:flutter/material.dart';
import '../../controllers/song_editor/song_editor_controller.dart';

/// Song content editor widget with transposition tools
class SongContentEditor extends StatelessWidget {
  final SongEditorController controller;

  const SongContentEditor({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          _buildHeader(),
          const SizedBox(height: 12),
          _buildBodyField(),
          if (controller.showKeyboard) ...[
            const SizedBox(height: 12),
            _buildKeyboardPlaceholder(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Song Content',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _buildTransposeButtons(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => controller.toggleKeyboard(),
            icon: Icon(
              controller.showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
              color: Colors.white70,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip:
                controller.showKeyboard ? 'Hide Keyboard' : 'Show Keyboard',
          ),
        ],
      ),
    );
  }

  Widget _buildTransposeButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Transpose:',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => controller.transposeBody(-1),
          icon: const Icon(Icons.remove, size: 16),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(4),
            minimumSize: const Size(24, 24),
          ),
        ),
        IconButton(
          onPressed: () => controller.transposeBody(1),
          icon: const Icon(Icons.add, size: 16),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(4),
            minimumSize: const Size(24, 24),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller.bodyController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          labelText: 'ChordPro Content',
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
          hintText:
              '{title: Song Title}\n{artist: Artist Name}\n\nVerse 1:\n[C]Chord [G]lyrics [F]here\n\nChorus:\n[C]More [G]chord [F]lyrics',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontFamily: 'monospace',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
        maxLines: 15,
        minLines: 8,
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }

  Widget _buildKeyboardPlaceholder() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.piano,
              size: 32,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Virtual Keyboard',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Interactive chord reference would appear here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
