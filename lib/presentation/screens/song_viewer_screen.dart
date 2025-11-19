import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/chordpro_parser.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../widgets/chord_renderer.dart';
import '../widgets/tag_edit_dialog.dart';
import 'song_editor_screen.dart';

/// Full-screen song viewer for live performance
/// Displays lyrics/chords with adjustable font size and theme toggle
class SongViewerScreen extends StatefulWidget {
  final Song song;
  final VoidCallback? onSongEdit;

  const SongViewerScreen({
    Key? key,
    required this.song,
    this.onSongEdit,
  }) : super(key: key);

  @override
  State<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends State<SongViewerScreen> {
  double _fontSize = 18.0;
  double _baseFontSize = 18.0; // Font size at the start of pinch gesture
  bool _showControls = true;
  int _transposeSteps = 0; // Semitones to transpose
  late Song _currentSong; // Mutable song that can be refreshed
  bool _showSettingsFlyout = false; // Compact settings flyout visibility

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;
    // Enable landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
      return true;
    }
    // Song was deleted
    return false;
  }

  /// Extract duration from song metadata
  String? _getDuration() {
    final metadata = ChordProParser.extractMetadata(_currentSong.body);
    return metadata.duration;
  }

  /// Get color for a tag based on whether it's an instrument tag
  (Color, Color) _getTagColors(String tag, BuildContext context) {
    const instrumentTags = {'Acoustic', 'Electric', 'Piano', 'Guitar', 'Bass', 'Drums', 'Vocals', 'Instrumental'};
    
    if (instrumentTags.contains(tag)) {
      return (Colors.orange.withValues(alpha: 0.2), Colors.orange);
    } else {
      return (Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.onPrimaryContainer);
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

  @override
  void dispose() {
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
            onTap: () {
              // Toggle controls visibility
              setState(() {
                _showControls = !_showControls;
              });
            },
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
              Column(
                children: [
                  // Header with song info
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showControls ? null : 0,
                    child: _showControls ? _buildHeader(textColor) : null,
                  ),

                  // Scrollable song body
                  Expanded(
                    child: SingleChildScrollView(
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
                            transposeSteps: _transposeSteps,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Back button (always visible)
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
                right: 56,
                child: IconButton(
                  icon: Icon(
                    Icons.share,
                    color: isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc),
                    size: 28,
                  ),
                  onPressed: () {
                    // TODO: Implement share
                  },
                  tooltip: 'Share song',
                ),
              ),

              // Edit button (always visible)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc),
                    size: 28,
                  ),
                  onPressed: () async {
                    // Notify home screen that song is being edited
                    widget.onSongEdit?.call();
                    
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SongEditorScreen(song: _currentSong),
                      ),
                    );
                    
                    // Handle the return from editor
                    if (mounted) {
                      if (result == 'deleted') {
                        // Song was deleted - clear it from global state
                        if (context.mounted) {
                          context.read<GlobalSidebarProvider>().clearCurrentSong();
                        }
                      } else if (result == true) {
                        // Song was updated, reload it
                        final reloaded = await _reloadSong();
                        if (!reloaded && context.mounted) {
                          // Song was deleted while editing, clear it
                          context.read<GlobalSidebarProvider>().clearCurrentSong();
                        } else if (context.mounted) {
                          // Update the song in global state with the reloaded version
                          context.read<GlobalSidebarProvider>().navigateToSong(_currentSong);
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
                    SizedBox(
                      width: 96, // Fixed width to prevent shifting
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: _showSettingsFlyout ? 1.0 : 0.0),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        builder: (context, wrapperValue, child) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              // Absorb taps to prevent propagation to parent
                            },
                            child: SizedBox(
                              width: 96,
                              height: 40,
                            child: Stack(
                              alignment: Alignment.centerRight,
                              clipBehavior: Clip.none,
                              children: [
                          // Expanding container (positioned to grow left)
                          Positioned(
                            right: 0,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: _showSettingsFlyout ? 1.0 : 0.0),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                // Calculate width based on expansion - starts at 40 (circular), expands by 56 for second button
                                final expandedWidth = 40.0 + (value * 56.0);
                                
                                return Container(
                                  width: expandedWidth,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDarkMode 
                                        ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                                        : Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                                      width: 1.0,
                                    ),
                                    boxShadow: isDarkMode ? [
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
                                    ] : [
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        // Theme toggle button (fades in/out) - positioned on left
                                        if (value > 0.3) // Start showing when 30% expanded
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            child: Center(
                                              child: Opacity(
                                                opacity: ((value - 0.3) / 0.7).clamp(0.0, 1.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    // Prevent tap from propagating to parent
                                                  },
                                                  child: Builder(
                                                    builder: (btnContext) => _buildInnerButton(
                                                      icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                                      tooltip: 'Toggle Theme',
                                                      onPressed: () {
                                                        btnContext.read<ThemeProvider>().toggleTheme();
                                                      },
                                                      isDarkMode: isDarkMode,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Settings icon button - fixed position from right
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: 40,
                                          child: Center(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _showSettingsFlyout = !_showSettingsFlyout;
                                                  });
                                                },
                                                customBorder: const CircleBorder(),
                                                child: SizedBox(
                                                  width: 40,
                                                  height: 40,
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.settings,
                                                      color: isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc),
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 96, // Fixed width to prevent shifting
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildTransposeButton(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 96, // Fixed width to prevent shifting
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildCapoButton(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 96, // Fixed width to prevent shifting
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildFloatingButton(
                          icon: Icons.play_arrow,
                          tooltip: 'AutoScroll',
                          onPressed: () {
                            // TODO: Implement autoscroll
                          },
                        ),
                      ),
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
        child: Text(
          _currentSong.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
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
                ? Colors.grey.shade700.withValues(alpha: 0.3) // Very faint border
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

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    const glowColor = Color(0xFF00D9FF); // Bright cyan
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7) // Semi-transparent dark interior
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1.0, // Thinner border
        ),
        boxShadow: isDarkMode ? [
          // Main shadow for elevation
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          // Secondary shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          // Subtle top highlight for raised effect
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ] : [
          // Main shadow for elevation
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          // Secondary shadow for depth
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: isDarkMode ? glowColor : const Color(0xFF0468cc),
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildCapoButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    const glowColor = Color(0xFF00D9FF);
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1.0,
        ),
        boxShadow: isDarkMode ? [
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
        ] : [
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
          onTap: () {
            // TODO: Implement capo
          },
          customBorder: const CircleBorder(),
          child: Center(
            child: CustomPaint(
              size: const Size(18, 18),
              painter: CapoIconPainter(
                color: isDarkMode ? glowColor : const Color(0xFF0468cc),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransposeButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    const glowColor = Color(0xFF00D9FF); // Bright cyan
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1.0,
        ),
        boxShadow: isDarkMode ? [
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
        ] : [
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
          onTap: () {
            // TODO: Implement transpose
          },
          customBorder: const CircleBorder(),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '−',
                  style: TextStyle(
                    color: isDarkMode ? glowColor : const Color(0xFF0468cc),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 1),
                Icon(
                  Icons.music_note,
                  color: isDarkMode ? glowColor : const Color(0xFF0468cc),
                  size: 14,
                ),
                const SizedBox(width: 1),
                Text(
                  '+',
                  style: TextStyle(
                    color: isDarkMode ? glowColor : const Color(0xFF0468cc),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongMetadata(Color textColor) {
    // Check if we have any metadata to display
    final hasKey = _currentSong.key.isNotEmpty;
    final hasBpm = _currentSong.bpm > 0;
    final hasTimeSignature = _currentSong.timeSignature.isNotEmpty;
    final hasCapo = _currentSong.capo > 0;
    final hasArtist = _currentSong.artist.isNotEmpty;

    return Row(
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
        // Right side: Key, Tempo, Capo
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasKey)
              Text(
                'Key of ${_currentSong.key}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            if (hasBpm || hasTimeSignature) ...[
              if (hasKey) const SizedBox(height: 2),
              Text(
                '${hasBpm ? '${_currentSong.bpm} bpm' : ''}${hasBpm && hasTimeSignature ? ' ' : ''}${hasTimeSignature ? _currentSong.timeSignature : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (hasCapo) ...[
              if (hasKey || hasBpm || hasTimeSignature) const SizedBox(height: 2),
              Text(
                'CAPO ${_currentSong.capo}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color textColor) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, Color textColor) {
    final (bgColor, tagTextColor) = _getTagColors(tag, context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tagTextColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: tagTextColor,
        ),
      ),
    );
  }

  Widget _buildEditTagsButton(Color textColor) {
    return GestureDetector(
      onTap: _openTagsDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.5),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 14,
              color: Colors.grey,
            ),
            SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(Color textColor) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Font size slider
          Row(
            children: [
              Icon(Icons.text_fields, color: textColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 32.0,
                  divisions: 20,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                  },
                ),
              ),
              Text(
                '${_fontSize.round()}',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Transpose controls
          Row(
            children: [
              Icon(Icons.music_note, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transpose:',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _transposeSteps--;
                  });
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: textColor,
                tooltip: 'Transpose down',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _transposeSteps == 0
                      ? '0'
                      : '${_transposeSteps > 0 ? '+' : ''}$_transposeSteps',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _transposeSteps++;
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
                color: textColor,
                tooltip: 'Transpose up',
              ),
              if (_transposeSteps != 0)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _transposeSteps = 0;
                    });
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(color: textColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Theme toggle and other controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Dark mode toggle
              ElevatedButton.icon(
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                label: Text(isDarkMode ? 'Light' : 'Dark'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  foregroundColor: textColor,
                ),
              ),
              // Future: Auto-scroll button
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement auto-scroll
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Auto-scroll coming soon!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Auto-scroll'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: textColor.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetronomeButton() {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    const glowColor = Color(0xFF00D9FF);
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          width: 1.0,
        ),
        boxShadow: isDarkMode ? [
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
        ] : [
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
          onTap: () {
            // TODO: Implement metronome
          },
          customBorder: const CircleBorder(),
          child: Center(
            child: CustomPaint(
              size: const Size(16, 16),
              painter: MetronomeIconPainter(
                color: isDarkMode ? glowColor : const Color(0xFF0468cc),
              ),
            ),
          ),
        ),
      ),
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
