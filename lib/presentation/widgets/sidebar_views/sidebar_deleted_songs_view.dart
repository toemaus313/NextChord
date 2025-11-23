import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../sidebar_components/sidebar_header.dart';
import '../sidebar_select_all_bar.dart';

/// Deleted songs view for the sidebar
class SidebarDeletedSongsView extends StatefulWidget {
  final VoidCallback onBack;

  const SidebarDeletedSongsView({
    Key? key,
    required this.onBack,
  }) : super(key: key);

  @override
  State<SidebarDeletedSongsView> createState() =>
      _SidebarDeletedSongsViewState();
}

class _SidebarDeletedSongsViewState extends State<SidebarDeletedSongsView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        final deletedSongs = provider.deletedSongs;

        return Column(
          children: [
            SidebarHeader(
              title: 'Deleted Songs',
              icon: Icons.delete_outline,
              onClose: widget.onBack,
            ),
            if (provider.selectionMode && deletedSongs.isNotEmpty)
              Column(
                children: [
                  SidebarSelectAllBar(
                    provider: provider,
                  ),
                  if (provider.hasSelectedSongs)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _bulkRestoreDeletedSongs(context),
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Restore Selected',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _bulkPermanentlyDeleteSongs(context),
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: const Text('Delete Forever',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            Expanded(
              child: deletedSongs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 48,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No deleted songs',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Songs you delete will appear here',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: deletedSongs.length,
                      itemBuilder: (context, index) {
                        final song = deletedSongs[index];
                        final isSelected =
                            provider.selectedSongs.contains(song);

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withAlpha(51),
                            child: Text(
                              song.title.isNotEmpty
                                  ? song.title[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: song.artist.isNotEmpty
                              ? Text(
                                  song.artist,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (provider.selectionMode)
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    if (value == true) {
                                      provider.selectSong(song);
                                    } else {
                                      provider.deselectSong(song);
                                    }
                                  },
                                  activeColor: Colors.blue,
                                  checkColor: Colors.white,
                                )
                              else
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'restore') {
                                      _restoreSong(context, song);
                                    } else if (value == 'delete') {
                                      _permanentlyDeleteSong(context, song);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'restore',
                                      child: Text('Restore'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Permanently Delete'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          onTap: () {
                            if (provider.selectionMode) {
                              if (isSelected) {
                                provider.deselectSong(song);
                              } else {
                                provider.selectSong(song);
                              }
                            }
                          },
                          onLongPress: () {
                            if (!provider.selectionMode) {
                              provider.toggleSelectionMode();
                              provider.selectSong(song);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _restoreSong(BuildContext context, dynamic song) async {
    try {
      await context.read<SongProvider>().restoreSong(song.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _permanentlyDeleteSong(BuildContext context, dynamic song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Song'),
        content: Text(
            'Are you sure you want to permanently delete "${song.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<SongProvider>().permanentlyDeleteSong(song.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song permanently deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting song: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _bulkRestoreDeletedSongs(BuildContext context) async {
    try {
      await context.read<SongProvider>().bulkRestoreSongs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Songs restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring songs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _bulkPermanentlyDeleteSongs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Songs'),
        content: const Text(
            'Are you sure you want to permanently delete all selected songs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<SongProvider>().bulkPermanentlyDeleteSongs();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Songs permanently deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting songs: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
