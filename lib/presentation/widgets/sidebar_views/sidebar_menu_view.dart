import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/setlist_provider.dart';
import '../sidebar_components/sidebar_menu_item.dart';
import '../sidebar_components/sidebar_sub_menu_item.dart';
import '../sidebar_components/sidebar_header.dart';
import '../standard_wide_button.dart';
import '../setlist_editor_dialog.dart';
import '../../../domain/entities/setlist.dart';

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
  final VoidCallback onNavigateToAppControl;
  final VoidCallback onNavigateToActionTest;
  final VoidCallback onAddSong;
  final bool isPhoneMode;
  final bool showHeader;

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
    required this.onNavigateToAppControl,
    required this.onNavigateToActionTest,
    required this.onAddSong,
    this.isPhoneMode = false,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarMenuView> createState() => _SidebarMenuViewState();
}

class _SidebarMenuViewState extends State<SidebarMenuView> {
  // Accordion state - only one section can be expanded at a time
  String? _expandedSection;

  // Song counts state
  int _totalSongsCount = 0;
  int _artistsCount = 0;
  int _tagsCount = 0;
  int _deletedSongsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSongCounts();
  }

  void _expandSection(String sectionName) {
    setState(() {
      if (_expandedSection == sectionName) {
        _expandedSection =
            null; // Collapse if clicking the already expanded section
      } else {
        _expandedSection =
            sectionName; // Expand new section, auto-collapsing others
      }
    });
  }

  /// Check if a specific section is expanded
  bool _isSectionExpanded(String sectionName) {
    return _expandedSection == sectionName;
  }

  /// Load all song counts
  Future<void> _loadSongCounts() async {
    try {
      final provider = context.read<SongProvider>();

      // Load all songs to get counts
      // Use post-frame callback to avoid build-phase setState error
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await provider.loadSongs();
        final allSongs = provider.songs;

        // Calculate counts
        final totalSongsCount = allSongs.length;
        final artistsCount = allSongs.map((song) => song.artist).toSet().length;
        final tagsCount = allSongs
            .where((song) => song.tags.isNotEmpty)
            .expand((song) => song.tags)
            .toSet()
            .length;
        final deletedSongsCount = await provider.getDeletedSongsCount();

        if (mounted) {
          setState(() {
            _totalSongsCount = totalSongsCount;
            _artistsCount = artistsCount;
            _tagsCount = tagsCount;
            _deletedSongsCount = deletedSongsCount;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalSongsCount = 0;
          _artistsCount = 0;
          _tagsCount = 0;
          _deletedSongsCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Only show header if not on mobile (mobile has its own header)
        if (widget.showHeader)
          const SidebarHeader(
            title: 'Library',
            icon: Icons.library_music,
          ),
        Expanded(
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: StandardWideButton(
            label: 'Add Song',
            icon: Icons.add,
            onPressed: widget.onAddSong,
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
        final wasExpanded = _isSectionExpanded('songs');
        _expandSection('songs');
        // Load song counts when expanding
        if (!wasExpanded && _isSectionExpanded('songs')) {
          await _loadSongCounts();
        }
      },
      isExpanded: _isSectionExpanded('songs'),
      isPhoneMode: widget.isPhoneMode,
      children: _isSectionExpanded('songs')
          ? [
              SidebarSubMenuItem(
                title: 'All Songs',
                isSelected: false,
                onTap: widget.onNavigateToAllSongs,
                count: _totalSongsCount,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'Artists',
                isSelected: false,
                onTap: widget.onNavigateToArtistsList,
                count: _artistsCount,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'Tags',
                isSelected: false,
                onTap: widget.onNavigateToTagsList,
                count: _tagsCount,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'Deleted',
                isSelected: false,
                onTap: widget.onNavigateToDeletedSongs,
                count: _deletedSongsCount,
                isPhoneMode: widget.isPhoneMode,
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
        final wasExpanded = _isSectionExpanded('setlists');
        _expandSection('setlists');
        if (!wasExpanded && _isSectionExpanded('setlists')) {
          try {
            await context.read<SetlistProvider>().loadSetlists();
          } catch (e) {}
        }
      },
      isExpanded: _isSectionExpanded('setlists'),
      isPhoneMode: widget.isPhoneMode,
      children: _isSectionExpanded('setlists')
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
                      isPhoneMode: widget.isPhoneMode,
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
        _expandSection('tools');
      },
      isExpanded: _isSectionExpanded('tools'),
      isPhoneMode: widget.isPhoneMode,
      children: _isSectionExpanded('tools')
          ? [
              SidebarSubMenuItem(
                title: 'Guitar Tuner',
                isSelected: false,
                onTap: widget.onNavigateToGuitarTuner,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'ActionTest',
                isSelected: false,
                onTap: widget.onNavigateToActionTest,
                isPhoneMode: widget.isPhoneMode,
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
        _expandSection('settings');
      },
      isExpanded: _isSectionExpanded('settings'),
      isPhoneMode: widget.isPhoneMode,
      children: _isSectionExpanded('settings')
          ? [
              SidebarSubMenuItem(
                title: 'MIDI Settings',
                isSelected: false,
                onTap: widget.onNavigateToMidiSettings,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'MIDI Profiles',
                isSelected: false,
                onTap: widget.onNavigateToMidiProfiles,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'Metronome',
                isSelected: false,
                onTap: widget.onNavigateToMetronomeSettings,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'Storage',
                isSelected: false,
                onTap: widget.onNavigateToStorageSettings,
                isPhoneMode: widget.isPhoneMode,
              ),
              SidebarSubMenuItem(
                title: 'App Control',
                isSelected: false,
                onTap: widget.onNavigateToAppControl,
                isPhoneMode: widget.isPhoneMode,
              ),
            ]
          : null,
    );
  }

  Widget _buildSetlistMenuItem(BuildContext context, dynamic setlist) {
    // Helper method for responsive text sizing (1.8x scaling on phones)
    double _getResponsiveTextSize(double baseSize) {
      return widget.isPhoneMode ? baseSize * 1.8 : baseSize;
    }

    // Calculate song count by filtering for song items (not dividers)
    final songCount = setlist.items?.whereType<SetlistSongItem>().length ?? 0;

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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getResponsiveTextSize(12.0),
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            // Always show count for debugging (remove condition)
            Text(
              '$songCount',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: _getResponsiveTextSize(10.0),
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
    debugPrint(
        '[SETLIST_DELETE] Starting deletion for setlist: "${setlist.name}" (ID: ${setlist.id})');
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
      debugPrint(
          '[SETLIST_DELETE] User confirmed deletion, calling provider.deleteSetlist()');
      try {
        await setlistProvider.deleteSetlist(setlist.id);
        debugPrint(
            '[SETLIST_DELETE] Provider.deleteSetlist() completed successfully');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Setlist deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('[SETLIST_DELETE] ERROR: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete setlist: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      debugPrint('[SETLIST_DELETE] User cancelled deletion');
    }
  }

  void _navigateToSpecificSetlist(String setlistId) {
    widget.onNavigateToSetlistViewWithId(setlistId);
  }
}
