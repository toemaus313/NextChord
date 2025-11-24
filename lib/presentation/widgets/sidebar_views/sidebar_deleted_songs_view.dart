import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../sidebar_components/sidebar_header.dart';
import '../sidebar_select_all_bar.dart';

/// Deleted songs view for the sidebar
class SidebarDeletedSongsView extends StatefulWidget {
  final VoidCallback onBack;
  final bool showHeader;

  const SidebarDeletedSongsView({
    Key? key,
    required this.onBack,
    this.showHeader = true,
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
            // Only show header if not on mobile (mobile has its own header)
            if (widget.showHeader)
              SidebarHeader(
                title: 'Deleted Songs',
                icon: Icons.delete_outline,
                onClose: widget.onBack,
              ),
            // Select Songs button
            Consumer<SongProvider>(
              builder: (context, provider, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.toggleSelectionMode();
                    },
                    icon: Icon(
                        provider.selectionMode ? Icons.close : Icons.checklist,
                        size: 16),
                    label: Text(provider.selectionMode
                        ? 'Cancel Selection'
                        : 'Select Songs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.selectionMode
                          ? Colors.red.withAlpha(20)
                          : Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),
                );
              },
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
                              label: const Text('Restore',
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
                              label: const Text('Delete',
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

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              // Song title and artist
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (song.artist.isNotEmpty)
                                      Text(
                                        song.artist,
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(179),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              // Action buttons
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
                              else ...[
                                // Restore button
                                IconButton(
                                  onPressed: () => _restoreSong(context, song),
                                  icon: const Icon(
                                    Icons.restore,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  tooltip: 'Restore',
                                  padding: const EdgeInsets.all(2),
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                ),
                                // Delete button
                                IconButton(
                                  onPressed: () =>
                                      _permanentlyDeleteSong(context, song),
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  tooltip: 'Permanently Delete',
                                  padding: const EdgeInsets.all(2),
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
