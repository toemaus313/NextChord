import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nextchord/main.dart' as main;
import '../../../domain/entities/setlist.dart';
import '../../providers/song_provider.dart';

/// Dialog for selecting songs to add to a setlist
///
/// This dialog handles song selection with search functionality and
/// prevents adding duplicate songs to the setlist.
class SetlistSongSelectorDialog extends StatefulWidget {
  final List<SetlistSongItem> currentItems;

  const SetlistSongSelectorDialog({
    Key? key,
    required this.currentItems,
  }) : super(key: key);

  /// Show dialog to add songs to a setlist
  static Future<List<String>?> show(
    BuildContext context, {
    required List<SetlistSongItem> currentItems,
  }) async {
    main.myDebug(
        '[SetlistSongSelectorDialog] show: currentItems=${currentItems.length}');
    return await showDialog<List<String>>(
      context: context,
      builder: (context) => SetlistSongSelectorDialog(
        currentItems: currentItems,
      ),
    );
  }

  @override
  State<SetlistSongSelectorDialog> createState() =>
      _SetlistSongSelectorDialogState();
}

class _SetlistSongSelectorDialogState extends State<SetlistSongSelectorDialog> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeSongProvider();
  }

  Future<void> _initializeSongProvider() async {
    final songProvider = context.read<SongProvider>();

    // Reset selection mode and load songs if needed
    songProvider.resetSelectionMode();
    // Enable selection mode by default
    songProvider.toggleSelectionMode();
    if (songProvider.songs.isEmpty && !songProvider.isLoading) {
      await songProvider.loadSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0468cc),
              Color.fromARGB(150, 3, 73, 153),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildSongList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel button in upper left
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel'),
          ),
          // Centered title
          const Expanded(
            child: Text(
              'Add Songs',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Save button in upper right
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(
              context.read<SongProvider>().selectedSongIds.toList(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search songs...',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.search, color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        onChanged: (query) {
          context.read<SongProvider>().searchSongs(query);
        },
      ),
    );
  }

  Widget _buildSongList() {
    return Expanded(
      child: Consumer<SongProvider>(
        builder: (context, songProvider, _) {
          if (songProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          }

          if (songProvider.songs.isEmpty) {
            return const Center(
              child: Text(
                'No songs found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            itemCount: songProvider.songs.length,
            itemBuilder: (context, index) {
              final song = songProvider.songs[index];
              final isSelected = songProvider.selectedSongIds.contains(song.id);
              final alreadyAdded =
                  widget.currentItems.any((item) => item.songId == song.id);

              // Skip songs that are already added
              if (alreadyAdded) {
                return const SizedBox.shrink();
              }

              return CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  if (value == true) {
                    songProvider.selectSong(song);
                  } else {
                    songProvider.deselectSong(song);
                  }
                },
                title: Text(
                  song.title,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  song.artist,
                  style: const TextStyle(color: Colors.white70),
                ),
                activeColor: Colors.white,
                checkColor: const Color(0xFF0468cc),
              );
            },
          );
        },
      ),
    );
  }
}
