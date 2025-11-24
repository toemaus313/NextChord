import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/setlist.dart';
import '../../providers/song_provider.dart';
import '../../controllers/setlist_editor/setlist_editor_controller.dart';

/// Setlist songs widget with drag-and-drop functionality
class SetlistSongs extends StatefulWidget {
  final SetlistEditorController controller;

  const SetlistSongs({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<SetlistSongs> createState() => _SetlistSongsState();
}

class _SetlistSongsState extends State<SetlistSongs> {
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Songs',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Songs'),
                  onPressed: () => _showAddSongsDialog(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.horizontal_rule, size: 16),
                  label: const Text('Add Divider'),
                  onPressed: () => _showAddDividerDialog(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          if (widget.controller.items.isEmpty)
            _buildEmptyState()
          else
            _buildSongsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.queue_music_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No songs added',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs and dividers to build your setlist',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: widget.controller.items.length,
      onReorder: widget.controller.moveItem,
      itemBuilder: (context, index) {
        final item = widget.controller.items[index];

        if (item is SetlistSongItem) {
          return _buildSongItem(item, index);
        } else if (item is SetlistDividerItem) {
          return _buildDividerItem(item, index);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSongItem(SetlistSongItem item, int index) {
    return Consumer<SongProvider>(
      key: ValueKey('song_${item.id}'),
      builder: (context, songProvider, child) {
        final song =
            songProvider.songs.where((s) => s.id == item.songId).firstOrNull;

        return Container(
          key: ValueKey('song_${item.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            dense: true,
            leading: ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: Colors.white.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            title: Text(
              song?.title ?? 'Unknown Song',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: song?.artist.isNotEmpty == true
                ? Text(
                    song!.artist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song?.key.isNotEmpty == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      song!.key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => widget.controller.removeItemAt(index),
                  icon: const Icon(Icons.remove_circle,
                      size: 18, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDividerItem(SetlistDividerItem item, int index) {
    return Container(
      key: ValueKey('divider_${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
        title: Text(
          item.label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
        trailing: IconButton(
          onPressed: () => widget.controller.removeItemAt(index),
          icon: const Icon(Icons.remove_circle, size: 18, color: Colors.red),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  void _showAddSongsDialog() {
    // Implementation would show song selection dialog
    // For now, just a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Songs'),
        content: const Text('Song selection dialog would appear here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddDividerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Divider'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Divider Text',
            hintText: 'e.g., "Encore", "Intermission"',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.controller.addDivider(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
