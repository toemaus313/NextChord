import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import 'song_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _searchController.dispose();
    super.dispose();
  }

  
  
  
  
  
  
  
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final sidebarProvider = context.watch<GlobalSidebarProvider>();

    return Scaffold(
      body: sidebarProvider.currentSong != null
          ? SongViewerScreen(
              key: ValueKey(sidebarProvider.currentSong!.id),
              song: sidebarProvider.currentSong!,
              onSongEdit: () {
                // Reload songs when returning from edit
                context.read<SongProvider>().loadSongs();
              },
            )
          : _buildMainContent(theme, isDarkMode),
    );
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  Widget _buildMainContent(ThemeData theme, bool isDarkMode) {
    // Always show welcome screen now since we navigate to song viewer
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
              ElevatedButton.icon(
                onPressed: () => context.read<GlobalSidebarProvider>().toggleSidebar(),
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
