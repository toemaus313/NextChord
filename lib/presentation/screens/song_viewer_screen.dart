import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/chordpro_parser.dart';
import '../providers/theme_provider.dart';
import '../widgets/chord_renderer.dart';
import 'song_editor_screen.dart';

/// Full-screen song viewer for live performance
/// Displays lyrics/chords with adjustable font size and theme toggle
class SongViewerScreen extends StatefulWidget {
  final Song song;
  final bool Function()? shouldHideSidebar;
  final VoidCallback? onSongEdit;

  const SongViewerScreen({
    Key? key,
    required this.song,
    this.shouldHideSidebar,
    this.onSongEdit,
  }) : super(key: key);

  @override
  State<SongViewerScreen> createState() => _SongViewerScreenState();
}

class _SongViewerScreenState extends State<SongViewerScreen> {
  double _fontSize = 18.0;
  bool _showControls = true;
  int _transposeSteps = 0; // Semitones to transpose
  late Song _currentSong; // Mutable song that can be refreshed

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
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // If sidebar check callback is provided, check if sidebar should be hidden
            if (widget.shouldHideSidebar != null) {
              final sidebarWasHidden = widget.shouldHideSidebar!();
              if (sidebarWasHidden) {
                // Sidebar was hidden, don't toggle controls
                return;
              }
            }
            // Otherwise, toggle controls visibility
            setState(() {
              _showControls = !_showControls;
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
                      child: ChordRenderer(
                        chordProText: _currentSong.body,
                        fontSize: _fontSize,
                        isDarkMode: isDarkMode,
                        transposeSteps: _transposeSteps,
                      ),
                    ),
                  ),

                  // Controls at bottom
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showControls ? null : 0,
                    child: _showControls ? _buildControls(textColor) : null,
                  ),
                ],
              ),

              // Back button (always visible)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: textColor,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              // Edit button (always visible)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: textColor,
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
                        // Song was deleted - pop all the way back to home screen
                        // with special value to indicate deletion
                        Navigator.of(context).pop('deleted');
                      } else if (result == true) {
                        // Song was updated, reload it
                        await _reloadSong();
                        // Also notify the library screen that data changed
                        Navigator.of(context).pop(true);
                      } else {
                        // Editor was closed without saving, just pop back
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  tooltip: 'Edit song',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      width: double.infinity, // Ensure full width
      padding: const EdgeInsets.fromLTRB(60, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _currentSong.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          // Artist
          Text(
            _currentSong.artist,
            style: TextStyle(
              fontSize: 18,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          // Key, Capo, BPM, Duration info
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Key: ${_currentSong.key}', textColor),
              if (_currentSong.capo > 0)
                _buildInfoChip('Capo: ${_currentSong.capo}', textColor),
              _buildInfoChip('${_currentSong.bpm} BPM', textColor),
              if (_getDuration() != null)
                _buildInfoChip('${_getDuration()}', textColor),
              if (_transposeSteps != 0)
                _buildInfoChip(
                  'Transpose: ${_transposeSteps > 0 ? '+' : ''}$_transposeSteps',
                  textColor,
                ),
              // Tags
              if (_currentSong.tags.isNotEmpty) ...[
                for (final tag in _currentSong.tags.take(3)) // Show max 3 tags
                  _buildTagChip(tag, textColor),
                if (_currentSong.tags.length > 3)
                  _buildInfoChip('+${_currentSong.tags.length - 3} more', textColor),
              ],
            ],
          ),
        ],
      ),
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
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blue.shade800 : Colors.blue.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800,
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
}
