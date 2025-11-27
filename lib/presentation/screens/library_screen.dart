import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../providers/song_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/tag_edit_dialog.dart';
import '../widgets/sidebar_select_all_bar.dart';
import '../widgets/add_songs_to_setlist_modal.dart';
import 'song_editor_screen_refactored.dart';
import 'song_viewer_screen.dart';
import '../../core/widgets/responsive_config.dart';

/// Main library screen that displays all songs
/// Features search/filter, pull-to-refresh, and FAB for adding songs
class LibraryScreen extends StatefulWidget {
  final Function(Song)? onSongSelected;
  final bool inSidebar;
  final bool skipInitialLoad;

  const LibraryScreen({
    Key? key,
    this.onSongSelected,
    this.inSidebar = false,
    this.skipInitialLoad = false,
  }) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load songs when screen initializes (unless skipInitialLoad is true)
    if (!widget.skipInitialLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SongProvider>().loadSongs();
      });
    }
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
      return _buildSongList(inSidebar: true);
    }

    // Full screen mode: with Scaffold
    return Scaffold(
      body: Column(
        children: [
          // Header with add button only
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Add song button
                IconButton.filled(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const SongEditorScreenRefactored(),
                      ),
                    );
                    if (result == true && context.mounted) {
                      // Refresh the song list after adding
                      context.read<SongProvider>().loadSongs();
                    }
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Add New Song',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
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
              builder: (context) => const SongEditorScreenRefactored(),
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
          itemCount: provider.songs.length +
              (inSidebar && provider.selectionMode ? 1 : 0),
          itemBuilder: (context, index) {
            // Select All header for sidebar in selection mode
            if (inSidebar && provider.selectionMode && index == 0) {
              return SidebarSelectAllBar(provider: provider);
            }
            final songIndex =
                inSidebar && provider.selectionMode ? index - 1 : index;
            final song = provider.songs[songIndex];
            return _buildSongItem(song, inSidebar);
          },
        );
      },
    );
  }

  Widget _buildSongItem(Song song, bool inSidebar) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        final isSelected = provider.selectedSongIds.contains(song.id);
        final hasSelections = provider.hasSelectedSongs;

        // Use SongListTile for both sidebar and full screen
        return Row(
          children: [
            // Selection checkbox (sidebar only)
            if (inSidebar && provider.selectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    provider.toggleSongSelection(song.id);
                  },
                  fillColor: WidgetStateProperty.all(Colors.white),
                  checkColor: Colors.black,
                ),
              ),
            // Song content
            Expanded(
              child: SongListTile(
                song: song,
                onTap: () {
                  if (provider.selectionMode) {
                    provider.toggleSongSelection(song.id);
                  } else {
                    final isPhone = ResponsiveConfig.isPhone(context);
                    if (inSidebar) {
                      if (isPhone) {
                        // Phone: Navigate to full-screen song viewer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongViewerScreen(song: song),
                          ),
                        );
                      } else if (widget.onSongSelected != null) {
                        // Desktop/Tablet: Use existing callback
                        widget.onSongSelected!(song);
                      }
                    } else {
                      // Full screen mode
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SongViewerScreen(song: song),
                        ),
                      ).then((result) {
                        if (result == true && context.mounted) {
                          context.read<SongProvider>().loadSongs();
                        }
                      });
                    }
                  }
                },
                onLongPress: () {
                  if (hasSelections) {
                    _showBulkOptions(context);
                  } else {
                    _showSongOptions(context, song);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show bulk operations menu for selected songs
  void _showBulkOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<SongProvider>(
          builder: (context, provider, child) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with selection count
                  ListTile(
                    title: Text(
                        '${provider.selectedSongIds.length} songs selected'),
                    subtitle: const Text(
                        'Choose an action to perform on all selected songs'),
                  ),
                  const Divider(),
                  // Delete option
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmBulkDelete(context);
                    },
                  ),
                  // Tag option
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: const Text('Edit Tags...'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  // Add to setlist option
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('Add to Setlist...'),
                    onTap: () {
                      Navigator.pop(context);
                      _showBulkAddToSetlist(context, provider.selectedSongs);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show dialog to edit tags for selected songs
  Future<void> showEditTagsDialog() async {
    final provider = context.read<SongProvider>();

    // Collect all tags from selected songs
    final allTagsFromSelection = <String>{};
    for (final songId in provider.selectedSongIds) {
      final song = provider.songs.firstWhere((s) => s.id == songId,
          orElse: () => throw Exception('Song not found'));
      allTagsFromSelection.addAll(song.tags);
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => TagEditDialog(
        title: 'Edit Tags',
        initialTags: allTagsFromSelection,
        onTagsUpdated: (updatedTags) async {
          try {
            await context
                .read<SongProvider>()
                .updateTagsForSelectedSongs(updatedTags);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Updated tags for ${context.read<SongProvider>().selectedSongIds.length} songs')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update tags: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// Show dialog to edit tags for a single song
  Future<void> showEditTagsDialogForSong(Song song) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => TagEditDialog(
        title: 'Edit Tags',
        initialTags: song.tags.toSet(),
        onTagsUpdated: (updatedTags) async {
          try {
            await context
                .read<SongProvider>()
                .updateSongTags(song.id, updatedTags);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tags updated')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update tags: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// Confirm bulk deletion of selected songs
  void _confirmBulkDelete(BuildContext context) {
    final provider = context.read<SongProvider>();
    final sidebarProvider = context.read<GlobalSidebarProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Songs'),
        content: Text(
            'Are you sure you want to delete ${provider.selectedSongIds.length} selected songs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Check if current song is in the selection
                final currentSongId = sidebarProvider.currentSong?.id;
                final willDeleteCurrentSong = currentSongId != null &&
                    provider.selectedSongIds.contains(currentSongId);

                await provider.deleteSelectedSongs();

                // Clear current song if it was deleted
                if (willDeleteCurrentSong) {
                  sidebarProvider.clearCurrentSong();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${provider.selectedSongIds.length} songs deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete songs: $e')),
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
      ),
    );
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
                      builder: (context) =>
                          SongEditorScreenRefactored(song: song),
                    ),
                  );
                  // Refresh the list if the song was updated
                  if (result == true && context.mounted) {
                    context.read<SongProvider>().loadSongs();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('Edit Tags...'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to Setlist'),
                onTap: () {
                  Navigator.pop(context);
                  AddSongsToSetlistModal.show(context, song);
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
      builder: (context) => AlertDialog(
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
                final sidebarProvider = context.read<GlobalSidebarProvider>();
                await context.read<SongProvider>().deleteSong(
                  song.id,
                  onDeleted: () {
                    // If this song is currently being viewed, clear it
                    if (sidebarProvider.currentSong?.id == song.id) {
                      sidebarProvider.clearCurrentSong();
                    }
                  },
                );
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
      ),
    );
  }

  /// Show bulk add to setlist functionality for multiple selected songs
  void _showBulkAddToSetlist(BuildContext context, List<Song> selectedSongs) {
    if (selectedSongs.isEmpty) return;

    // For multiple songs, we'll show the modal for the first song
    // but modify the modal to handle multiple songs
    AddSongsToSetlistModal.showMultiple(context, selectedSongs);
  }
}
