import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/setlist.dart';
import '../../../domain/entities/song.dart';
import '../../providers/song_provider.dart';

/// Widget for managing songs within a setlist
///
/// Handles drag-and-drop reordering, selection mode, and bulk operations
/// for songs in a setlist.
class SetlistSongsEditor extends StatefulWidget {
  final List<SetlistSongItem> songs;
  final bool isLoading;
  final Function(List<SetlistSongItem>) onSongsChanged;
  final VoidCallback onAddSongs;

  const SetlistSongsEditor({
    Key? key,
    required this.songs,
    required this.isLoading,
    required this.onSongsChanged,
    required this.onAddSongs,
  }) : super(key: key);

  @override
  State<SetlistSongsEditor> createState() => _SetlistSongsEditorState();
}

class _SetlistSongsEditorState extends State<SetlistSongsEditor> {
  bool _isSelectionMode = false;
  final Set<String> _selectedSongs = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, child) {
        final songsMap = {
          for (final song in songProvider.songs) song.id: song,
        };

        if (widget.songs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            _buildSelectionControls(),
            _buildSongsList(songsMap),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Center(
            child: Text(
              'No songs in this setlist',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          // Add Songs button for empty setlist
          ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onAddSongs,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(36, 36),
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionControls() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Selection mode toggle
          ElevatedButton(
            onPressed: widget.isLoading
                ? null
                : () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      _selectedSongs.clear();
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSelectionMode
                  ? Colors.red.withAlpha(20)
                  : Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(36, 36),
            ),
            child: Icon(_isSelectionMode ? Icons.close : Icons.checklist,
                size: 20),
          ),
          const SizedBox(width: 8),
          // Bulk delete button
          if (_isSelectionMode && _selectedSongs.isNotEmpty)
            ElevatedButton(
              onPressed: widget.isLoading ? null : _deleteSelectedSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(40),
                foregroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(36, 36),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete, size: 16),
                  const SizedBox(width: 4),
                  Text('(${_selectedSongs.length})'),
                ],
              ),
            ),
          const Spacer(),
          // Add Songs button
          ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onAddSongs,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(36, 36),
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList(Map<String, Song> songsMap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: widget.songs.length,
        onReorder: _moveSong,
        buildDefaultDragHandles: false,
        itemBuilder: (context, index) {
          final item = widget.songs[index];
          final song = songsMap[item.songId];
          return _buildSongItem(item, song, index);
        },
        // Custom drag highlight color
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              return Material(
                color: const Color(0xFF0468cc).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                elevation: 4,
                child: child,
              );
            },
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildSongItem(SetlistSongItem item, Song? song, int index) {
    final title = song?.title ?? 'Unknown song';
    final artist = song?.artist ?? '';

    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Selection checkbox or drag handle
          if (_isSelectionMode)
            Checkbox(
              value: _selectedSongs.contains(item.id),
              onChanged: widget.isLoading
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedSongs.add(item.id);
                        } else {
                          _selectedSongs.remove(item.id);
                        }
                      });
                    },
              activeColor: Colors.white,
              checkColor: const Color(0xFF0468cc),
            )
          else
            ReorderableDragStartListener(
              index: index,
              child: const Icon(
                Icons.drag_indicator,
                color: Colors.white54,
                size: 16,
              ),
            ),
          const SizedBox(width: 8),
          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Remove button
          if (!_isSelectionMode)
            IconButton(
              onPressed: widget.isLoading ? null : () => _removeSong(index),
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.white54,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  void _moveSong(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newSongs = List<SetlistSongItem>.from(widget.songs);
    final item = newSongs.removeAt(oldIndex);
    newSongs.insert(newIndex, item);
    widget.onSongsChanged(newSongs);
  }

  void _removeSong(int index) {
    final newSongs = List<SetlistSongItem>.from(widget.songs);
    newSongs.removeAt(index);
    widget.onSongsChanged(newSongs);
  }

  void _deleteSelectedSongs() {
    final newSongs = widget.songs
        .where((item) => !_selectedSongs.contains(item.id))
        .toList();
    widget.onSongsChanged(newSongs);
    setState(() {
      _selectedSongs.clear();
      _isSelectionMode = false;
    });
  }
}
