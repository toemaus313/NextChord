import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nextchord/main.dart' as main;
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import 'song_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh songs if we're currently showing all songs
    // This prevents overwriting deleted songs list when navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SongProvider>();
      // Only load songs if we're not currently viewing deleted songs
      if (provider.currentListType == SongListType.all) {
        provider.loadSongs();
      }
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
    main.myDebug(
        '[HomeScreen] build: hasCurrentSong=${sidebarProvider.currentSong != null}');

    return Scaffold(
      body: sidebarProvider.currentSong != null
          ? SongViewerScreen(
              key: ValueKey(
                  '${sidebarProvider.currentSong!.id}_${sidebarProvider.currentSong!.updatedAt.millisecondsSinceEpoch}'),
              song: sidebarProvider.currentSong!,
              onSongEdit: () {
                // Reload songs when returning from edit
                context.read<SongProvider>().loadSongs();
              },
              setlistContext: sidebarProvider.currentSetlistSongItem,
            )
          : _buildMainContent(theme, isDarkMode),
    );
  }

  Widget _buildMainContent(ThemeData theme, bool isDarkMode) {
    // Always show welcome screen now since we navigate to song viewer
    // Welcome screen when no song is selected
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Calculate responsive logo size (max 70% of screen width, max 300px height)
    final logoWidth = (screenWidth * 0.7).clamp(200.0, 700.0);
    final logoHeight = (screenHeight * 0.3).clamp(100.0, 300.0);

    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + viewInsets.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.9, // Limit max width to 90% of screen
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Responsive logo
                  Image.asset(
                    'assets/images/NextChord-Logo-transparent.png',
                    width: logoWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                    semanticLabel: 'NextChord logo',
                  ),
                  const SizedBox(height: 24),
                  // Responsive title text
                  Text(
                    'NextChord',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (screenWidth * 0.08)
                          .clamp(24.0, 48.0), // Responsive font size
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Responsive subtitle text
                  Text(
                    'Select a song from the library to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (screenWidth * 0.04)
                          .clamp(14.0, 18.0), // Responsive font size
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Responsive button
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<GlobalSidebarProvider>().toggleSidebar(),
                    icon: const Icon(Icons.menu),
                    label: const Text('Open Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0468cc),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: (screenWidth * 0.06).clamp(16.0, 32.0),
                        vertical: (screenHeight * 0.02).clamp(12.0, 16.0),
                      ),
                      textStyle: TextStyle(
                        fontSize: (screenWidth * 0.03).clamp(12.0, 16.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
