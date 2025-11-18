import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../providers/song_provider.dart';
import '../widgets/song_list_tile.dart';
import 'song_editor_screen.dart';
import 'song_viewer_screen.dart';

/// Main library screen that displays all songs
/// Features search/filter, pull-to-refresh, and FAB for adding songs
class LibraryScreen extends StatefulWidget {
  final Function(Song)? onSongSelected;
  final bool inSidebar;

  const LibraryScreen({
    Key? key,
    this.onSongSelected,
    this.inSidebar = false,
  }) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load songs when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().loadSongs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sidebar mode: no Scaffold wrapper
    if (widget.inSidebar) {
      return Column(
        children: [
          // Search bar for sidebar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          context.read<SongProvider>().searchSongs('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (query) {
                context.read<SongProvider>().searchSongs(query);
              },
            ),
          ),
          Expanded(
            child: _buildSongList(inSidebar: true),
          ),
          // Add song button in sidebar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SongEditorScreen(),
                    ),
                  );
                  if (result == true && context.mounted) {
                    context.read<SongProvider>().loadSongs();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Song'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0468cc),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Full screen mode: with Scaffold
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search songs or artists...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      context.read<SongProvider>().searchSongs('');
                    },
                  ),
              ],
              onChanged: (query) {
                context.read<SongProvider>().searchSongs(query);
              },
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Song list
          Expanded(
            child: _buildSongList(inSidebar: false),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SongEditorScreen(),
            ),
          );
          if (result == true && context.mounted) {
            context.read<SongProvider>().loadSongs();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Song'),
      ),
    );
  }

  Widget _buildSongList({required bool inSidebar}) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        final textColor = inSidebar ? Colors.white : null;
        final iconColor = inSidebar ? Colors.white70 : null;

        // Loading state
        if (provider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: inSidebar ? Colors.white : null,
            ),
          );
        }

        // Error state
        if (provider.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: iconColor ?? Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage ?? 'An unknown error occurred',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.clearError();
                      provider.loadSongs();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Empty state
        if (provider.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_outlined,
                    size: 48,
                    color: iconColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No songs yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first song',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
          );
        }

        // No search results
        if (provider.songs.isEmpty && provider.searchQuery.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: iconColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
          );
        }

        // Song list
        return ListView.builder(
          padding: EdgeInsets.only(bottom: inSidebar ? 0 : 80),
          itemCount: provider.songs.length,
          itemBuilder: (context, index) {
            final song = provider.songs[index];
            return _buildSongItem(song, inSidebar);
          },
        );
      },
    );
  }

  Widget _buildSongItem(Song song, bool inSidebar) {
    if (inSidebar) {
      // Compact list item for sidebar
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.onSongSelected != null) {
              widget.onSongSelected!(song);
            }
          },
          onLongPress: () {
            _showSongOptions(context, song);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        song.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Full song list tile for full screen mode
      return SongListTile(
        song: song,
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SongViewerScreen(song: song),
            ),
          );
          if (result == true && context.mounted) {
            context.read<SongProvider>().loadSongs();
          }
        },
        onLongPress: () {
          _showSongOptions(context, song);
        },
      );
    }
  }

  /// Show options menu for a song (edit, delete, etc.)
  void _showSongOptions(BuildContext context, song) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongViewerScreen(song: song),
                    ),
                  );
                  // Refresh the list if the song was updated
                  if (result == true && context.mounted) {
                    context.read<SongProvider>().loadSongs();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongEditorScreen(song: song),
                    ),
                  );
                  // Refresh the list if the song was updated
                  if (result == true && context.mounted) {
                    context.read<SongProvider>().loadSongs();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, song);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Confirm deletion of a song
  void _confirmDelete(BuildContext context, song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Song'),
          content: Text('Are you sure you want to delete "${song.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await context.read<SongProvider>().deleteSong(song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song deleted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
