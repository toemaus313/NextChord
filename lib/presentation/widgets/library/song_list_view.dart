import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/song.dart';
import '../../providers/song_provider.dart';
import '../song_list_tile.dart';
import '../sidebar_select_all_bar.dart';

/// Widget that displays the list of songs with selection support
class SongListView extends StatelessWidget {
  final bool inSidebar;
  final Function(Song)? onSongSelected;
  final bool showSelectionControls;

  const SongListView({
    Key? key,
    this.inSidebar = false,
    this.onSongSelected,
    this.showSelectionControls = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.songs.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            // Selection controls (select all bar)
            if (showSelectionControls && provider.selectionMode)
              SidebarSelectAllBar(
                provider: provider,
              ),
            // Song list
            Expanded(
              child: ListView.builder(
                itemCount: provider.songs.length,
                itemBuilder: (context, index) {
                  final song = provider.songs[index];

                  return SongListTile(
                    song: song,
                    onTap: () => _handleSongTap(context, song, provider),
                    onLongPress: () =>
                        _handleSongLongPress(context, song, provider),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first song to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSongTap(BuildContext context, Song song, SongProvider provider) {
    if (provider.selectionMode) {
      _toggleSelection(context, song, provider);
    } else {
      onSongSelected?.call(song);
    }
  }

  void _handleSongLongPress(
      BuildContext context, Song song, SongProvider provider) {
    provider.toggleSelectionMode();
    provider.selectSong(song);
  }

  void _toggleSelection(
      BuildContext context, Song song, SongProvider provider) {
    if (provider.selectedSongIds.contains(song.id)) {
      provider.deselectSong(song);
    } else {
      provider.selectSong(song);
    }
  }
}
