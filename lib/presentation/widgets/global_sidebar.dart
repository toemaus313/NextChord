import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../providers/song_provider.dart';
import '../providers/setlist_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/library_screen.dart';
import '../screens/song_editor_screen.dart';
import '../screens/setlist_editor_screen.dart';
import '../screens/setlists_screen.dart';
import 'sidebar_select_all_bar.dart';

/// Global sidebar widget that can overlay any screen
class GlobalSidebar extends StatefulWidget {
  const GlobalSidebar({Key? key}) : super(key: key);

  @override
  State<GlobalSidebar> createState() => _GlobalSidebarState();
}

class _GlobalSidebarState extends State<GlobalSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSongsExpanded = false;
  bool _isSetlistsExpanded = false;
  String _currentView =
      'menu'; // 'menu', 'allSongs', 'deletedSongs', 'artistsList', 'artistSongs', 'tagsList', 'tagSongs'
  String? _selectedArtist;
  String? _selectedTag;
  int _deletedSongsCount = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: 1.0, // Start with sidebar visible
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Initialize the provider with our controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<GlobalSidebarProvider>()
          .initializeAnimation(_animationController);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Calculate width based on animation value (0 when hidden, 302 when visible)
        final width = 302.0 * _animation.value;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: width * 0.85, // Make sidebar 15% narrower
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
          clipBehavior: Clip.hardEdge,
          child: width > 0 ? _buildSidebar(context) : null,
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 256, // Reduced from 302
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0468cc), // Original blue at top
              Color.fromARGB(99, 3, 73, 153), // Darker blue at bottom
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            right: BorderSide(
              color: Colors.black.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: _currentView == 'allSongs'
            ? _buildAllSongsView(context)
            : _currentView == 'deletedSongs'
                ? _buildDeletedSongsView(context)
                : _currentView == 'artistsList'
                    ? _buildArtistsListView(context)
                    : _currentView == 'artistSongs'
                        ? _buildArtistSongsView(context)
                        : _currentView == 'tagsList'
                            ? _buildTagsListView(context)
                            : _currentView == 'tagSongs'
                                ? _buildTagSongsView(context)
                                : _buildMenuView(context),
      ),
    );
  }

  Widget _buildMenuView(BuildContext context) {
    return Column(
      children: [
        // Sidebar header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.library_music,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    context.read<GlobalSidebarProvider>().hideSidebar(),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Menu items
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMenuItem(
                  context,
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
                        // Temporarily load deleted songs to get count
                        await provider.loadDeletedSongs();
                        if (mounted) {
                          setState(() {
                            _deletedSongsCount = provider.songs.length;
                          });
                        }
                        // Reload regular songs
                        await provider.loadSongs();
                      } catch (e) {
                        // If error, just set count to 0
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
                              // Calculate counts
                              final songsCount = provider.songs.length;

                              // Get unique artists count
                              final artists = <String>{};
                              for (final song in provider.songs) {
                                if (song.artist.isNotEmpty) {
                                  artists.add(song.artist);
                                }
                              }
                              final artistsCount = artists.length;

                              // Get unique tags count
                              final tags = <String>{};
                              for (final song in provider.songs) {
                                tags.addAll(song.tags);
                              }
                              final tagsCount = tags.length;

                              return Column(
                                children: [
                                  _buildSubMenuItem(
                                    context,
                                    title: 'All Songs',
                                    isSelected: false,
                                    count: songsCount,
                                    onTap: () {
                                      context
                                          .read<SongProvider>()
                                          .resetSelectionMode();
                                      setState(() {
                                        _currentView = 'allSongs';
                                        _isSongsExpanded = false;
                                      });
                                    },
                                  ),
                                  _buildSubMenuItem(
                                    context,
                                    title: 'Artists',
                                    isSelected: false,
                                    count: artistsCount,
                                    onTap: () {
                                      context
                                          .read<SongProvider>()
                                          .resetSelectionMode();
                                      setState(() {
                                        _currentView = 'artistsList';
                                        _isSongsExpanded = false;
                                      });
                                    },
                                  ),
                                  _buildSubMenuItem(
                                    context,
                                    title: 'Tags',
                                    isSelected: false,
                                    count: tagsCount,
                                    onTap: () {
                                      context
                                          .read<SongProvider>()
                                          .resetSelectionMode();
                                      setState(() {
                                        _currentView = 'tagsList';
                                        _isSongsExpanded = false;
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          _buildSubMenuItem(
                            context,
                            title: 'Deleted Songs',
                            isSelected: false,
                            count: _deletedSongsCount,
                            onTap: () async {
                              context.read<SongProvider>().resetSelectionMode();
                              setState(() {
                                _currentView = 'deletedSongs';
                                _isSongsExpanded = false;
                              });
                              // Load deleted songs
                              await context
                                  .read<SongProvider>()
                                  .loadDeletedSongs();
                            },
                          ),
                        ]
                      : null,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.playlist_play,
                  title: 'Setlists',
                  isSelected: false,
                  onTap: () async {
                    final wasExpanded = _isSetlistsExpanded;
                    setState(() {
                      _isSetlistsExpanded = !_isSetlistsExpanded;
                    });
                    // Load setlists when expanding
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
                              // Loading state
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

                              // Error state
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

                              // Empty state or list of setlists
                              final setlists = provider.setlists;
                              final widgets = <Widget>[];

                              // Add existing setlists
                              for (final setlist in setlists) {
                                widgets.add(
                                  _buildSubMenuItem(
                                    context,
                                    title: setlist.name,
                                    isSelected: false,
                                    onTap: () {
                                      // Navigate to setlist editor
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SetlistsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }

                              // Add "Create Setlist" button
                              widgets.add(
                                _buildSubMenuItem(
                                  context,
                                  title: '+ Create Setlist',
                                  isSelected: false,
                                  onTap: () async {
                                    final BuildContext context = this.context;
                                    final result =
                                        await SetlistEditorDialog.show(context);
                                    if (result == true && context.mounted) {
                                      await context
                                          .read<SetlistProvider>()
                                          .loadSetlists();
                                    }
                                  },
                                ),
                              );

                              return Column(children: widgets);
                            },
                          ),
                        ]
                      : null,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.build,
                  title: 'Tools',
                  isSelected: false,
                  onTap: () {
                    // Handle Tools navigation
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'Settings',
                  isSelected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllSongsView(BuildContext context) {
    return Column(
      children: [
        // Header with back button, title, checkbox, and add button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      context.read<SongProvider>().resetSelectionMode();
                      setState(() {
                        _currentView = 'menu';
                        _searchController.clear();
                        context.read<SongProvider>().searchSongs('');
                      });
                    },
                    tooltip: 'Back to menu',
                  ),
                  const Expanded(
                    child: Text(
                      'All Songs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Checkbox button for selection mode
                  Consumer<SongProvider>(
                    builder: (context, provider, child) {
                      return IconButton(
                        icon: Icon(
                          provider.selectionMode
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          provider.toggleSelectionMode();
                        },
                        tooltip: provider.selectionMode
                            ? 'Exit selection'
                            : 'Select songs',
                      );
                    },
                  ),
                  // Add button
                  IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                    ),
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
                    tooltip: 'Add song',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Search box
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Song, tag or artist',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white70, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.white70, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            context.read<SongProvider>().searchSongs('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  isDense: true,
                ),
                onChanged: (value) {
                  context.read<SongProvider>().searchSongs(value);
                  setState(() {}); // Rebuild to show/hide clear button
                },
              ),
            ],
          ),
        ),
        // Song list from LibraryScreen
        Expanded(
          child: LibraryScreen(
            inSidebar: true,
            onSongSelected: (song) {
              // Navigate to the song in the main content area
              context.read<GlobalSidebarProvider>().navigateToSong(song);
              // Keep sidebar open (drawer behavior)
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedSongsView(BuildContext context) {
    return Column(
      children: [
        // Header with back button, title, and checkbox
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(20),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () {
                  context.read<SongProvider>().resetSelectionMode();
                  setState(() {
                    _currentView = 'menu';
                  });
                  // Reload regular songs when going back
                  context.read<SongProvider>().loadSongs();
                },
                tooltip: 'Back to menu',
              ),
              const Expanded(
                child: Text(
                  'Deleted Songs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Checkbox button for selection mode
              Consumer<SongProvider>(
                builder: (context, provider, child) {
                  return IconButton(
                    icon: Icon(
                      provider.selectionMode
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      provider.toggleSelectionMode();
                    },
                    tooltip: provider.selectionMode
                        ? 'Exit selection'
                        : 'Select songs',
                  );
                },
              ),
            ],
          ),
        ),
        // Deleted songs list
        Expanded(
          child: Consumer<SongProvider>(
            builder: (context, provider, child) {
              // Loading state
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
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
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading deleted songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.errorMessage ?? 'Unknown error',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Empty state
              if (provider.songs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No deleted songs',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Songs list with bulk actions
              return Column(
                children: [
                  // Bulk action bar (shown when in selection mode)
                  if (provider.selectionMode && provider.hasSelectedSongs)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${provider.selectedSongIds.length} selected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Restore all button (icon only)
                          IconButton(
                            onPressed: () => _bulkRestoreDeletedSongs(context),
                            icon: const Icon(Icons.restore,
                                color: Colors.green, size: 20),
                            tooltip: 'Restore selected',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          // Delete all permanently button (icon only)
                          IconButton(
                            onPressed: () =>
                                _bulkPermanentlyDeleteSongs(context),
                            icon: const Icon(Icons.delete_forever,
                                color: Colors.red, size: 20),
                            tooltip: 'Delete forever',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  // Select All bar (shown when in selection mode)
                  if (provider.selectionMode)
                    SidebarSelectAllBar(
                      provider: provider,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      backgroundColor: Colors.black.withValues(alpha: 0.2),
                      dividerColor: Colors.black.withValues(alpha: 0.3),
                      textColor: Colors.white,
                      secondaryTextColor: Colors.white.withValues(alpha: 0.7),
                      checkboxScale: 0.75,
                    ),
                  // Songs list
                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.songs.length,
                      itemBuilder: (context, index) {
                        final song = provider.songs[index];
                        final isSelected =
                            provider.selectedSongIds.contains(song.id);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(color: Colors.blue, width: 1.5)
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            leading: provider.selectionMode
                                ? Transform.scale(
                                    scale: 0.85,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        provider.toggleSongSelection(song.id);
                                      },
                                      fillColor:
                                          WidgetStateProperty.resolveWith(
                                              (states) {
                                        if (states
                                            .contains(WidgetState.selected)) {
                                          return Colors.white;
                                        }
                                        return Colors.white
                                            .withValues(alpha: 0.3);
                                      }),
                                      checkColor: const Color(0xFF0468cc),
                                    ),
                                  )
                                : null,
                            title: Text(
                              song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: song.artist.isNotEmpty
                                ? Text(
                                    song.artist,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: provider.selectionMode
                                ? () => provider.toggleSongSelection(song.id)
                                : null,
                            trailing: provider.selectionMode
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Restore button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.restore,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          try {
                                            await provider.restoreSong(song.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Restored "${song.title}"'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Failed to restore: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        tooltip: 'Restore song',
                                      ),
                                      // Permanent delete button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_forever,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          // Show confirmation dialog
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                  'Permanently Delete'),
                                              content: Text(
                                                'Are you sure you want to permanently delete "${song.title}"? This action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  child: const Text(
                                                      'Delete Forever'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            try {
                                              await provider
                                                  .permanentlyDeleteSong(
                                                      song.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Permanently deleted "${song.title}"'),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Failed to delete: $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        tooltip: 'Delete permanently',
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtistsListView(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        // Get all unique artists from songs
        final artists = <String>{};
        for (final song in provider.songs) {
          if (song.artist.isNotEmpty) {
            artists.add(song.artist);
          }
        }
        final artistsList = artists.toList()..sort();

        return Column(
          children: [
            // Header with back button and search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          context.read<SongProvider>().resetSelectionMode();
                          setState(() {
                            _currentView = 'menu';
                            _searchController.clear();
                          });
                        },
                        tooltip: 'Back to menu',
                      ),
                      const Expanded(
                        child: Text(
                          'Artists',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search artists',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white70, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white70, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(
                          () {}); // Rebuild to filter and show/hide clear button
                    },
                  ),
                ],
              ),
            ),
            // Artists list
            Expanded(
              child: Builder(
                builder: (context) {
                  // Filter artists based on search
                  final filteredArtists = _searchController.text.isEmpty
                      ? artistsList
                      : artistsList
                          .where((artist) => artist
                              .toLowerCase()
                              .contains(_searchController.text.toLowerCase()))
                          .toList();

                  if (filteredArtists.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No artists'
                                  : 'No artists found',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredArtists.length,
                    itemBuilder: (context, index) {
                      final artist = filteredArtists[index];
                      // Count songs by this artist
                      final songCount = provider.songs
                          .where((s) => s.artist == artist)
                          .length;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          title: Text(
                            artist,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$songCount song${songCount != 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                          onTap: () {
                            context.read<SongProvider>().resetSelectionMode();
                            setState(() {
                              _selectedArtist = artist;
                              _currentView = 'artistSongs';
                              _searchController.clear();
                            });
                            // Filter songs by this artist
                            context.read<SongProvider>().filterByArtist(artist);
                          },
                        ),
                      );
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

  Widget _buildArtistSongsView(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Header with back button, title, checkbox, and add button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          context.read<SongProvider>().resetSelectionMode();
                          setState(() {
                            _currentView = 'artistsList';
                            _searchController.clear();
                          });
                          // Reload all songs when going back
                          context.read<SongProvider>().loadSongs();
                        },
                        tooltip: 'Back to artists',
                      ),
                      Expanded(
                        child: Text(
                          _selectedArtist ?? 'Artist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Checkbox button for selection mode
                      IconButton(
                        icon: Icon(
                          provider.selectionMode
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          provider.toggleSelectionMode();
                        },
                        tooltip: provider.selectionMode
                            ? 'Exit selection'
                            : 'Select songs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Song or tag',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white70, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white70, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                context.read<SongProvider>().searchSongs('');
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<SongProvider>().searchSongs(value);
                      setState(() {}); // Rebuild to show/hide clear button
                    },
                  ),
                ],
              ),
            ),
            // Song list from LibraryScreen
            Expanded(
              child: LibraryScreen(
                inSidebar: true,
                skipInitialLoad: true,
                onSongSelected: (song) {
                  context.read<GlobalSidebarProvider>().navigateToSong(song);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTagsListView(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        // Get all unique tags from songs
        final tags = <String>{};
        for (final song in provider.songs) {
          tags.addAll(song.tags);
        }
        final tagsList = tags.toList()..sort();

        return Column(
          children: [
            // Header with back button and search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _currentView = 'menu';
                            _searchController.clear();
                          });
                        },
                        tooltip: 'Back to menu',
                      ),
                      const Expanded(
                        child: Text(
                          'Tags',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          provider.selectionMode
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          provider.toggleSelectionMode();
                        },
                        tooltip: provider.selectionMode
                            ? 'Exit selection'
                            : 'Select songs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search tags',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white70, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white70, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(
                          () {}); // Rebuild to filter and show/hide clear button
                    },
                  ),
                  if (provider.selectionMode) ...[
                    const SizedBox(height: 10),
                    SidebarSelectAllBar(
                      provider: provider,
                      backgroundColor: Colors.black.withValues(alpha: 0.15),
                      dividerColor: Colors.black.withValues(alpha: 0.25),
                      textColor: Colors.white,
                      secondaryTextColor: Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
            // Tags list
            Expanded(
              child: Builder(
                builder: (context) {
                  // Filter tags based on search
                  final filteredTags = _searchController.text.isEmpty
                      ? tagsList
                      : tagsList
                          .where((tag) => tag
                              .toLowerCase()
                              .contains(_searchController.text.toLowerCase()))
                          .toList();

                  if (filteredTags.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.label_outline,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No tags'
                                  : 'No tags found',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredTags.length,
                    itemBuilder: (context, index) {
                      final tag = filteredTags[index];
                      // Count songs with this tag
                      final songCount = provider.songs
                          .where((s) => s.tags.contains(tag))
                          .length;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          title: Text(
                            tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$songCount song${songCount != 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onTap: () {
                            context.read<SongProvider>().resetSelectionMode();
                            setState(() {
                              _selectedTag = tag;
                              _currentView = 'tagSongs';
                              _searchController.clear();
                            });
                            // Filter songs by this tag
                            context.read<SongProvider>().filterByTag(tag);
                          },
                        ),
                      );
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

  Widget _buildTagSongsView(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Header with back button, title, checkbox, and add button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          context.read<SongProvider>().resetSelectionMode();
                          setState(() {
                            _currentView = 'tagsList';
                            _searchController.clear();
                          });
                          // Reload all songs when going back
                          context.read<SongProvider>().loadSongs();
                        },
                        tooltip: 'Back to tags',
                      ),
                      Expanded(
                        child: Text(
                          _selectedTag ?? 'Tag',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Checkbox button for selection mode
                      IconButton(
                        icon: Icon(
                          provider.selectionMode
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          provider.toggleSelectionMode();
                        },
                        tooltip: provider.selectionMode
                            ? 'Exit selection'
                            : 'Select songs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search box
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Song or artist',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white70, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white70, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                context.read<SongProvider>().searchSongs('');
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      context.read<SongProvider>().searchSongs(value);
                      setState(() {}); // Rebuild to show/hide clear button
                    },
                  ),
                ],
              ),
            ),
            // Song list from LibraryScreen
            Expanded(
              child: LibraryScreen(
                inSidebar: true,
                skipInitialLoad: true,
                onSongSelected: (song) {
                  context.read<GlobalSidebarProvider>().navigateToSong(song);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Bulk restore selected deleted songs
  void _bulkRestoreDeletedSongs(BuildContext context) async {
    final provider = context.read<SongProvider>();
    final count = provider.selectedSongIds.length;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Songs'),
        content: Text(
            'Are you sure you want to restore $count selected song${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final songsToRestore = provider.selectedSongs;
      for (final song in songsToRestore) {
        await provider.restoreSong(song.id);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored $count song${count > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore songs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Bulk permanently delete selected songs
  void _bulkPermanentlyDeleteSongs(BuildContext context) async {
    final provider = context.read<SongProvider>();
    final count = provider.selectedSongIds.length;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: Text(
          'Are you sure you want to permanently delete $count selected song${count > 1 ? 's' : ''}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final songsToDelete = provider.selectedSongs;
      for (final song in songsToDelete) {
        await provider.permanentlyDeleteSong(song.id);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Permanently deleted $count song${count > 1 ? 's' : ''}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete songs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    List<Widget>? children,
    bool isExpanded = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (children != null) ...children,
      ],
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 44, right: 16, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (count != null)
              Text(
                count.toString(),
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
}
