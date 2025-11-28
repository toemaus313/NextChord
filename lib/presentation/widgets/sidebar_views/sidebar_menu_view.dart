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
  final VoidCallback onNavigateToAppearanceSettings;
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
    required this.onNavigateToAppearanceSettings,
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
  String? _pendingSection; // Next section to expand after current collapses

  // Mobile-only: whether top-level menus should be centered (no section open)
  bool _shouldCenterMenusOnPhone = true;

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

  /// Check if a specific section is expanded
  bool _isSectionExpanded(String sectionName) {
    return _expandedSection == sectionName;
  }

  /// Handle taps on top-level sections with animated collapse-then-expand behavior
  Future<void> _onSectionTap(
    String sectionName,
    Future<void> Function()? onExpanded,
  ) async {
    // Tapping the already-expanded section just collapses it
    if (_expandedSection == sectionName) {
      setState(() {
        _expandedSection = null;
        _pendingSection = null;
        _shouldCenterMenusOnPhone = true; // Re-center when everything collapsed
      });
      return;
    }

    // Remember which section we ultimately want to open
    _pendingSection = sectionName;

    // If nothing is currently expanded, first slide menus from center -> left,
    // then roll down the submenu
    if (_expandedSection == null) {
      setState(() {
        // Stop centering on mobile to trigger slide-left animation
        _shouldCenterMenusOnPhone = false;
      });

      // Allow the slide-left animation to play (~500ms)
      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;

      // If another tap changed the pending section in the meantime, respect that
      if (_pendingSection != sectionName) {
        return;
      }

      setState(() {
        _expandedSection = sectionName;
      });
      if (onExpanded != null) {
        await onExpanded();
      }
      return;
    }

    // Otherwise, collapse current section first
    setState(() {
      _expandedSection = null;
      _shouldCenterMenusOnPhone =
          false; // Keep menus left-aligned between sections
    });

    // Wait for the submenu close + slide-left alignment animations to complete
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    // If another tap changed the pending section in the meantime, respect that
    if (_pendingSection != sectionName) {
      return;
    }

    setState(() {
      _expandedSection = sectionName;
    });

    if (onExpanded != null) {
      await onExpanded();
    }
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
    final bool centerMenusOnPhone =
        widget.isPhoneMode && _shouldCenterMenusOnPhone;

    return Column(
      children: [
        // Only show header if not on mobile (mobile has its own header)
        if (widget.showHeader)
          const SidebarHeader(
            title: 'Library',
            icon: Icons.library_music,
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSongsSection(context, centerMenusOnPhone),
                _buildSetlistsSection(context, centerMenusOnPhone),
                _buildToolsSection(context, centerMenusOnPhone),
                _buildSettingsSection(context, centerMenusOnPhone),
              ],
            ),
          ),
        ),

        // Mobile-only branding
        if (widget.isPhoneMode && _expandedSection == null)
          _buildMobileBranding(context),
        const SizedBox(height: 50),
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

  /// Mobile-only branding block shown when all sections are collapsed
  Widget _buildMobileBranding(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final logoWidth = (screenWidth * 0.6).clamp(250.0, 360.0);
    final titleFontSize = (screenWidth * 0.06).clamp(60.0, 70.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/NextChord-Logo-transparent.png',
            width: logoWidth,
            fit: BoxFit.contain,
            semanticLabel: 'NextChord logo',
          ),
          const SizedBox(height: 40),
          Text(
            'NextChord',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsSection(BuildContext context, bool centerOnPhone) {
    return SidebarMenuItem(
      icon: Icons.music_note,
      title: 'Songs',
      isSelected: false,
      onTap: () async {
        await _onSectionTap('songs', () async {
          await _loadSongCounts();
        });
      },
      isExpanded: _isSectionExpanded('songs'),
      isPhoneMode: widget.isPhoneMode,
      centerOnPhone: centerOnPhone,
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

  Widget _buildSetlistsSection(BuildContext context, bool centerOnPhone) {
    return SidebarMenuItem(
      icon: Icons.playlist_play,
      title: 'Setlists',
      isSelected: false,
      onTap: () async {
        await _onSectionTap('setlists', () async {
          try {
            await context.read<SetlistProvider>().loadSetlists();
          } catch (e) {
            // Ignore load errors here; error UI is handled in builder
          }
        });
      },
      isExpanded: _isSectionExpanded('setlists'),
      isPhoneMode: widget.isPhoneMode,
      centerOnPhone: centerOnPhone,
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

  Widget _buildToolsSection(BuildContext context, bool centerOnPhone) {
    return SidebarMenuItem(
      icon: Icons.build,
      title: 'Tools',
      isSelected: false,
      onTap: () async {
        await _onSectionTap('tools', null);
      },
      isExpanded: _isSectionExpanded('tools'),
      isPhoneMode: widget.isPhoneMode,
      centerOnPhone: centerOnPhone,
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

  Widget _buildSettingsSection(BuildContext context, bool centerOnPhone) {
    return SidebarMenuItem(
      icon: Icons.settings,
      title: 'Settings',
      isSelected: false,
      onTap: () async {
        await _onSectionTap('settings', null);
      },
      isExpanded: _isSectionExpanded('settings'),
      isPhoneMode: widget.isPhoneMode,
      centerOnPhone: centerOnPhone,
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
                title: 'Appearance',
                isSelected: false,
                onTap: widget.onNavigateToAppearanceSettings,
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
      return widget.isPhoneMode ? baseSize * 1.8 : baseSize * 1.5;
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
    } else {}
  }

  void _navigateToSpecificSetlist(String setlistId) {
    widget.onNavigateToSetlistViewWithId(setlistId);
  }
}
