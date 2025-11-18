import 'package:flutter/material.dart';
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
        print('AnimatedBuilder build: isSidebarVisible=${sidebarProvider.isSidebarVisible}, animationValue=${_animation.value}');
        
        if (!sidebarProvider.isSidebarVisible || _animation.value == 0) {
          print('AnimatedBuilder: hiding sidebar (visible=${sidebarProvider.isSidebarVisible}, value=${_animation.value})');
          return const SizedBox.shrink();
        }

        print('AnimatedBuilder: showing sidebar with offset ${-320 * (1 - _animation.value)}');
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
                  onPressed: () => context.read<GlobalSidebarProvider>().hideSidebar(),
                  tooltip: 'Hide sidebar',
                ),
              ],
            ),
          ),
          // Song list
          Expanded(
            child: const LibraryScreen(inSidebar: true),
          ),
        ],
      ),
    );
  }
}
