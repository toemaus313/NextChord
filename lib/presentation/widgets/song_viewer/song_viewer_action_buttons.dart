import 'package:flutter/material.dart';
import '../../../core/constants/song_viewer_constants.dart';

/// Widget that builds action buttons for phone mode header
class SongViewerActionButtons extends StatelessWidget {
  final VoidCallback onDeleteSong;
  final VoidCallback onEditSong;

  const SongViewerActionButtons({
    Key? key,
    required this.onDeleteSong,
    required this.onEditSong,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Share button
        IconButton(
          icon: Icon(
            Icons.share,
            color: accent,
            size: 24, // Smaller size for phone header
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share functionality coming soon!')),
            );
          },
          tooltip: 'Share song',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4), // Tight padding for grouping
        ),
        // Delete button
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 24),
          onPressed: onDeleteSong,
          tooltip: 'Delete song',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4), // Tight padding for grouping
        ),
        // Edit button
        IconButton(
          icon: Icon(
            Icons.edit,
            color: accent,
            size: 24, // Smaller size for phone header
          ),
          onPressed: onEditSong,
          tooltip: 'Edit song',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4), // Tight padding for grouping
        ),
      ],
    );
  }
}
