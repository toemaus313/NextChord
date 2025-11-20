import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/chordpro_parser.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../providers/metronome_provider.dart';
import '../providers/autoscroll_provider.dart';
import '../providers/setlist_provider.dart';
import '../widgets/chord_renderer.dart';
import '../widgets/tag_edit_dialog.dart';
import 'song_editor_screen.dart';

const Color _sidebarTopColor = Color(0xFF0468cc);

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

/// Lightweight metadata describing how chords should be adjusted in the viewer.
/// This lets us keep track of per-setlist overrides without mutating the base song.
class ViewerAdjustmentMetadata {
  final int transposeSteps;
  final int capo;
  final bool appliesToSetlist;

  const ViewerAdjustmentMetadata({
    required this.transposeSteps,
    required this.capo,
    required this.appliesToSetlist,
  });

  ViewerAdjustmentMetadata copyWith({
    int? transposeSteps,
    int? capo,
    bool? appliesToSetlist,
  }) {
    return ViewerAdjustmentMetadata(
      transposeSteps: transposeSteps ?? this.transposeSteps,
      capo: capo ?? this.capo,
      appliesToSetlist: appliesToSetlist ?? this.appliesToSetlist,
    );
  }
}

class _ViewerTagWrap extends StatelessWidget {
  final List<String> tags;
  final bool hasTags;
  final Color textColor;
  final Future<void> Function(String tag) onRemove;
  final VoidCallback onEdit;
  final (Color, Color) Function(String tag) getTagColors;

  const _ViewerTagWrap({
    required this.tags,
    required this.hasTags,
    required this.textColor,
    required this.onRemove,
    required this.onEdit,
    required this.getTagColors,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasTags) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Tags',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Text(
            'No tags yet',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
          _buildEditButton(),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        ...tags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;
          final (bgColor, tagTextColor) = getTagColors(tag);
          return DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) async {
              final updated = List<String>.from(tags);
              final tagToMove = updated.removeAt(details.data);
              updated.insert(index, tagToMove);
              await _reorderTags(context, updated);
            },
            builder: (context, candidate, rejected) {
              return Draggable<int>(
                data: index,
                feedback: Opacity(
                  opacity: 0.7,
                  child: Material(
                    color: Colors.transparent,
                    child: _TagChip(
                      tag: tag,
                      bgColor: bgColor,
                      textColor: tagTextColor,
                      onRemove: () {},
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _TagChip(
                    tag: tag,
                    bgColor: bgColor,
                    textColor: tagTextColor,
                    onRemove: () => onRemove(tag),
                  ),
                ),
                child: _TagChip(
                  tag: tag,
                  bgColor: bgColor,
                  textColor: tagTextColor,
                  onRemove: () => onRemove(tag),
                ),
              );
            },
          );
        }),
        _buildEditButton(),
      ],
    );
  }

  Future<void> _reorderTags(BuildContext context, List<String> updated) async {
    final repository = context.read<SongRepository>();
    final state = context.findAncestorStateOfType<_SongViewerScreenState>();
    if (state == null) return;
    final updatedSong = state._currentSong.copyWith(tags: updated);
    await repository.updateSong(updatedSong);
    await state._reloadSong();
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 14, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                  fontSize: 12, color: textColor.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onRemove;

  const _TagChip({
    required this.tag,
    required this.bgColor,
    required this.textColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: textColor),
          ),
        ],
      ),
    );
  }
}

class _SongViewerScreenState extends State<SongViewerScreen> {
  static const int _minTranspose = -12;
  static const int _maxTranspose = 12;
  static const int _minCapo = 0;
  static const int _maxCapo = 12;

  double _fontSize = 18.0;
  double _baseFontSize = 18.0; // Font size at the start of pinch gesture
  int _transposeSteps = 0; // Semitones to transpose
  late Song _currentSong; // Mutable song that can be refreshed
  bool _showSettingsFlyout = false; // Compact settings flyout visibility
  int _currentCapo = 0;
  bool _showTransposeFlyout = false;
  bool _showCapoFlyout = false;
  bool _showAutoscrollFlyout = false;
  late ViewerAdjustmentMetadata _viewerAdjustments;
  late MetronomeProvider _metronome;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
    _transposeSteps = widget.setlistContext?.transposeSteps ?? 0;
    _currentCapo = widget.setlistContext?.capo ?? widget.song.capo;
    _initializeViewerAdjustments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncMetronomeSettings();
      _initializeAutoscroll();
    });
    // Enable landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metronome = context.read<MetronomeProvider>();
  }

  void _initializeViewerAdjustments() {
    _viewerAdjustments = ViewerAdjustmentMetadata(
      transposeSteps: _transposeSteps,
      capo: _currentCapo,
      appliesToSetlist: widget.setlistContext != null,
    );
  }

  void _initializeAutoscroll() {
    final autoscroll = context.read<AutoscrollProvider>();
    autoscroll.initialize(_currentSong.body);
    autoscroll.setScrollController(_scrollController);
  }

  @override
  void didUpdateWidget(covariant SongViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final songChanged = oldWidget.song.id != widget.song.id;
    final setlistChanged =
        oldWidget.setlistContext?.songId != widget.setlistContext?.songId;
    if (songChanged || setlistChanged) {
      setState(() {
        _currentSong = widget.song;
        _transposeSteps = widget.setlistContext?.transposeSteps ?? 0;
        _currentCapo = widget.setlistContext?.capo ?? widget.song.capo;
        _initializeViewerAdjustments();
        _showTransposeFlyout = false;
        _showCapoFlyout = false;
        _showAutoscrollFlyout = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncMetronomeSettings();
        _initializeAutoscroll();
      });
    }
  }

  bool get _hasSetlistContext => widget.setlistContext != null;

  int get _capoOffsetFromSong => _currentSong.capo - _currentCapo;

  int get _effectiveTransposeSteps => _transposeSteps + _capoOffsetFromSong;

  String get _transposeStatusLabel {
    final steps = _effectiveTransposeSteps;
    if (steps == 0) return 'No transposition';
    final unit = steps.abs() == 1 ? 'semitone' : 'semitones';
    return 'Transposed ${_formatSignedValue(steps)} $unit';
  }

  String get _capoStatusLabel {
    final defaultCapo = _currentSong.capo;
    if (_currentCapo == defaultCapo) {
      return 'Capo $_currentCapo (song default)';
    }
    final direction = _currentCapo > defaultCapo ? 'higher' : 'lower';
    return 'Capo $_currentCapo (${(defaultCapo - _currentCapo).abs()} frets $direction than song)';
  }

  String? _getKeyDisplayLabel() {
    final baseKey = _currentSong.key.trim();
    if (baseKey.isEmpty) return null;
    final steps = _effectiveTransposeSteps;
    if (steps == 0) {
      return 'Key of $baseKey';
    }
    final transposed = ChordProParser.transposeChord(baseKey, steps);
    return 'Key of $transposed (${_formatSignedValue(steps)})';
  }

  String _formatSignedValue(int value) =>
      value > 0 ? '+$value' : value.toString();

  void _updateTranspose(int delta) {
    final int updated =
        (_transposeSteps + delta).clamp(_minTranspose, _maxTranspose);
    if (updated == _transposeSteps) return;
    setState(() {
      _transposeSteps = updated;
      _viewerAdjustments = _viewerAdjustments.copyWith(transposeSteps: updated);
    });

    // Save to setlist if setlist-specific edits are enabled
    _saveTransposeToSetlist(updated);
  }

  void _updateCapo(int delta) {
    final int updated = (_currentCapo + delta).clamp(_minCapo, _maxCapo);
    if (updated == _currentCapo) return;
    setState(() {
      _currentCapo = updated;
      _viewerAdjustments = _viewerAdjustments.copyWith(capo: updated);
    });

    // Save to setlist if setlist-specific edits are enabled
    _saveCapoToSetlist(updated);
  }

  /// Save transpose setting to setlist if applicable
  void _saveTransposeToSetlist(int transposeSteps) async {
    debugPrint('🎵 SongViewerScreen: _saveTransposeToSetlist called');
    debugPrint('   - _hasSetlistContext: $_hasSetlistContext');
    debugPrint('   - transposeSteps: $transposeSteps');

    if (!_hasSetlistContext) {
      debugPrint('🎵 SongViewerScreen: ABORT - no setlist context');
      return;
    }

    final setlistProvider = context.read<SetlistProvider>();
    debugPrint(
        '   - setlistProvider.isSetlistActive: ${setlistProvider.isSetlistActive}');

    if (!setlistProvider.isSetlistActive) {
      debugPrint('🎵 SongViewerScreen: ABORT - setlist not active');
      return;
    }

    // Only save if setlist-specific edits are enabled
    final activeSetlist = setlistProvider.activeSetlist;
    debugPrint(
        '   - setlistSpecificEditsEnabled: ${activeSetlist?.setlistSpecificEditsEnabled}');

    if (activeSetlist?.setlistSpecificEditsEnabled != true) {
      debugPrint(
          '🎵 SongViewerScreen: ABORT - setlist-specific edits disabled');
      return;
    }

    try {
      debugPrint('🎵 SongViewerScreen: SAVING transpose to setlist...');
      await setlistProvider.updateCurrentSongAdjustments(
        transposeSteps: transposeSteps,
      );
      debugPrint('🎵 SongViewerScreen: SUCCESS - transpose saved to setlist');
    } catch (e) {
      debugPrint(
          '🎵 SongViewerScreen: ERROR - failed to save transpose to setlist: $e');
    }
  }

  /// Save capo setting to setlist if applicable
  void _saveCapoToSetlist(int capo) async {
    debugPrint('🎵 SongViewerScreen: _saveCapoToSetlist called');
    debugPrint('   - _hasSetlistContext: $_hasSetlistContext');
    debugPrint('   - capo: $capo');

    if (!_hasSetlistContext) {
      debugPrint('🎵 SongViewerScreen: ABORT - no setlist context');
      return;
    }

    final setlistProvider = context.read<SetlistProvider>();
    debugPrint(
        '   - setlistProvider.isSetlistActive: ${setlistProvider.isSetlistActive}');

    if (!setlistProvider.isSetlistActive) {
      debugPrint('🎵 SongViewerScreen: ABORT - setlist not active');
      return;
    }

    // Only save if setlist-specific edits are enabled
    final activeSetlist = setlistProvider.activeSetlist;
    debugPrint(
        '   - setlistSpecificEditsEnabled: ${activeSetlist?.setlistSpecificEditsEnabled}');

    if (activeSetlist?.setlistSpecificEditsEnabled != true) {
      debugPrint(
          '🎵 SongViewerScreen: ABORT - setlist-specific edits disabled');
      return;
    }

    try {
      debugPrint('🎵 SongViewerScreen: SAVING capo to setlist...');
      await setlistProvider.updateCurrentSongAdjustments(
        capo: capo,
      );
      debugPrint('🎵 SongViewerScreen: SUCCESS - capo saved to setlist');
    } catch (e) {
      debugPrint(
          '🎵 SongViewerScreen: ERROR - failed to save capo to setlist: $e');
    }
  }

  void _toggleTransposeFlyout() {
    setState(() {
      _showTransposeFlyout = !_showTransposeFlyout;
      if (_showTransposeFlyout) {
        _showCapoFlyout = false;
      }
    });
  }

  void _toggleCapoFlyout() {
    setState(() {
      _showCapoFlyout = !_showCapoFlyout;
      if (_showCapoFlyout) {
        _showTransposeFlyout = false;
        _showAutoscrollFlyout = false;
      }
    });
  }

  void _toggleAutoscrollFlyout() {
    final autoscroll = context.read<AutoscrollProvider>();
    setState(() {
      // If autoscroll is active, don't close the flyout when toggling
      if (autoscroll.isActive) {
        _showAutoscrollFlyout = true;
      } else {
        _showAutoscrollFlyout = !_showAutoscrollFlyout;
        if (_showAutoscrollFlyout) {
          _showTransposeFlyout = false;
          _showCapoFlyout = false;
        }
      }
    });
  }

  void _toggleSettingsFlyout() {
    setState(() {
      _showSettingsFlyout = !_showSettingsFlyout;
      if (_showSettingsFlyout) {
        _showTransposeFlyout = false;
        _showCapoFlyout = false;
        _showAutoscrollFlyout = false;
      }
    });
  }

  void _closeAllFlyouts() {
    if (!_showSettingsFlyout &&
        !_showTransposeFlyout &&
        !_showCapoFlyout &&
        !_showAutoscrollFlyout) {
      return;
    }
    setState(() {
      _showSettingsFlyout = false;
      _showTransposeFlyout = false;
      _showCapoFlyout = false;
      _showAutoscrollFlyout = false;
    });
  }

  /// Handle horizontal swipe gestures for setlist navigation
  void _handleHorizontalSwipeEnd(DragEndDetails details) {
    final setlistProvider = context.read<SetlistProvider>();
    if (!setlistProvider.isSetlistActive) return;

    // Check velocity and ensure it's a primarily horizontal gesture
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return; // Minimum velocity threshold

    if (velocity > 0) {
      // Swipe right -> Previous song
      _navigateToPreviousSong();
    } else {
      // Swipe left -> Next song
      _navigateToNextSong();
    }
  }

  /// Navigate to the next song in the setlist
  void _navigateToNextSong() async {
    final setlistProvider = context.read<SetlistProvider>();
    final globalSidebarProvider = context.read<GlobalSidebarProvider>();
    final songRepository = context.read<SongRepository>();

    final nextSongItem = setlistProvider.getNextSongItem();
    if (nextSongItem == null) return;

    try {
      final nextSong = await songRepository.getSongById(nextSongItem.songId);
      if (nextSong != null && mounted) {
        // Update setlist provider index
        setlistProvider
            .updateCurrentSongIndex(setlistProvider.currentSongIndex + 1);

        // Update global sidebar with new song and context
        globalSidebarProvider.navigateToSongInSetlist(
            nextSong, setlistProvider.currentSongIndex, nextSongItem);

        // Update current song state instead of navigating
        setState(() {
          _currentSong = nextSong;
          _transposeSteps = nextSongItem.transposeSteps ?? 0;
          _currentCapo = nextSongItem.capo ?? nextSong.capo;
          _initializeViewerAdjustments();
          _showTransposeFlyout = false;
          _showCapoFlyout = false;
          _showAutoscrollFlyout = false;
        });

        // Reset scroll position and sync settings
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        _syncMetronomeSettings();
        _initializeAutoscroll();
      }
    } catch (e) {
      debugPrint('Error navigating to next song: $e');
    }
  }

  /// Navigate to the previous song in the setlist
  void _navigateToPreviousSong() async {
    final setlistProvider = context.read<SetlistProvider>();
    final globalSidebarProvider = context.read<GlobalSidebarProvider>();
    final songRepository = context.read<SongRepository>();

    final prevSongItem = setlistProvider.getPreviousSongItem();
    if (prevSongItem == null) return;

    try {
      final prevSong = await songRepository.getSongById(prevSongItem.songId);
      if (prevSong != null && mounted) {
        // Update setlist provider index
        setlistProvider
            .updateCurrentSongIndex(setlistProvider.currentSongIndex - 1);

        // Update global sidebar with new song and context
        globalSidebarProvider.navigateToSongInSetlist(
            prevSong, setlistProvider.currentSongIndex, prevSongItem);

        // Update current song state instead of navigating
        setState(() {
          _currentSong = prevSong;
          _transposeSteps = prevSongItem.transposeSteps ?? 0;
          _currentCapo = prevSongItem.capo ?? prevSong.capo;
          _initializeViewerAdjustments();
          _showTransposeFlyout = false;
          _showCapoFlyout = false;
          _showAutoscrollFlyout = false;
        });

        // Reset scroll position and sync settings
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        _syncMetronomeSettings();
        _initializeAutoscroll();
      }
    } catch (e) {
      debugPrint('Error navigating to previous song: $e');
    }
  }

  /// Reload the song from the database to get fresh data
  /// Returns true if song was reloaded, false if song was deleted
  Future<bool> _reloadSong() async {
    final repository = context.read<SongRepository>();
    final updatedSong = await repository.getSongById(_currentSong.id);
    if (updatedSong != null && mounted) {
      setState(() {
        _currentSong = updatedSong;
      });
      _syncMetronomeSettings();
      return true;
    }
    // Song was deleted
    return false;
  }

  void _syncMetronomeSettings() {
    if (!mounted) return;
    final bpm = _currentSong.bpm > 0 ? _currentSong.bpm : 120;
    final timeSig = _currentSong.timeSignature.isNotEmpty
        ? _currentSong.timeSignature
        : '4/4';
    _metronome
      ..setTempo(bpm)
      ..setTimeSignature(timeSig);
  }

  /// Get color for a tag based on whether it's an instrument tag
  (Color, Color) _getTagColors(String tag, BuildContext context) {
    const instrumentTags = {
      'Acoustic',
      'Electric',
      'Piano',
      'Guitar',
      'Bass',
      'Drums',
      'Vocals',
      'Instrumental'
    };

    if (instrumentTags.contains(tag)) {
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
        initialTags: _currentSong.tags.toSet(),
        onTagsUpdated: (updatedTags) async {
          // Update the song in the database
          final repository = context.read<SongRepository>();
          final updatedSong = _currentSong.copyWith(tags: updatedTags);
          await repository.updateSong(updatedSong);

          // Reload the song to get fresh data
          await _reloadSong();
        },
      ),
    );
  }

  Future<void> _removeTag(String tag) async {
    if (!_currentSong.tags.contains(tag)) return;
    final repository = context.read<SongRepository>();
    final updatedTags = List<String>.from(_currentSong.tags)..remove(tag);
    final updatedSong = _currentSong.copyWith(tags: updatedTags);
    await repository.updateSong(updatedSong);
    await _reloadSong();
  }

  /// Delete the current song with confirmation
  Future<void> _deleteSong() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text(
          'Are you sure you want to delete "${_currentSong.title}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed != true) return;

    try {
      final repository = context.read<SongRepository>();
      await repository.deleteSong(_currentSong.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song deleted successfully'),
          ),
        );

        // Clear the current song from global state
        if (context.mounted) {
          context.read<GlobalSidebarProvider>().clearCurrentSong();
        }
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

  @override
  void dispose() {
    _metronome.stop();
    _scrollController.dispose();
    // Reset to portrait only when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              // Check if Ctrl key is pressed (for mouse wheel zoom)
              if (HardwareKeyboard.instance.isControlPressed) {
                setState(() {
                  // Scroll down = negative delta = increase font size
                  // Scroll up = positive delta = decrease font size
                  final delta = event.scrollDelta.dy;
                  _fontSize = (_fontSize - delta * 0.05).clamp(12.0, 48.0);
                });
              }
            }
          },
          child: GestureDetector(
            onScaleStart: (details) {
              // Store the current font size when pinch starts
              _baseFontSize = _fontSize;
            },
            onScaleUpdate: (details) {
              // Update font size based on pinch scale
              setState(() {
                _fontSize = (_baseFontSize * details.scale).clamp(12.0, 48.0);
              });
            },
            child: Stack(
              children: [
                // Main content - scrollable lyrics/chords
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _closeAllFlyouts(),
                  onHorizontalDragEnd: _handleHorizontalSwipeEnd,
                  child: Column(
                    children: [
                      // Header with song info (always visible)
                      _buildHeader(textColor),

                      // Scrollable song body
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Song metadata section
                              _buildSongMetadata(textColor),
                              const SizedBox(height: 24),
                              // Song content
                              ChordRenderer(
                                chordProText: _currentSong.body,
                                fontSize: _fontSize,
                                isDarkMode: isDarkMode,
                                transposeSteps: _effectiveTransposeSteps,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sidebar toggle button (always visible - static)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: textColor,
                      size: 28,
                    ),
                    onPressed: () {
                      context.read<GlobalSidebarProvider>().toggleSidebar();
                    },
                    tooltip: 'Toggle sidebar',
                  ),
                ),

                // Share button (always visible)
                Positioned(
                  top: 8,
                  right: 104,
                  child: IconButton(
                    icon: Icon(
                      Icons.share,
                      color: isDarkMode
                          ? const Color(0xFF00D9FF)
                          : const Color(0xFF0468cc),
                      size: 28,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share functionality coming soon!'),
                        ),
                      );
                    },
                    tooltip: 'Share song',
                  ),
                ),

                // Delete button (always visible)
                Positioned(
                  top: 8,
                  right: 56,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 28,
                    ),
                    onPressed: _deleteSong,
                    tooltip: 'Delete song',
                  ),
                ),

                // Edit button (always visible)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: isDarkMode
                          ? const Color(0xFF00D9FF)
                          : const Color(0xFF0468cc),
                      size: 28,
                    ),
                    onPressed: () async {
                      // Notify home screen that song is being edited
                      widget.onSongEdit?.call();

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SongEditorScreen(
                              song: _currentSong,
                              setlistContext: widget.setlistContext),
                        ),
                      );

                      // Handle the return from editor
                      if (mounted) {
                        if (result == 'deleted') {
                          // Song was deleted - clear it from global state
                          if (context.mounted) {
                            context
                                .read<GlobalSidebarProvider>()
                                .clearCurrentSong();
                          }
                        } else if (result == true) {
                          // Song was updated, reload it
                          final reloaded = await _reloadSong();
                          if (!reloaded && context.mounted) {
                            // Song was deleted while editing, clear it
                            context
                                .read<GlobalSidebarProvider>()
                                .clearCurrentSong();
                          } else if (context.mounted) {
                            // Update the song in global state with the reloaded version
                            context
                                .read<GlobalSidebarProvider>()
                                .navigateToSong(_currentSong);
                          }
                        }
                      }
                    },
                    tooltip: 'Edit song',
                  ),
                ),

                // Floating action buttons (bottom right)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildSettingsFlyoutButton(isDarkMode),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildTransposeButton(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildCapoButton(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildAutoscrollButton(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 96, // Fixed width to prevent shifting
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildMetronomeButton(),
                        ),
                      ),
                    ],
                  ),
                ),
                const _MetronomeFlashOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
      color: backgroundColor, // Match main window background
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentSong.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            _buildNextSongDisplay(textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSongDisplay(Color textColor) {
    final setlistProvider = context.read<SetlistProvider>();
    if (!setlistProvider.isSetlistActive) return const SizedBox.shrink();

    return FutureBuilder<String?>(
      future: _getNextSongDisplayText(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        return Text(
          snapshot.data!,
          style: TextStyle(
            fontSize: 14,
            color: textColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  Future<String?> _getNextSongDisplayText() async {
    final setlistProvider = context.read<SetlistProvider>();
    final songRepository = context.read<SongRepository>();

    final nextSongItem = setlistProvider.getNextSongItem();
    if (nextSongItem == null) return null;

    try {
      final nextSong = await songRepository.getSongById(nextSongItem.songId);
      if (nextSong == null) return null;

      // Calculate the effective key considering transpose/capo
      String effectiveKey = nextSong.key.trim();
      if (effectiveKey.isNotEmpty) {
        final transposeSteps = nextSongItem.transposeSteps ?? 0;
        final capoOffset = (nextSongItem.capo ?? nextSong.capo) - nextSong.capo;
        final totalTranspose = transposeSteps + capoOffset;

        if (totalTranspose != 0) {
          effectiveKey =
              ChordProParser.transposeChord(effectiveKey, totalTranspose);
        }

        return 'Next: ${nextSong.title} ($effectiveKey)';
      } else {
        return 'Next: ${nextSong.title}';
      }
    } catch (e) {
      debugPrint('Error getting next song display: $e');
      return null;
    }
  }

  Widget _buildInnerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDarkMode,
  }) {
    const glowColor = Color(0xFF00D9FF);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDarkMode
                ? Colors.grey.shade700
                    .withValues(alpha: 0.3) // Very faint border
                : Colors.grey.shade400.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: IconButton(
          icon: Icon(icon),
          color: isDarkMode ? glowColor : const Color(0xFF0468cc),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
      ),
    );
  }

  Widget _buildSettingsFlyoutButton(bool isDarkMode) {
    final backgroundColor = isDarkMode
        ? const Color(0xFF0A0A0A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accent =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

    return SizedBox(
      width: 220,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showSettingsFlyout ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showSettingsFlyout,
                child: Container(
                  width: 148,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.0),
                    boxShadow: _buildFloatingShadows(isDarkMode),
                  ),
                  child: Row(
                    children: [
                      _buildInnerButton(
                        icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        tooltip: 'Toggle theme',
                        onPressed: () {
                          context.read<ThemeProvider>().toggleTheme();
                        },
                        isDarkMode: isDarkMode,
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
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: _toggleSettingsFlyout,
              child: Container(
                width: 40,
                height: 40,
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

  Widget _buildCapoButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final iconColor =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

    return _buildAdjustmentFlyout(
      isDarkMode: isDarkMode,
      isOpen: _showCapoFlyout,
      onToggle: _toggleCapoFlyout,
      icon: CustomPaint(
        size: const Size(18, 18),
        painter: CapoIconPainter(color: iconColor),
      ),
      displayValue: '$_currentCapo',
      semanticsLabel: _capoStatusLabel,
      onIncrement: () => _updateCapo(1),
      onDecrement: () => _updateCapo(-1),
      canIncrement: _currentCapo < _maxCapo,
      canDecrement: _currentCapo > _minCapo,
      extraContent: _buildAdjustmentScopeToggle(isDarkMode),
    );
  }

  Widget _buildAutoscrollButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final accent =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

    return Consumer<AutoscrollProvider>(
      builder: (context, autoscroll, child) {
        return _buildAdjustmentFlyout(
          isDarkMode: isDarkMode,
          isOpen: _showAutoscrollFlyout,
          onToggle: () {
            final wasActive = autoscroll.isActive;
            final wasFlyoutOpen = _showAutoscrollFlyout;
            autoscroll.toggle();
            // Open flyout when autoscroll starts
            // Close flyout when stopping from open state
            // Keep flyout closed when stopping from closed state
            if (autoscroll.isActive) {
              setState(() {
                _showAutoscrollFlyout = true;
                _showTransposeFlyout = false;
                _showCapoFlyout = false;
              });
            } else if (wasActive && !wasFlyoutOpen) {
              // Was active with flyout closed, now stopping - keep flyout closed
              // Do nothing
            } else {
              // Normal toggle behavior
              _toggleAutoscrollFlyout();
            }
          },
          icon: Icon(
            autoscroll.isActive ? Icons.pause : Icons.play_arrow,
            color: autoscroll.isActive ? Colors.white : accent,
            size: 18,
          ),
          displayValue: autoscroll.durationDisplay,
          semanticsLabel: 'Autoscroll duration ${autoscroll.durationDisplay}',
          onIncrement: () => autoscroll.adjustDuration(15),
          onDecrement: () => autoscroll.adjustDuration(-15),
          canIncrement: autoscroll.durationSeconds < 600,
          canDecrement: autoscroll.durationSeconds > 30,
          isActive: autoscroll.isActive,
        );
      },
    );
  }

  Widget _buildTransposeButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final accent =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

    final icon = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '−',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 1),
        Icon(
          Icons.music_note,
          color: accent,
          size: 14,
        ),
        const SizedBox(width: 1),
        Text(
          '+',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ],
    );

    final capoOffset = _capoOffsetFromSong;
    final capoNote = capoOffset == 0
        ? null
        : Text(
            'Includes capo offset ${_formatSignedValue(capoOffset)}',
            style: TextStyle(
              fontSize: 11,
              color: accent.withValues(alpha: 0.9),
            ),
          );
    final scopeToggle = _buildAdjustmentScopeToggle(isDarkMode);

    Widget? extraContent;
    if (capoNote != null || scopeToggle != null) {
      extraContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (capoNote != null) capoNote,
          if (scopeToggle != null) ...[
            if (capoNote != null) const SizedBox(height: 6),
            scopeToggle,
          ],
        ],
      );
    }

    return _buildAdjustmentFlyout(
      isDarkMode: isDarkMode,
      isOpen: _showTransposeFlyout,
      onToggle: _toggleTransposeFlyout,
      icon: icon,
      displayValue: _formatSignedValue(_transposeSteps),
      semanticsLabel: _transposeStatusLabel,
      onIncrement: () => _updateTranspose(1),
      onDecrement: () => _updateTranspose(-1),
      canIncrement: _transposeSteps < _maxTranspose,
      canDecrement: _transposeSteps > _minTranspose,
      extraContent: extraContent,
    );
  }

  Widget _buildAdjustmentFlyout({
    required bool isDarkMode,
    required bool isOpen,
    required VoidCallback onToggle,
    required Widget icon,
    required String displayValue,
    String? semanticsLabel,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    bool canIncrement = true,
    bool canDecrement = true,
    Widget? extraContent,
    bool isActive = false,
  }) {
    final backgroundColor = isDarkMode
        ? const Color(0xFF0A0A0A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accent =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

    return SizedBox(
      width: 220,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isOpen ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isOpen,
                child: Container(
                  width: 148,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.0),
                    boxShadow: _buildFloatingShadows(isDarkMode),
                  ),
                  child: Row(
                    children: [
                      _buildInlineAdjustmentControl(
                        label: '- ',
                        onPressed: onDecrement,
                        enabled: canDecrement,
                        accentColor: accent,
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            // Absorb taps on the display value to prevent propagation
                          },
                          child: Center(
                            child: Semantics(
                              label: semanticsLabel ?? displayValue,
                              child: Text(
                                displayValue,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildInlineAdjustmentControl(
                        label: ' +',
                        onPressed: onIncrement,
                        enabled: canIncrement,
                        accentColor: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (extraContent != null)
            Positioned(
              right: 52,
              top: 48,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isOpen ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !isOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Absorb taps to prevent propagation to parent
                    },
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1.0),
                        boxShadow: _buildFloatingShadows(isDarkMode),
                      ),
                      child: extraContent,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.blue.withValues(alpha: 0.8)
                      : (isDarkMode
                          ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? Colors.blue : borderColor,
                    width: 1.0,
                  ),
                  boxShadow: _buildFloatingShadows(isDarkMode),
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildAdjustmentScopeToggle(bool isDarkMode) {
    // Remove duplicate "Apply to setlist entry" toggle - this is already handled in Add/Edit Setlist dialog
    return null;
  }

  Widget _buildInlineAdjustmentControl({
    required String label,
    required VoidCallback onPressed,
    required bool enabled,
    required Color accentColor,
  }) {
    final color = enabled ? accentColor : accentColor.withValues(alpha: 0.35);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: SizedBox(
        width: 32,
        height: 40,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
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

  Widget _buildSongMetadata(Color textColor) {
    // Check if we have any metadata to display
    final keyLabel = _getKeyDisplayLabel();
    final hasBpm = _currentSong.bpm > 0;
    final hasTimeSignature = _currentSong.timeSignature.isNotEmpty;
    final showCapoBadge = _currentCapo > 0;
    final hasArtist = _currentSong.artist.isNotEmpty;
    final tags = _currentSong.tags;
    final hasTags = tags.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Title and Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentSong.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  if (hasArtist) ...[
                    const SizedBox(height: 2),
                    Text(
                      _currentSong.artist,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Right side: Key, Tempo, Capo summary text
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (keyLabel != null)
                  Text(
                    keyLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                if (hasBpm || hasTimeSignature) ...[
                  if (keyLabel != null) const SizedBox(height: 2),
                  Text(
                    '${hasBpm ? '${_currentSong.bpm} bpm' : ''}${hasBpm && hasTimeSignature ? ' ' : ''}${hasTimeSignature ? _currentSong.timeSignature : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (showCapoBadge) ...[
                  if (keyLabel != null || hasBpm || hasTimeSignature)
                    const SizedBox(height: 2),
                  Text(
                    'CAPO $_currentCapo',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ViewerTagWrap(
          tags: tags,
          hasTags: hasTags,
          textColor: textColor,
          onRemove: _removeTag,
          onEdit: _openTagsDialog,
          getTagColors: (tag) => _getTagColors(tag, context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMetronomeButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    const glowColor = Color(0xFF00D9FF);

    return Consumer<MetronomeProvider>(
      builder: (context, metronome, _) {
        final isActive = metronome.isRunning;
        final accent = isDarkMode ? glowColor : const Color(0xFF0468cc);
        final backgroundColor = isActive
            ? accent.withValues(alpha: 0.15)
            : isDarkMode
                ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.9);

        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? accent
                  : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400),
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: isDarkMode
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
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: metronome.toggle,
              customBorder: const CircleBorder(),
              child: Center(
                child: CustomPaint(
                  size: const Size(16, 16),
                  painter: MetronomeIconPainter(
                    color: accent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetronomeFlashOverlay extends StatelessWidget {
  const _MetronomeFlashOverlay();

  @override
  Widget build(BuildContext context) {
    return Selector<MetronomeProvider, bool>(
      selector: (_, provider) => provider.flashActive,
      builder: (context, isFlashing, _) {
        return IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 80),
            opacity: isFlashing ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _sidebarTopColor.withValues(alpha: 0.5),
                  width: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for capo icon (fretboard with horizontal lines)
class CapoIconPainter extends CustomPainter {
  final Color color;

  CapoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines (strings) - 4 strings
    final stringSpacing = size.width / 5;
    for (int i = 1; i <= 4; i++) {
      final x = stringSpacing * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines (frets) - 3 frets
    final fretSpacing = size.height / 4;
    for (int i = 1; i <= 3; i++) {
      final y = fretSpacing * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw capo bar at top (thicker horizontal line)
    final capoPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(stringSpacing, 1),
      Offset(size.width - stringSpacing, 1),
      capoPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for metronome icon (triangle with tick marks)
class MetronomeIconPainter extends CustomPainter {
  final Color color;

  MetronomeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;

    // Draw triangle (metronome shape)
    final path = Path();
    path.moveTo(size.width * 0.5, 0); // Top point
    path.lineTo(size.width * 0.9, size.height); // Bottom right
    path.lineTo(size.width * 0.1, size.height); // Bottom left
    path.close();

    canvas.drawPath(path, paint);

    // Draw tick marks
    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Center vertical tick
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.7),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
