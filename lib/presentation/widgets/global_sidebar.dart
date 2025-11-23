import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/global_sidebar_provider.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/setlist_provider.dart';
import '../controllers/global_sidebar_controller.dart';
import '../screens/song_editor_screen_refactored.dart';
import 'midi_settings_modal.dart';
import 'midi_profiles_modal.dart';
import 'metronome_settings_modal.dart';
import 'guitar_tuner_modal.dart';
import 'storage_settings_modal.dart';
import 'sidebar_views/sidebar_menu_view.dart';
import 'sidebar_views/sidebar_all_songs_view.dart';
import 'sidebar_views/sidebar_setlist_view.dart';
import 'sidebar_views/sidebar_deleted_songs_view.dart';
import 'sidebar_views/sidebar_artists_list_view.dart';
import 'sidebar_views/sidebar_artist_songs_view.dart';
import 'sidebar_views/sidebar_tags_list_view.dart';
import 'sidebar_views/sidebar_tag_songs_view.dart';

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
  late GlobalSidebarController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GlobalSidebarController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: 1.0,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<GlobalSidebarProvider>()
            .initializeAnimation(_animationController);
        // Initialize controller with SetlistProvider for active setlist management
        _controller.initialize(context.read<SetlistProvider>());
      }
    });

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final sidebarWidth = Platform.isIOS ? 320.0 : 256.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final width = sidebarWidth * _animation.value;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: width,
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
          clipBehavior: Clip.hardEdge,
          child: width > 0 ? _buildSidebar(context, sidebarWidth) : null,
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, double sidebarWidth) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return IconButtonTheme(
      data: IconButtonThemeData(
        style: ButtonStyle(
          iconSize: MaterialStateProperty.all(isIOS ? 24.0 : 20.0),
          padding: MaterialStateProperty.all(
            EdgeInsets.all(isIOS ? 12.0 : 8.0),
          ),
          minimumSize: MaterialStateProperty.all(
            Size(isIOS ? 44 : 40, isIOS ? 44 : 40),
          ),
        ),
      ),
      child: IconTheme(
        data: IconThemeData(size: isIOS ? 24 : 20),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: sidebarWidth,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0468cc),
                  Color.fromARGB(99, 3, 73, 153),
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
            child: _buildCurrentView(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(BuildContext context) {
    switch (_controller.currentView) {
      case 'allSongs':
        return SidebarAllSongsView(
          onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
          onAddSong: () => _navigateToAddSong(),
        );
      case 'deletedSongs':
        return SidebarDeletedSongsView(
          onBack: () => _controller.navigateToMenu(),
        );
      case 'artistsList':
        return SidebarArtistsListView(
          onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
          onArtistSelected: (artist) => _controller.navigateToView(
            'artistSongs',
            artist: artist,
          ),
        );
      case 'artistSongs':
        return SidebarArtistSongsView(
          artist: _controller.selectedArtist ?? '',
          onBack: () => _controller.navigateToView('artistsList'),
        );
      case 'tagsList':
        return SidebarTagsListView(
          onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
          onTagSelected: (tag) => _controller.navigateToView(
            'tagSongs',
            tag: tag,
          ),
        );
      case 'tagSongs':
        return SidebarTagSongsView(
          tag: _controller.selectedTag ?? '',
          onBack: () => _controller.navigateToView('tagsList'),
        );
      case 'setlistView':
        return SidebarSetlistView(
          setlistId: _controller.selectedSetlistId ?? '',
          onBack: () => _controller.navigateToMenu(),
          onAddSong: () => _showAddSongsToSetlist(),
          onAddDivider: () => _showDividerDialog(),
        );
      default:
        return SidebarMenuView(
          onNavigateToAllSongs: () => _controller.navigateToView('allSongs'),
          onNavigateToArtistsList: () =>
              _controller.navigateToView('artistsList'),
          onNavigateToTagsList: () => _controller.navigateToView('tagsList'),
          onNavigateToDeletedSongs: () =>
              _controller.navigateToView('deletedSongs'),
          onNavigateToSetlistView: () =>
              _controller.navigateToView('setlistView'),
          onNavigateToSetlistViewWithId: (setlistId) =>
              _controller.navigateToView('setlistView', setlistId: setlistId),
          onNavigateToMidiSettings: () => _showMidiSettings(),
          onNavigateToMidiProfiles: () => _showMidiProfiles(),
          onNavigateToMetronomeSettings: () => _showMetronomeSettings(),
          onNavigateToGuitarTuner: () => _showGuitarTuner(),
          onNavigateToStorageSettings: () => _showStorageSettings(),
        );
    }
  }

  void _navigateToAddSong() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SongEditorScreenRefactored(),
      ),
    );
    if (result == true && context.mounted) {
      context.read<SongProvider>().loadSongs();
    }
  }

  void _showMidiSettings() {
    MidiSettingsModal.show(context);
  }

  void _showMidiProfiles() {
    MidiProfilesModal.show(context);
  }

  void _showMetronomeSettings() {
    MetronomeSettingsModal.show(context);
  }

  void _showGuitarTuner() {
    GuitarTunerModal.show(context);
  }

  void _showStorageSettings() {
    StorageSettingsModal.show(context);
  }

  void _showAddSongsToSetlist() {
    // Implementation would go here
  }

  void _showDividerDialog() {
    // Implementation would go here
  }
}
