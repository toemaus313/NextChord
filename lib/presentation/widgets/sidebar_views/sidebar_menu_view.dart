import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/setlist_provider.dart';
import '../sidebar_components/sidebar_menu_item.dart';
import '../sidebar_components/sidebar_sub_menu_item.dart';
import '../sidebar_components/sidebar_header.dart';
import '../setlist_editor_dialog.dart';

/// Menu view for the sidebar
class SidebarMenuView extends StatefulWidget {
  final VoidCallback onNavigateToAllSongs;
  final VoidCallback onNavigateToArtistsList;
  final VoidCallback onNavigateToTagsList;
  final VoidCallback onNavigateToDeletedSongs;
  final VoidCallback onNavigateToSetlistView;
  final Function(String) onNavigateToSetlistViewWithId;
  final VoidCallback onNavigateToMidiSettings;
  final VoidCallback onNavigateToMidiProfiles;
  final VoidCallback onNavigateToMetronomeSettings;
  final VoidCallback onNavigateToGuitarTuner;
  final VoidCallback onNavigateToStorageSettings;

  const SidebarMenuView({
    Key? key,
    required this.onNavigateToAllSongs,
    required this.onNavigateToArtistsList,
    required this.onNavigateToTagsList,
    required this.onNavigateToDeletedSongs,
    required this.onNavigateToSetlistView,
    required this.onNavigateToSetlistViewWithId,
    required this.onNavigateToMidiSettings,
    required this.onNavigateToMidiProfiles,
    required this.onNavigateToMetronomeSettings,
    required this.onNavigateToGuitarTuner,
    required this.onNavigateToStorageSettings,
  }) : super(key: key);

  @override
  State<SidebarMenuView> createState() => _SidebarMenuViewState();
}

class _SidebarMenuViewState extends State<SidebarMenuView> {
  bool _isSongsExpanded = false;
  bool _isSetlistsExpanded = false;
  bool _isToolsExpanded = false;
  bool _isSettingsExpanded = false;
  int _deletedSongsCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SidebarHeader(
          title: 'Library',
          icon: Icons.library_music,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSongsSection(context),
                _buildSetlistsSection(context),
                _buildToolsSection(context),
                _buildSettingsSection(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongsSection(BuildContext context) {
    return SidebarMenuItem(
      icon: Icons.music_note,
      title: 'Songs',
      isSelected: false,
      onTap: () async {
        final wasExpanded = _isSongsExpanded;
        setState(() {
          _isSongsExpanded = !_isSongsExpanded;
        });
        // Fetch deleted songs count when expanding
        if (!wasExpanded && _isSongsExpanded) {
          try {
            final provider = context.read<SongProvider>();
            final deletedSongs = await provider.getDeletedSongsCount();
            if (mounted) {
              setState(() {
                _deletedSongsCount = deletedSongs;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _deletedSongsCount = 0;
              });
            }
          }
        }
      },
      isExpanded: _isSongsExpanded,
      children: _isSongsExpanded
          ? [
              Consumer<SongProvider>(
                builder: (context, provider, child) {
                  final songsCount = provider.songs.length;
                  final artists = <String>{};
                  for (final song in provider.songs) {
                    if (song.artist.isNotEmpty) {
                      artists.add(song.artist);
                    }
                  }
                  final artistsCount = artists.length;
                  final tags = <String>{};
                  for (final song in provider.songs) {
                    tags.addAll(song.tags);
                  }
                  final tagsCount = tags.length;

                  return Column(
                    children: [
                      SidebarSubMenuItem(
                        title: 'All Songs',
                        isSelected: false,
                        count: songsCount,
                        onTap: () {
                          context.read<SongProvider>().resetSelectionMode();
                          setState(() {
                            _isSongsExpanded = false;
                          });
                          widget.onNavigateToAllSongs();
                        },
                      ),
                      SidebarSubMenuItem(
                        title: 'Artists',
                        isSelected: false,
                        count: artistsCount,
                        onTap: () {
                          context.read<SongProvider>().resetSelectionMode();
                          setState(() {
                            _isSongsExpanded = false;
                          });
                          widget.onNavigateToArtistsList();
                        },
                      ),
                      SidebarSubMenuItem(
                        title: 'Tags',
                        isSelected: false,
                        count: tagsCount,
                        onTap: () {
                          context.read<SongProvider>().resetSelectionMode();
                          setState(() {
                            _isSongsExpanded = false;
                          });
                          widget.onNavigateToTagsList();
                        },
                      ),
                    ],
                  );
                },
              ),
              SidebarSubMenuItem(
                title: 'Deleted Songs',
                isSelected: false,
                count: _deletedSongsCount,
                onTap: () async {
                  context.read<SongProvider>().resetSelectionMode();
                  setState(() {
                    _isSongsExpanded = false;
                  });
                  await context.read<SongProvider>().loadDeletedSongs();
                  widget.onNavigateToDeletedSongs();
                },
              ),
            ]
          : null,
    );
  }

  Widget _buildSetlistsSection(BuildContext context) {
    return SidebarMenuItem(
      icon: Icons.playlist_play,
      title: 'Setlists',
      isSelected: false,
      onTap: () async {
        final wasExpanded = _isSetlistsExpanded;
        setState(() {
          _isSetlistsExpanded = !_isSetlistsExpanded;
        });
        if (!wasExpanded && _isSetlistsExpanded) {
          try {
            await context.read<SetlistProvider>().loadSetlists();
          } catch (e) {
            // Error handled by provider
          }
        }
      },
      isExpanded: _isSetlistsExpanded,
      children: _isSetlistsExpanded
          ? [
              Consumer<SetlistProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }

                  if (provider.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Error loading setlists',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final setlists = provider.setlists;
                  final widgets = <Widget>[];

                  for (final setlist in setlists) {
                    widgets.add(_buildSetlistMenuItem(context, setlist));
                  }

                  widgets.add(
                    SidebarSubMenuItem(
                      title: '+ Create Setlist',
                      isSelected: false,
                      onTap: () async {
                        final result = await SetlistEditorDialog.show(context);
                        if (result == true && context.mounted) {
                          await context.read<SetlistProvider>().loadSetlists();
                        }
                      },
                    ),
                  );

                  return Column(children: widgets);
                },
              ),
            ]
          : null,
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return SidebarMenuItem(
      icon: Icons.build,
      title: 'Tools',
      isSelected: false,
      onTap: () {
        setState(() {
          _isToolsExpanded = !_isToolsExpanded;
        });
      },
      isExpanded: _isToolsExpanded,
      children: _isToolsExpanded
          ? [
              SidebarSubMenuItem(
                title: 'Guitar Tuner',
                isSelected: false,
                onTap: widget.onNavigateToGuitarTuner,
              ),
            ]
          : null,
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return SidebarMenuItem(
      icon: Icons.settings,
      title: 'Settings',
      isSelected: false,
      onTap: () {
        setState(() {
          _isSettingsExpanded = !_isSettingsExpanded;
        });
      },
      isExpanded: _isSettingsExpanded,
      children: _isSettingsExpanded
          ? [
              SidebarSubMenuItem(
                title: 'MIDI Settings',
                isSelected: false,
                onTap: widget.onNavigateToMidiSettings,
              ),
              SidebarSubMenuItem(
                title: 'MIDI Profiles',
                isSelected: false,
                onTap: widget.onNavigateToMidiProfiles,
              ),
              SidebarSubMenuItem(
                title: 'Metronome',
                isSelected: false,
                onTap: widget.onNavigateToMetronomeSettings,
              ),
              SidebarSubMenuItem(
                title: 'Storage',
                isSelected: false,
                onTap: widget.onNavigateToStorageSettings,
              ),
            ]
          : null,
    );
  }

  Widget _buildSetlistMenuItem(BuildContext context, dynamic setlist) {
    return GestureDetector(
      onTap: () {
        // Need to navigate with the specific setlist ID
        // This requires updating the callback to accept setlist ID
        _navigateToSpecificSetlist(setlist.id);
      },
      onSecondaryTap: () => _showSetlistContextMenu(context, setlist),
      onLongPress: () => _showSetlistContextMenu(context, setlist),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 44, right: 16, top: 8, bottom: 8),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                setlist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Text(
              '${setlist.items.length} songs',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetlistContextMenu(BuildContext context, dynamic setlist) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await SetlistEditorDialog.show(
                    context,
                    setlist: setlist,
                  );
                  if (result == true && context.mounted) {
                    await context.read<SetlistProvider>().loadSetlists();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSetlist(context, setlist);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteSetlist(BuildContext context, dynamic setlist) async {
    final setlistProvider = context.read<SetlistProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Setlist'),
        content: Text(
            'Are you sure you want to delete "${setlist.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await setlistProvider.deleteSetlist(setlist.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Setlist deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete setlist: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToSpecificSetlist(String setlistId) {
    setState(() {
      _isSetlistsExpanded = false;
    });
    widget.onNavigateToSetlistViewWithId(setlistId);
  }
}
