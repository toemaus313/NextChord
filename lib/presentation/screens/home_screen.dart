import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import 'library_screen.dart';
import 'song_editor_screen.dart';
import 'song_viewer_screen.dart';
import '../../domain/entities/song.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isSidebarVisible = true;
  Song? _selectedSong;
  int? _expandedSection; // null means all collapsed, 0-3 for each section
  bool _showingSongList = false;
  String _songListTitle = 'All Songs';
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
      if (_isSidebarVisible) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  void _onSongSelected(Song song) {
    setState(() {
      _selectedSong = song;
    });
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
    setState(() {
      _showingSongList = true;
      _songListTitle = title;
    });
    // Load songs when showing the list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().loadSongs();
    });
  }

  void _hideSongList() {
    setState(() {
      _showingSongList = false;
    });
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
              ],
            ),
          ),
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
            ),
            child: TextField(
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
                  itemCount: provider.songs.length,
                  itemBuilder: (context, index) {
                    final song = provider.songs[index];
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

  Widget _buildSongListItem(Song song) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _onSongSelected(song);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${song.artist} - ${song.key}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
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
    if (_selectedSong != null) {
      return SongViewerScreen(song: _selectedSong!);
    }

    // Welcome screen when no song is selected
    return Container(
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
    );
  }
}
