import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/logger.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../providers/metronome_provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../providers/autoscroll_provider.dart';
import '../providers/setlist_provider.dart';
import '../providers/song_viewer_provider.dart';
import '../widgets/chord_renderer.dart';
import '../widgets/tag_edit_dialog.dart';
import '../widgets/song_viewer_header.dart';
import '../widgets/song_metadata_section.dart';
import '../widgets/transpose_button.dart';
import '../widgets/capo_button.dart';
import '../widgets/autoscroll_button.dart';
import '../widgets/metronome_button.dart';
import '../widgets/metronome_flash_overlay.dart';
import '../mixins/song_viewer_gestures.dart';
import '../../services/midi_integration_service.dart';
import '../../services/setlist_navigation_service.dart';
import '../../services/midi/midi_service.dart';
import 'song_editor_screen_refactored.dart';

/// Full-screen song viewer for live performance
/// Displays lyrics/chords with adjustable font size and theme toggle
class SongViewerScreen extends StatefulWidget {
  final Song song;
  final VoidCallback? onSongEdit;
  final SetlistSongItem? setlistContext;

  const SongViewerScreen({
    Key? key,
    required this.song,
    this.onSongEdit,
    this.setlistContext,
  }) : super(key: key);

  @override
  State<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends State<SongViewerScreen>
    with SongViewerGestures {
  late SongViewerProvider _songViewerProvider;
  late MidiIntegrationService _midiIntegrationService;
  late SetlistNavigationService _setlistNavigationService;
  late MetronomeProvider _metronome;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Logger.methodEntry('SongViewerScreen', 'initState');

    // Initialize providers and services
    _songViewerProvider = SongViewerProvider(
      song: widget.song,
      setlistContext: widget.setlistContext,
    );

    _initializeServices();
    super.initializeGestures(_songViewerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializePostFrame();
    });

    // Enable landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Logger.methodExit('SongViewerScreen', 'initState');
  }

  void _initializeServices() {
    final songRepository = context.read<SongRepository>();
    final midiService = context.read<MidiService>();
    final setlistProvider = context.read<SetlistProvider>();
    final globalSidebarProvider = context.read<GlobalSidebarProvider>();

    _midiIntegrationService = MidiIntegrationService(
      songRepository: songRepository,
      midiService: midiService,
    );

    _setlistNavigationService = SetlistNavigationService(
      songRepository: songRepository,
      setlistProvider: setlistProvider,
      globalSidebarProvider: globalSidebarProvider,
    );
  }

  void _initializePostFrame() {
    _syncMetronomeSettings();
    _initializeAutoscroll();
    _sendMidiMappingOnOpen();
    _focusNode.requestFocus();
  }

  /// Send MIDI mapping when song is opened in viewer
  Future<void> _sendMidiMappingOnOpen() async {
    await _midiIntegrationService.sendMidiMappingOnOpen(
      _songViewerProvider.currentSong.id,
      _songViewerProvider.currentSong.title,
      _songViewerProvider.currentSong.bpm,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metronome = context.read<MetronomeProvider>();
  }

  void _initializeAutoscroll() {
    final autoscroll = context.read<AutoscrollProvider>();
    final metronomeSettings = context.read<MetronomeSettingsProvider>();

    // Stop any existing autoscroll when loading a new song
    autoscroll.stop();

    autoscroll.initialize(_songViewerProvider.currentSong.body);
    autoscroll.setScrollController(scrollController);
    autoscroll.setMetronomeProviders(_metronome, metronomeSettings);

    // Set up callback for metronome to check if autoscroll is active
    _metronome.setAutoscrollActiveCallback(() => autoscroll.isActive);
  }

  @override
  void didUpdateWidget(covariant SongViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final songChanged = oldWidget.song.id != widget.song.id;
    final setlistChanged =
        oldWidget.setlistContext?.songId != widget.setlistContext?.songId;

    if (songChanged || setlistChanged) {
      _songViewerProvider.updateSong(widget.song);
      _songViewerProvider.closeAllFlyouts();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncMetronomeSettings();
        _initializeAutoscroll();
      });
    }
  }

  void _syncMetronomeSettings() {
    if (!mounted) return;
    final song = _songViewerProvider.currentSong;
    final bpm = song.bpm > 0 ? song.bpm : 120;
    final timeSig = song.timeSignature.isNotEmpty ? song.timeSignature : '4/4';
    _metronome
      ..setTempo(bpm)
      ..setTimeSignature(timeSig);
  }

  /// Handle horizontal swipe gestures for setlist navigation
  void _handleHorizontalSwipeEnd(DragEndDetails details) {
    if (!shouldHandleGesture()) return;
    handleHorizontalSwipeEnd(details, _handleSetlistNavigation);
  }

  /// Handle keyboard navigation for setlist songs
  void _handleKeyboardNavigation(bool isNext) {
    if (!shouldHandleGesture()) return;
    handleKeyboardNavigation(isNext, _handleSetlistNavigation);
  }

  /// Handle setlist navigation (both swipe and keyboard)
  void _handleSetlistNavigation(bool isNext) async {
    if (!_setlistNavigationService.canNavigate) return;

    Song? newSong;
    if (isNext) {
      newSong = await _setlistNavigationService.navigateToNextSong();
    } else {
      newSong = await _setlistNavigationService.navigateToPreviousSong();
    }

    if (newSong != null && mounted) {
      _songViewerProvider.updateSong(newSong);
      _songViewerProvider.closeAllFlyouts();
      resetScrollPosition();
      _syncMetronomeSettings();
      _initializeAutoscroll();
      _sendMidiMappingOnOpen();
    }
  }

  /// Get color for a tag based on whether it's an instrument tag
  (Color, Color) _getTagColors(String tag, BuildContext context) {
    if (SongViewerConstants.instrumentTags.contains(tag)) {
      return (Colors.orange.withValues(alpha: 0.2), Colors.orange);
    } else {
      return (
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onPrimaryContainer
      );
    }
  }

  /// Open the Edit Tags dialog
  Future<void> _openTagsDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (context) => TagEditDialog(
        title: 'Edit Tags',
        initialTags: _songViewerProvider.currentSong.tags.toSet(),
        onTagsUpdated: (updatedTags) async {
          await _updateSongTags(updatedTags.toSet());
        },
      ),
    );
  }

  /// Update song tags in database
  Future<void> _updateSongTags(Set<String> updatedTags) async {
    try {
      final repository = context.read<SongRepository>();
      final updatedSong =
          _songViewerProvider.currentSong.copyWith(tags: updatedTags.toList());
      await repository.updateSong(updatedSong);
      await _reloadSong();
    } catch (e) {
      Logger.error('Failed to update song tags', e);
    }
  }

  /// Reorder song tags in database
  Future<void> _reorderTags(List<String> updatedTags) async {
    await _updateSongTags(updatedTags.toSet());
  }

  /// Remove a tag from the song
  Future<void> _removeTag(String tag) async {
    final currentTags = _songViewerProvider.currentSong.tags;
    if (!currentTags.contains(tag)) return;

    final updatedTags = Set<String>.from(currentTags)..remove(tag);
    await _updateSongTags(updatedTags);
  }

  /// Reload the song from the database to get fresh data
  Future<bool> _reloadSong() async {
    try {
      final repository = context.read<SongRepository>();
      final updatedSong =
          await repository.getSongById(_songViewerProvider.currentSong.id);
      if (updatedSong != null && mounted) {
        _songViewerProvider.updateSong(updatedSong);
        _syncMetronomeSettings();
        return true;
      }
    } catch (e) {
      Logger.error('Failed to reload song', e);
    }
    return false;
  }

  /// Delete the current song with confirmation
  Future<void> _deleteSong() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text(
          'Are you sure you want to delete "${_songViewerProvider.currentSong.title}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final repository = context.read<SongRepository>();
      await repository.deleteSong(_songViewerProvider.currentSong.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song deleted successfully')),
        );
        context.read<GlobalSidebarProvider>().clearCurrentSong();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle edit button press
  Future<void> _handleEdit() async {
    widget.onSongEdit?.call();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongEditorScreenRefactored(
          song: _songViewerProvider.currentSong,
          setlistContext: widget.setlistContext,
        ),
      ),
    );

    if (mounted) {
      await _handleEditResult(result);
    }
  }

  /// Handle result from song editor
  Future<void> _handleEditResult(dynamic result) async {
    if (result == 'deleted') {
      context.read<GlobalSidebarProvider>().clearCurrentSong();
    } else if (result == true) {
      final reloaded = await _reloadSong();
      if (!reloaded) {
        context.read<GlobalSidebarProvider>().clearCurrentSong();
      } else {
        context
            .read<GlobalSidebarProvider>()
            .navigateToSong(_songViewerProvider.currentSong);
      }
    }
  }

  @override
  void dispose() {
    Logger.methodEntry('SongViewerScreen', 'dispose');
    _metronome.stop();
    disposeGestures();
    _focusNode.dispose();

    // Reset to portrait only when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
    Logger.methodExit('SongViewerScreen', 'dispose');
  }

  @override
  Widget build(BuildContext context) {
    Logger.methodEntry('SongViewerScreen', 'build');

    return ChangeNotifierProvider.value(
      value: _songViewerProvider,
      child: Consumer<SongViewerProvider>(
        builder: (context, provider, _) {
          final themeProvider = Theme.of(context);
          final isDarkMode = themeProvider.brightness == Brightness.dark;
          final backgroundColor =
              isDarkMode ? const Color(0xFF121212) : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black87;

          return Scaffold(
            backgroundColor: backgroundColor,
            body: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKey: (node, event) {
                if (event is RawKeyDownEvent &&
                    _setlistNavigationService.canNavigate) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _handleKeyboardNavigation(false);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey ==
                      LogicalKeyboardKey.arrowRight) {
                    _handleKeyboardNavigation(true);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: SafeArea(
                child: Shortcuts(
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                        const _NavigatePrevIntent(),
                    LogicalKeySet(LogicalKeyboardKey.arrowRight):
                        const _NavigateNextIntent(),
                  },
                  child: Actions(
                    actions: {
                      _NavigatePrevIntent: CallbackAction<_NavigatePrevIntent>(
                        onInvoke: (_) => _handleKeyboardNavigation(false),
                      ),
                      _NavigateNextIntent: CallbackAction<_NavigateNextIntent>(
                        onInvoke: (_) => _handleKeyboardNavigation(true),
                      ),
                    },
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent &&
                            shouldHandleGesture()) {
                          handleScrollWheelZoom(event);
                        }
                      },
                      child: GestureDetector(
                        onScaleStart: (_) => handleScaleStart(),
                        onScaleUpdate: (details) {
                          if (shouldHandleGesture()) {
                            handlePinchToZoom(details, provider.fontSize);
                          }
                        },
                        child: Stack(
                          children: [
                            // Main content
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => handleTapToCloseFlyouts(),
                              onHorizontalDragEnd: _handleHorizontalSwipeEnd,
                              child: Column(
                                children: [
                                  // Header
                                  SongViewerHeader(
                                    songTitle: provider.currentSong.title,
                                    nextSongDisplayTextFuture:
                                        _setlistNavigationService
                                            .getNextSongDisplayText(),
                                  ),
                                  // Scrollable content
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      padding: const EdgeInsets.all(
                                          SongViewerConstants.contentPadding),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Song metadata section
                                          SongMetadataSection(
                                            song: provider.currentSong,
                                            currentCapo: provider.currentCapo,
                                            keyDisplayLabel:
                                                provider.keyDisplayLabel,
                                            tags: provider.currentSong.tags,
                                            hasTags: provider
                                                .currentSong.tags.isNotEmpty,
                                            textColor: textColor,
                                            onRemoveTag: _removeTag,
                                            onEditTags: _openTagsDialog,
                                            onReorderTags: _reorderTags,
                                            getTagColors: (tag) =>
                                                _getTagColors(tag, context),
                                          ),
                                          const SizedBox(height: 24),
                                          // Song content
                                          ChordRenderer(
                                            chordProText:
                                                provider.currentSong.body,
                                            fontSize: provider.fontSize,
                                            isDarkMode: isDarkMode,
                                            transposeSteps: provider
                                                .effectiveTransposeSteps,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Floating UI elements
                            _buildFloatingUI(context, isDarkMode, textColor),
                            const MetronomeFlashOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingUI(
      BuildContext context, bool isDarkMode, Color textColor) {
    return Stack(
      children: [
        // Sidebar toggle button
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            icon: Icon(Icons.menu, color: textColor, size: 28),
            onPressed: () =>
                context.read<GlobalSidebarProvider>().toggleSidebar(),
            tooltip: 'Toggle sidebar',
          ),
        ),
        // Top right buttons
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Share button
              IconButton(
                icon: Icon(
                  Icons.share,
                  color: isDarkMode
                      ? SongViewerConstants.darkModeAccent
                      : SongViewerConstants.lightModeAccent,
                  size: 28,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Share functionality coming soon!')),
                  );
                },
                tooltip: 'Share song',
              ),
              const SizedBox(width: 8),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                onPressed: _deleteSong,
                tooltip: 'Delete song',
              ),
              const SizedBox(width: 8),
              // Edit button
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: isDarkMode
                      ? SongViewerConstants.darkModeAccent
                      : SongViewerConstants.lightModeAccent,
                  size: 28,
                ),
                onPressed: _handleEdit,
                tooltip: 'Edit song',
              ),
            ],
          ),
        ),
        // Bottom right adjustment buttons
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSettingsFlyoutButton(isDarkMode),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              TransposeButton(provider: _songViewerProvider),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              CapoButton(provider: _songViewerProvider),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              AutoscrollButton(
                autoscrollProvider: context.read<AutoscrollProvider>(),
                viewerProvider: _songViewerProvider,
              ),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              SizedBox(
                width: 96,
                child: const MetronomeButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsFlyoutButton(bool isDarkMode) {
    final backgroundColor = isDarkMode
        ? const Color(0xFF0A0A0A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accent = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    return SizedBox(
      width: SongViewerConstants.flyoutWidth,
      height: SongViewerConstants.flyoutHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // Settings flyout content
          Positioned(
            right: 52,
            child: AnimatedOpacity(
              duration: SongViewerConstants.flyoutAnimationDuration,
              opacity: _songViewerProvider.showSettingsFlyout ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_songViewerProvider.showSettingsFlyout,
                child: Container(
                  width: SongViewerConstants.flyoutExtendedWidth,
                  height: SongViewerConstants.flyoutHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.0),
                    boxShadow: _buildFloatingShadows(isDarkMode),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                            isDarkMode ? Icons.dark_mode : Icons.light_mode),
                        onPressed: () =>
                            context.read<ThemeProvider>().toggleTheme(),
                        color: accent,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Toggle theme',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Theme',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Settings toggle button
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: () =>
                  _songViewerProvider.toggleFlyout(FlyoutType.settings),
              child: Container(
                width: SongViewerConstants.buttonSize,
                height: SongViewerConstants.buttonSize,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: _buildFloatingShadows(isDarkMode),
                ),
                child: Center(
                  child: Icon(
                    Icons.settings,
                    color: accent,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BoxShadow> _buildFloatingShadows(bool isDarkMode) {
    return isDarkMode
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];
  }
}

// Intent classes for keyboard navigation
class _NavigatePrevIntent extends Intent {
  const _NavigatePrevIntent();
}

class _NavigateNextIntent extends Intent {
  const _NavigateNextIntent();
}
