import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../add_songs_to_setlist_modal.dart';

/// Widget that provides floating action buttons for the library
class LibraryFloatingActions extends StatelessWidget {
  final bool inSidebar;
  final VoidCallback? onAddSong;

  const LibraryFloatingActions({
    Key? key,
    this.inSidebar = false,
    this.onAddSong,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (inSidebar) {
      return const SizedBox.shrink(); // No floating actions in sidebar mode
    }

    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add to setlist button (only show when songs are selected)
            if (provider.selectionMode && provider.selectedSongIds.isNotEmpty)
              FloatingActionButton.extended(
                onPressed: () => _showAddToSetlistDialog(context),
                icon: const Icon(Icons.playlist_add),
                label:
                    Text('Add ${provider.selectedSongIds.length} to Setlist'),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            if (provider.selectionMode && provider.selectedSongIds.isNotEmpty)
              const SizedBox(height: 16),
            // Add song button
            FloatingActionButton(
              onPressed: onAddSong ?? () => _navigateToAddSong(context),
              child: const Icon(Icons.add),
              tooltip: 'Add Song',
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddSong(BuildContext context) {
    Navigator.pushNamed(context, '/song_editor');
  }

  void _showAddToSetlistDialog(BuildContext context) {
    final songProvider = context.read<SongProvider>();
    final selectedSongs = songProvider.songs
        .where((song) => songProvider.selectedSongIds.contains(song.id))
        .toList();

    AddSongsToSetlistModal.showMultiple(
      context,
      selectedSongs,
    ).then((_) {
      songProvider.resetSelectionMode();
    });
  }
}
