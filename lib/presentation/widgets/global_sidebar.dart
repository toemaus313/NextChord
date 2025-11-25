import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/global_sidebar_provider.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/setlist_provider.dart';
import '../controllers/global_sidebar_controller.dart';
import '../../services/midi/midi_device_manager.dart';
import '../screens/song_editor_screen_refactored.dart';
import 'midi_settings_modal.dart';
import 'midi_profiles_modal.dart';
import 'metronome_settings_modal.dart';
import 'guitar_tuner_modal.dart';
import 'storage_settings_modal.dart';
import 'app_control_modal.dart';
import 'action_test_modal.dart';
import 'sidebar_views/sidebar_menu_view.dart';
import 'sidebar_views/sidebar_all_songs_view.dart';
import 'sidebar_views/sidebar_setlist_view.dart';
import 'sidebar_views/sidebar_deleted_songs_view.dart';
import 'sidebar_views/sidebar_artists_list_view.dart';
import 'sidebar_views/sidebar_artist_songs_view.dart';
import 'sidebar_views/sidebar_tags_list_view.dart';
import 'sidebar_views/sidebar_tag_songs_view.dart';
import 'mobile_songs_layout.dart';
import 'sidebar_components/mobile_sidebar_scaffold.dart';
import '../../core/widgets/responsive_config.dart';

/// Helper method to detect if we're actually on a phone (not just small screen)
bool _isActualPhone(BuildContext context) {
  final isPhoneSized = MediaQuery.of(context).size.width < 600;
  final isMobilePlatform = Platform.isIOS || Platform.isAndroid;
  return isPhoneSized && isMobilePlatform;
}

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
        _controller.initialize(
          context.read<SetlistProvider>(),
          context.read<SongProvider>(),
        );
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
    final isPhone = ResponsiveConfig.isPhone(context);

    if (isPhone) {
      // Phone mode: full-screen sidebar with SafeArea for camera notch
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0468cc),
                Color.fromARGB(99, 3, 73, 153),
              ],
            ),
          ),
          child: SafeArea(
            child: _buildSidebar(context, MediaQuery.of(context).size.width),
          ),
        ),
      );
    } else {
      // Desktop/Tablet mode: animated sidebar
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
    final isPhone = _isActualPhone(context);

    switch (_controller.currentView) {
      case 'allSongs':
        final view = SidebarAllSongsView(
          onBack: () {
            // Reset selection mode and search before going back
            context.read<SongProvider>().resetSelectionMode();
            context.read<SongProvider>().searchSongs('');
            _controller.navigateToMenuKeepSongsExpanded();
          },
          onAddSong: () => _navigateToAddSong(),
          showHeader: !isPhone, // Hide header on mobile, show on desktop
        );
        return isPhone
            ? MobileSidebarScaffold(
                title: 'All Songs',
                icon: Icons.music_note,
                onBack: () {
                  // Reset selection mode and search before going back
                  context.read<SongProvider>().resetSelectionMode();
                  context.read<SongProvider>().searchSongs('');
                  _controller.navigateToMenuKeepSongsExpanded();
                },
                body: view,
              )
            : view;

      case 'deletedSongs':
        final view = SidebarDeletedSongsView(
          onBack: () => _controller.navigateToMenu(),
          showHeader: !isPhone, // Hide header on mobile, show on desktop
        );
        return isPhone
            ? MobileSidebarScaffold(
                title: 'Deleted Songs',
                icon: Icons.delete_outline,
                onBack: () => _controller.navigateToMenu(),
                body: view,
              )
            : view;

      case 'artistsList':
        final view = SidebarArtistsListView(
          onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
          onArtistSelected: (artist) => _controller.navigateToView(
            'artistSongs',
            artist: artist,
          ),
          showHeader: !isPhone, // Hide header on mobile, show on desktop
        );
        return isPhone
            ? MobileSidebarScaffold(
                title: 'Artists',
                icon: Icons.person_outline,
                onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
                body: view,
              )
            : view;

      case 'artistSongs':
        if (isPhone) {
          // Mobile layout using reusable MobileSongsLayout
          return MobileSongsLayout(
            searchHint: 'Search ${_controller.selectedArtist ?? ''} songs',
            child: SidebarArtistSongsView(
              artist: _controller.selectedArtist ?? '',
              onBack: () => _controller.navigateToView('artistsList'),
              showHeader: false, // No header on mobile
            ),
          );
        } else {
          // Desktop layout
          return SidebarArtistSongsView(
            artist: _controller.selectedArtist ?? '',
            onBack: () => _controller.navigateToView('artistsList'),
            showHeader: true,
          );
        }

      case 'tagsList':
        final view = SidebarTagsListView(
          onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
          onTagSelected: (tag) => _controller.navigateToView(
            'tagSongs',
            tag: tag,
          ),
          showHeader: !isPhone, // Hide header on mobile, show on desktop
        );
        return isPhone
            ? MobileSidebarScaffold(
                title: 'Tags',
                icon: Icons.tag,
                onBack: () => _controller.navigateToMenuKeepSongsExpanded(),
                body: view,
              )
            : view;

      case 'tagSongs':
        if (isPhone) {
          // Mobile layout using reusable MobileSongsLayout
          return MobileSongsLayout(
            searchHint: 'Search #${_controller.selectedTag ?? ''} songs',
            child: SidebarTagSongsView(
              tag: _controller.selectedTag ?? '',
              onBack: () => _controller.navigateToView('tagsList'),
              showHeader: false, // No header on mobile
            ),
          );
        } else {
          // Desktop layout
          return SidebarTagSongsView(
            tag: _controller.selectedTag ?? '',
            onBack: () => _controller.navigateToView('tagsList'),
            showHeader: true,
          );
        }

      case 'setlistView':
        final view = SidebarSetlistView(
          setlistId: _controller.selectedSetlistId ?? '',
          onBack: () => _controller.navigateToMenu(),
          onAddSong: () => _showAddSongsToSetlist(),
          onAddDivider: () {}, // TODO: Implement add divider functionality
          showHeader: !isPhone, // Hide header on mobile, show on desktop
        );
        return isPhone
            ? MobileSidebarScaffold(
                title: _getSetlistTitle(context),
                icon: Icons.playlist_play,
                onBack: () => _controller.navigateToMenu(),
                body: view,
              )
            : view;

      default:
        final view = SidebarMenuView(
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
          onNavigateToAppControl: () => _showAppControl(),
          onNavigateToActionTest: () => _showActionTest(),
          isPhoneMode: _isActualPhone(context),
          showHeader: !isPhone, // Hide header on mobile, show on desktop
        );
        return isPhone
            ? MobileSidebarScaffold(
                title: 'Library',
                icon: Icons.library_music,
                body: view,
              )
            : view;
    }
  }

  /// Helper method to get setlist title for mobile header
  String _getSetlistTitle(BuildContext context) {
    final setlistProvider = context.read<SetlistProvider>();
    final setlist = setlistProvider.setlists
        .where((s) => s.id == _controller.selectedSetlistId)
        .firstOrNull;
    return setlist?.name ?? 'Setlist';
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

  void _showAppControl() {
    // Use singleton instance since Provider is not available in this context
    AppControlModal.show(context, deviceManager: MidiDeviceManager());
  }

  void _showActionTest() {
    ActionTestModal.show(context);
  }

  void _showAddSongsToSetlist() {
    // Implementation would go here
  }
}
