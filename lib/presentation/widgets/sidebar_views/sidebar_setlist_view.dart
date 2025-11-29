import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nextchord/main.dart' as main;
import '../../providers/global_sidebar_provider.dart';
import '../../providers/setlist_provider.dart';
import '../../providers/song_provider.dart';
import '../../../domain/entities/setlist.dart';
import '../../../domain/entities/song.dart';
import '../sidebar_components/sidebar_header.dart';
import '../../screens/song_editor_screen_refactored.dart';
import '../tag_edit_dialog.dart';
import '../setlist_editor_dialog.dart';
import '../standard_wide_button.dart';
import '../../../services/setlist/setlist_service.dart';
import 'dart:io';

/// Setlist view for the sidebar
class SidebarSetlistView extends StatefulWidget {
  final String setlistId;
  final VoidCallback onBack;
  final VoidCallback onAddSong;
  final VoidCallback onAddDivider;
  final bool showHeader;

  const SidebarSetlistView({
    Key? key,
    required this.setlistId,
    required this.onBack,
    required this.onAddSong,
    required this.onAddDivider,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarSetlistView> createState() => _SidebarSetlistViewState();
}

class _SidebarSetlistViewState extends State<SidebarSetlistView> {
  @override
  Widget build(BuildContext context) {
    main.myDebug(
        '[SidebarSetlistView] build: setlistId=${widget.setlistId}, showHeader=${widget.showHeader}');
    return Consumer<SetlistProvider>(
      builder: (context, setlistProvider, child) {
        final currentSetlist = setlistProvider.setlists
            .where((s) => s.id == widget.setlistId)
            .firstOrNull;

        if (currentSetlist == null) {
          return Column(
            children: [
              // Only show header if not on mobile (mobile has its own header)
              if (widget.showHeader)
                SidebarHeader(
                  title: 'Setlist',
                  icon: Icons.playlist_play,
                  onClose: widget.onBack,
                ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Setlist not found',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            // Header with setlist icon and back button
            if (widget.showHeader)
              SidebarHeader(
                title: currentSetlist.name,
                icon: Icons.playlist_play,
                onClose: widget.onBack,
              ),
            // Make the entire content scrollable so we don't overflow on
            // short screens or in compact sidebar layouts.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Logo area (200x200 placeholder)
                    Container(
                      height: 200,
                      width: 200,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: currentSetlist.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(currentSetlist.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildLogoPlaceholder(),
                              ),
                            )
                          : _buildLogoPlaceholder(),
                    ),
                    // Setlist title area (moved below logo)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        currentSetlist.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Edit Setlist button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await SetlistEditorDialog.show(
                            context,
                            setlist: currentSetlist,
                          );
                          if (result == true && context.mounted) {
                            await setlistProvider.loadSetlists();
                          }
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Setlist'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(20),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Setlist items (non-expanding, shrink-wrapped list)
                    Consumer<SongProvider>(
                      builder: (context, songProvider, child) {
                        final songsMap = {
                          for (final song in songProvider.songs) song.id: song,
                        };

                        if (currentSetlist.items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'No songs in this setlist',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: currentSetlist.items.length,
                              onReorder: (oldIndex, newIndex) =>
                                  _reorderSetlistItems(oldIndex, newIndex,
                                      currentSetlist, setlistProvider),
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final item = currentSetlist.items[index];
                                if (item is SetlistSongItem) {
                                  final song = songsMap[item.songId];
                                  return _buildSetlistSongItem(
                                      item, song, index);
                                } else if (item is SetlistDividerItem) {
                                  return _buildSetlistDividerItem(item, index);
                                }
                                return const SizedBox.shrink();
                              },
                              // Custom drag highlight color
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder:
                                      (BuildContext context, Widget? child) {
                                    return Material(
                                      color: const Color(0xFF0468cc)
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      elevation: 4,
                                      child: child,
                                    );
                                  },
                                  child: child,
                                );
                              },
                            ),
                            _buildAddButton(context, currentSetlist),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              color: Colors.white54,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetlistSongItem(SetlistSongItem item, Song? song, int index) {
    final title = song?.title ?? 'Unknown song';
    final artist = song?.artist ?? '';

    // Calculate effective key and capo
    String displayKey = song?.key ?? '';
    int capo = song?.capo ?? 0;

    if (song != null) {
      if (item.transposeSteps != 0) {
        // Apply transpose to key
        displayKey = _transposeKey(displayKey, item.transposeSteps);
      }
      if (item.capo != song.capo) {
        capo = item.capo;
      }
    }

    return GestureDetector(
      key: ValueKey('song_${item.songId}_$index'),
      onTap: () {
        if (song != null) {
          context
              .read<GlobalSidebarProvider>()
              .navigateToSongInSetlist(song, index, item);
        }
      },
      onSecondaryTap: () => _showSongContextMenu(context, item, song, index),
      onLongPress: () => _showSongContextMenu(context, item, song, index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // Drag handle
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
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Key badge
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
                          displayKey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Artist and capo row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          artist,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (capo > 0) ...[
                        const SizedBox(width: 8),
                        // Capo badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CAPO $capo',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetlistDividerItem(SetlistDividerItem item, int index) {
    final dividerColor = _parseColor(item.color);

    return GestureDetector(
      key: ValueKey('divider_${item.order}_${item.color}_$index'),
      onSecondaryTap: () => _showDividerContextMenu(context, item, index),
      onLongPress: () => _showDividerContextMenu(context, item, index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 1,
              color: dividerColor,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    color: Colors.white54,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: dividerColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              height: 1,
              color: dividerColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, Setlist setlist) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: StandardWideButton(
        label: 'Add...',
        icon: Icons.add,
        onPressed: () async {
          if (!mounted) return;
          final setlistProvider =
              Provider.of<SetlistProvider>(context, listen: false);
          final songProvider =
              Provider.of<SongProvider>(context, listen: false);
          if (songProvider.songs.isEmpty && !songProvider.isLoading) {
            await songProvider.loadSongs();
          }

          final setlist = setlistProvider.setlists
              .firstWhere((s) => s.id == widget.setlistId);
          final result = await SetlistEditorDialog.showAddSongs(
              context, setlist.items.whereType<SetlistSongItem>().toList());
          if (result != null && result.isNotEmpty && mounted) {
            final availableSongs = songProvider.songs;
            final setlistService = SetlistService(setlistProvider.repository);
            final newItems =
                setlistService.createSetlistSongItems(result, availableSongs);

            // Create updated setlist with new songs
            final updatedSetlist = setlist.copyWith(
              items: [...setlist.items, ...newItems],
              updatedAt: DateTime.now(),
            );

            await setlistProvider.updateSetlist(updatedSetlist);
          }
        },
      ),
    );
  }

  void _reorderSetlistItems(int oldIndex, int newIndex, Setlist setlist,
      SetlistProvider provider) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final items = List<SetlistItem>.from(setlist.items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Normalize orders
    final updatedItems = items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      if (item is SetlistSongItem) {
        return item.copyWith(order: index);
      } else if (item is SetlistDividerItem) {
        return item.copyWith(order: index);
      }
      return item;
    }).toList();

    final updatedSetlist = setlist.copyWith(items: updatedItems);

    try {
      await provider.updateSetlist(updatedSetlist);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder setlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSongContextMenu(
      BuildContext context, SetlistSongItem item, Song? song, int index) {
    if (song == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View'),
                  onTap: () async {
                    Navigator.pop(context);
                    context
                        .read<GlobalSidebarProvider>()
                        .navigateToSongInSetlist(song, index, item);
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
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete from Setlist',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteSongFromSetlist(context, item, index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDividerContextMenu(
      BuildContext context, SetlistDividerItem divider, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Divider'),
                onTap: () {
                  Navigator.pop(context);
                  // Divider edit functionality not yet implemented
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Divider',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteDividerFromSetlist(context, divider, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteSongFromSetlist(
      BuildContext context, SetlistSongItem item, int index) async {
    try {
      final setlistProvider = context.read<SetlistProvider>();
      final currentSetlist = setlistProvider.setlists
          .where((s) => s.id == widget.setlistId)
          .firstOrNull;

      if (currentSetlist != null) {
        final updatedItems = <SetlistItem>[];
        for (int i = 0; i < currentSetlist.items.length; i++) {
          if (i != index) {
            updatedItems.add(currentSetlist.items[i]);
          }
        }

        final updatedSetlist = currentSetlist.copyWith(
          items: updatedItems,
          updatedAt: DateTime.now(),
        );

        await setlistProvider.updateSetlist(updatedSetlist);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song removed from setlist'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDividerFromSetlist(
      BuildContext context, SetlistDividerItem divider, int index) async {
    try {
      final setlistProvider = context.read<SetlistProvider>();
      final currentSetlist = setlistProvider.setlists
          .where((s) => s.id == widget.setlistId)
          .firstOrNull;

      if (currentSetlist != null) {
        final updatedItems = <SetlistItem>[];
        for (int i = 0; i < currentSetlist.items.length; i++) {
          if (i != index) {
            updatedItems.add(currentSetlist.items[i]);
          }
        }

        final updatedSetlist = currentSetlist.copyWith(
          items: updatedItems,
          updatedAt: DateTime.now(),
        );

        await setlistProvider.updateSetlist(updatedSetlist);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Divider removed from setlist'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove divider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editSongTags(BuildContext context, dynamic song) async {
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

  String _transposeKey(String key, int steps) {
    // Simple key transposition (can be enhanced)
    const keys = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];

    if (key.isEmpty) return key;

    // Find the base key (remove 'm' for minor keys)
    String baseKey = key.endsWith('m') ? key.substring(0, key.length - 1) : key;
    bool isMinor = key.endsWith('m');

    int? currentIndex = keys.indexOf(baseKey);
    if (currentIndex == -1) return key; // Key not found

    int newIndex = (currentIndex + steps) % 12;
    if (newIndex < 0) newIndex += 12;

    String transposedKey = keys[newIndex];
    return isMinor ? '${transposedKey}m' : transposedKey;
  }

  Color _parseColor(String colorString) {
    // Parse color string to Color object
    try {
      if (colorString.startsWith('#')) {
        return Color(
            int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      } else if (colorString.startsWith('0x')) {
        return Color(int.parse(colorString) + 0xFF000000);
      } else {
        // Default to white if parsing fails
        return Colors.white;
      }
    } catch (e) {
      return Colors.white;
    }
  }
}
