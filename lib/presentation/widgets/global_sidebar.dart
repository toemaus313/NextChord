import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../screens/library_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: 0.0,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final sidebarProvider = context.watch<GlobalSidebarProvider>();
        debugPrint('AnimatedBuilder build: isSidebarVisible=${sidebarProvider.isSidebarVisible}, animationValue=${_animation.value}');
        
        if (!sidebarProvider.isSidebarVisible || _animation.value == 0) {
          debugPrint('AnimatedBuilder: hiding sidebar (visible=${sidebarProvider.isSidebarVisible}, value=${_animation.value})');
          return const SizedBox.shrink();
        }

        debugPrint('AnimatedBuilder: showing sidebar with offset ${-320 * (1 - _animation.value)}');
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
    return Container(
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
      child: Column(
        children: [
          // Sidebar header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(20),
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
                  onPressed: () => context.read<GlobalSidebarProvider>().hideSidebar(),
                  tooltip: 'Hide sidebar',
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
                          // Handle All Songs navigation
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
                      // Show library content when expanded
                      Container(
                        height: 300,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const LibraryScreen(inSidebar: true),
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
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
        padding: const EdgeInsets.only(left: 64, right: 24, top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.transparent,
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
