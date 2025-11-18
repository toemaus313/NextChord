import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import 'song_editor_screen.dart';
import 'song_viewer_screen.dart';
import '../../domain/entities/song.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isSidebarVisible = true;
  int? _expandedSection; // null means all collapsed, 0-3 for each section
  bool _showingSongList = false;
  String _songListTitle = 'All Songs';
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: 1.0,
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // App resumed, refresh songs if we're showing the song list or sidebar
      if (_showingSongList || _isSidebarVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<SongProvider>().loadSongs();
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always refresh songs when dependencies change to ensure data is fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().loadSongs();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sidebarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
    
    // Animate the sidebar
    if (_isSidebarVisible) {
      _sidebarController.forward();
      // Refresh songs when opening sidebar to ensure list is up-to-date
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SongProvider>().loadSongs();
      });
    } else {
      _sidebarController.reverse();
    }
  }

  void _onSongSelected(Song song) async {
    // Navigate to song viewer and capture the result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongViewerScreen(
          song: song,
          shouldHideSidebar: () {
            if (_isSidebarVisible) {
              _toggleSidebar();
              return true; // Sidebar was hidden
            }
            return false; // Sidebar was already hidden
          },
        ),
      ),
    );
    
    // Handle return from song viewer
    if (mounted && result == 'deleted') {
      // Song was deleted, refresh the song list and ensure sidebar is visible
      await context.read<SongProvider>().loadSongs();
      setState(() {
        _isSidebarVisible = true;
        _sidebarController.forward();
      });
    }
  }

  void _toggleSection(int section) {
    setState(() {
      if (_expandedSection == section) {
        _expandedSection = null; // Collapse if already expanded
      } else {
        _expandedSection = section; // Expand the selected section
      }
    });
  }

  void _showSongList(String title) {
    // Clear search when navigating to a different view
    context.read<SongProvider>().clearSearch();
    _searchController.clear();
    
    setState(() {
      _showingSongList = true;
      _songListTitle = title;
    });
    // Load songs when showing the list to ensure fresh data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (title == 'Deleted') {
        context.read<SongProvider>().loadDeletedSongs();
      } else {
        context.read<SongProvider>().loadSongs();
      }
    });
  }

  void _hideSongList() {
    setState(() {
      _showingSongList = false;
    });
  }

  /// Show options menu for a song (edit, delete, etc.)
  void _showSongOptions(BuildContext context, Song song) {
    final isDeleted = _songListTitle == 'Deleted';
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View'),
                  onTap: () async {
                    Navigator.pop(context);
                    // Navigate to song viewer and capture the result
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongViewerScreen(
                          song: song,
                          shouldHideSidebar: () {
                            if (_isSidebarVisible) {
                              _toggleSidebar();
                              return true; // Sidebar was hidden
                            }
                            return false; // Sidebar was already hidden
                          },
                        ),
                      ),
                    );
                    
                    // Handle return from song viewer
                    if (mounted && result == 'deleted') {
                      // Song was deleted, refresh the song list and ensure sidebar is visible
                      await context.read<SongProvider>().loadSongs();
                      setState(() {
                        _isSidebarVisible = true;
                        _sidebarController.forward();
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () async {
                    Navigator.pop(context);
                    // Close sidebar before opening editor
                    if (_isSidebarVisible) {
                      _toggleSidebar();
                    }
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongEditorScreen(song: song),
                      ),
                    );
                    // Handle the return
                    if (context.mounted && result == 'deleted') {
                      // Song was deleted, refresh the song list and ensure sidebar is visible
                      await context.read<SongProvider>().loadSongs();
                      setState(() {
                        _isSidebarVisible = true;
                        _sidebarController.forward();
                      });
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
              ] else ...[
                // Deleted song options
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.green),
                  title: const Text('Restore', style: TextStyle(color: Colors.green)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRestore(context, song);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Permanently Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmPermanentDelete(context, song);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Confirm deletion of a song
  void _confirmDelete(BuildContext context, Song song) {
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
                  // Refresh the song list immediately
                  await context.read<SongProvider>().loadSongs();
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

  /// Confirm restore of a deleted song
  void _confirmRestore(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore Song'),
          content: Text('Are you sure you want to restore "${song.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await context.read<SongProvider>().restoreSong(song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song restored')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to restore: $e')),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  /// Confirm permanent deletion of a song
  void _confirmPermanentDelete(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permanently Delete Song'),
          content: Text(
            'Are you sure you want to permanently delete "${song.title}"? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await context.read<SongProvider>().permanentlyDeleteSong(song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Song permanently deleted')),
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
              child: const Text('Delete Forever'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // Main content area (full screen)
          _buildMainContent(theme, isDarkMode),

          // Floating Sidebar
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              if (_sidebarAnimation.value == 0) return const SizedBox();

              return Positioned(
                left: 16,
                top: 16,
                bottom: 16,
                child: Transform.translate(
                  offset: Offset(-320 * (1 - _sidebarAnimation.value), 0),
                  child: _buildSidebar(isDarkMode),
                ),
              );
            },
          ),

          // Toggle button (always visible)
          Positioned(
            top: 16,
            left: _isSidebarVisible
                ? 352
                : 16, // Adjust position based on sidebar
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: FloatingActionButton.small(
                onPressed: _toggleSidebar,
                backgroundColor: const Color(0xFF0468cc),
                child: Icon(
                  _isSidebarVisible ? Icons.chevron_left : Icons.menu,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDarkMode) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0468cc),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.library_music,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                  ),
                  onPressed: _toggleSidebar,
                  tooltip: 'Hide sidebar',
                ),
              ],
            ),
          ),
          // Collapsible sections or song list
          Expanded(
            child: _showingSongList
                ? _buildSongListPage()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSongsSection(),
                        _buildSetlistsSection(),
                        _buildToolsSection(),
                        _buildSettingsSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required int section,
  }) {
    final isExpanded = _expandedSection == section;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleSection(section),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongsSection() {
    final isExpanded = _expandedSection == 0;
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Songs',
          icon: Icons.music_note,
          section: 0,
        ),
        if (isExpanded)
          Container(
            color: Colors.white.withValues(alpha: 0.05),
            child: Column(
              children: [
                // Search bar in sidebar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Consumer<SongProvider>(
                    builder: (context, provider, child) {
                      // Sync controller with provider state
                      if (_searchController.text != provider.searchQuery) {
                        _searchController.text = provider.searchQuery;
                      }
                      
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search songs...',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.white.withValues(alpha: 0.7), size: 18),
                          suffixIcon: provider.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: Colors.white.withValues(alpha: 0.7), size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.clearSearch();
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
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (value) {
                          provider.searchSongs(value);
                        },
                      );
                    },
                  ),
                ),
                _buildFilterOption(Icons.library_music, 'All Songs'),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                _buildFilterOption(Icons.label, 'Tags'),
                _buildFilterOption(Icons.person, 'Artists'),
                _buildFilterOption(Icons.access_time, 'Recently Added'),
                _buildFilterOption(Icons.delete_outline, 'Deleted'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(12),
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
                          // Optionally refresh or handle the new song
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Song',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0468cc),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSongListPage() {
    return Container(
      color: const Color(0xFF0468cc),
      child: Column(
        children: [
          // Header with back button and title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _hideSongList,
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    _songListTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Selection mode toggle button
                Consumer<SongProvider>(
                  builder: (context, provider, child) {
                    return IconButton(
                      icon: Icon(
                        provider.selectionMode ? Icons.checklist : Icons.check_box_outline_blank,
                        color: provider.selectionMode ? Colors.white : Colors.white70,
                      ),
                      onPressed: () {
                        provider.toggleSelectionMode();
                      },
                      tooltip: provider.selectionMode ? 'Exit selection mode' : 'Enter selection mode',
                    );
                  },
                ),
                // Add song button
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SongEditorScreen(),
                      ),
                    );
                    if (result == true && context.mounted) {
                      // Refresh the song list after adding
                      context.read<SongProvider>().loadSongs();
                    }
                  },
                  tooltip: 'Add New Song',
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
            ),
            child: Consumer<SongProvider>(
              builder: (context, provider, child) {
                return TextField(
                  decoration: InputDecoration(
                    hintText: 'Song, tag or artist',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.white.withValues(alpha: 0.7), size: 18),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (value) {
                    provider.searchSongs(value);
                  },
                );
              },
            ),
          ),
          // Song list
          Expanded(
            child: Consumer<SongProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (provider.isEmpty) {
                  return Center(
                    child: Text(
                      'No songs yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: provider.songs.length + (provider.selectionMode ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show select all header when in selection mode
                    if (provider.selectionMode && index == 0) {
                      return _buildSelectAllHeader(provider);
                    }
                    
                    // Adjust index for actual songs when header is present
                    final songIndex = provider.selectionMode ? index - 1 : index;
                    final song = provider.songs[songIndex];
                    return _buildSongListItem(song);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllHeader(SongProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Select all checkbox
          Checkbox(
            value: provider.isAllSelected,
            onChanged: (bool? value) {
              provider.toggleSelectAll();
            },
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return Colors.white.withValues(alpha: 0.7);
            }),
            checkColor: const Color(0xFF0468cc),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          // Select all text
          Expanded(
            child: Text(
              provider.isAllSelected ? 'Deselect All' : 'Select All',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Selection count
          if (provider.hasSelectedSongs)
            Text(
              '${provider.selectedSongIds.length} selected',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongListItem(Song song) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        final isSelected = provider.selectedSongIds.contains(song.id);
        final isSelectionMode = provider.selectionMode;
        final hasSelections = provider.hasSelectedSongs;
        
        return Material(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSongSelection(song.id);
              } else {
                _onSongSelected(song);
              }
            },
            onLongPress: () {
              if (hasSelections) {
                _showBulkOptions(context);
              } else if (!isSelectionMode) {
                _showSongOptions(context, song);
              }
            },
            onSecondaryTap: () {
              // Right-click for desktop users
              if (hasSelections) {
                _showBulkOptions(context);
              } else if (!isSelectionMode) {
                _showSongOptions(context, song);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Show checkbox in selection mode
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        provider.toggleSongSelection(song.id);
                      },
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.white.withValues(alpha: 0.7);
                      }),
                      checkColor: const Color(0xFF0468cc),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Song content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${song.artist} - ${song.key}',
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Chevron icon (only when not in selection mode)
                  if (!isSelectionMode)
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
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
                    title: Text('${provider.selectedSongIds.length} songs selected'),
                    subtitle: const Text('Choose an action to perform on all selected songs'),
                  ),
                  const Divider(),
                  // Delete option
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmBulkDelete(context);
                    },
                  ),
                  // Tag option
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: const Text('Add Tags...'),
                    onTap: () {
                      Navigator.pop(context);
                      _showTagDialog(context);
                    },
                  ),
                  // Add to setlist option (placeholder)
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('Add to Setlist...'),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Setlists feature coming soon!')),
                      );
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

  /// Show dialog to add tags to selected songs
  void _showTagDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tags'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter tags separated by commas:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., rock, favorite, practice',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final tagText = controller.text.trim();
                if (tagText.isEmpty) return;
                
                final tags = tagText
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();
                
                Navigator.pop(context);
                try {
                  await context.read<SongProvider>().addTagsToSelectedSongs(tags);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${tags.length} tag(s) to ${context.read<SongProvider>().selectedSongIds.length} songs')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add tags: $e')),
                    );
                  }
                }
              },
              child: const Text('Add Tags'),
            ),
          ],
        );
      },
    );
  }

  /// Confirm bulk deletion of selected songs
  void _confirmBulkDelete(BuildContext context) {
    final provider = context.read<SongProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Songs'),
          content: Text('Are you sure you want to delete ${provider.selectedSongIds.length} selected songs?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await provider.deleteSelectedSongs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${provider.selectedSongIds.length} songs deleted')),
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
        );
      },
    );
  }

  Widget _buildFilterOption(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showSongList(label);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetlistsSection() {
    final isExpanded = _expandedSection == 1;
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Setlists',
          icon: Icons.list,
          section: 1,
        ),
        if (isExpanded)
          Container(
            color: Colors.white.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    'Recent Setlists',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Placeholder for recent setlists
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'No setlists yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSetlistOption(Icons.list_alt, 'All Setlists'),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Add Setlist coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Setlist',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0468cc),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSetlistOption(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label coming soon!')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsSection() {
    final isExpanded = _expandedSection == 2;
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Tools',
          icon: Icons.build,
          section: 2,
        ),
        if (isExpanded)
          Container(
            color: Colors.white.withValues(alpha: 0.05),
            child: Column(
              children: [
                _buildToolOption(Icons.music_note, 'Tuner'),
                _buildToolOption(Icons.speed, 'Metronome'),
                _buildToolOption(Icons.library_books, 'Chord Library'),
                _buildToolOption(Icons.piano, 'MIDI Commands'),
                _buildToolOption(Icons.tv, 'External Display'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToolOption(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label coming soon!')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final isExpanded = _expandedSection == 3;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      children: [
        _buildSectionHeader(
          title: 'Settings',
          icon: Icons.settings,
          section: 3,
        ),
        if (isExpanded)
          Container(
            color: Colors.white.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(12),
            child: Card(
              color: Colors.white.withValues(alpha: 0.1),
              child: SwitchListTile(
                secondary: Icon(
                  isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: Colors.white,
                ),
                title: const Text(
                  'Dark Mode',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                subtitle: const Text(
                  'Toggle dark/light theme',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                value: isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent(ThemeData theme, bool isDarkMode) {
    // Always show welcome screen now since we navigate to song viewer
    // Welcome screen when no song is selected
    return GestureDetector(
      onTap: () {
        if (_isSidebarVisible) {
          _toggleSidebar();
        }
      },
      child: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                size: 120,
                color: const Color(0xFF0468cc).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'NextChord',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select a song from the library to get started',
                style: TextStyle(
                  fontSize: 18,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              if (!_isSidebarVisible)
                ElevatedButton.icon(
                  onPressed: _toggleSidebar,
                  icon: const Icon(Icons.menu),
                  label: const Text('Open Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0468cc),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
