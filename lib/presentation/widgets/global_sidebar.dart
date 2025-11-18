import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../providers/song_provider.dart';
import '../screens/library_screen.dart';
import '../screens/song_editor_screen.dart';

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
  String _currentView = 'menu'; // 'menu', 'allSongs', 'artists', 'tags'
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
      context.read<GlobalSidebarProvider>().initializeAnimation(_animationController);
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final sidebarProvider = context.watch<GlobalSidebarProvider>();
        
        if (!sidebarProvider.isSidebarVisible || _animation.value == 0) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 16,
          top: 16,
          bottom: 16,
          child: Transform.translate(
            offset: Offset(-320 * (1 - _animation.value), 0),
            child: _buildSidebar(context),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Material(
      color: const Color(0xFF0468cc),
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      shadowColor: Colors.black.withAlpha(30),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF0468cc),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _currentView == 'allSongs'
            ? _buildAllSongsView(context)
            : _buildMenuView(context),
      ),
    );
  }

  Widget _buildMenuView(BuildContext context) {
    return Column(
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.library_music,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.read<GlobalSidebarProvider>().hideSidebar(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 24,
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
                    onTap: () {
                      setState(() {
                        _isSongsExpanded = !_isSongsExpanded;
                      });
                    },
                    isExpanded: _isSongsExpanded,
                    children: _isSongsExpanded ? [
                      _buildSubMenuItem(
                        context,
                        title: 'All Songs',
                        isSelected: false,
                        onTap: () {
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
                        onTap: () {
                          // Handle Artists navigation
                        },
                      ),
                      _buildSubMenuItem(
                        context,
                        title: 'Tags',
                        isSelected: false,
                        onTap: () {
                          // Handle Tags navigation
                        },
                      ),
                    ] : null,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.playlist_play,
                    title: 'Setlists',
                    isSelected: false,
                    onTap: () {
                      // Handle Setlists navigation
                    },
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
                    onTap: () {
                      // Handle Settings navigation
                    },
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Checkbox button for selection mode
                  Consumer<SongProvider>(
                    builder: (context, provider, child) {
                      return IconButton(
                        icon: Icon(
                          provider.selectionMode ? Icons.check_box : Icons.check_box_outline_blank,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          provider.toggleSelectionMode();
                        },
                        tooltip: provider.selectionMode ? 'Exit selection' : 'Select songs',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 12),
              // Search box
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Song, tag or artist',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            context.read<SongProvider>().searchSongs('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          child: const LibraryScreen(inSidebar: true),
        ),
      ],
    );
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
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 52, right: 20, top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.transparent,
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
