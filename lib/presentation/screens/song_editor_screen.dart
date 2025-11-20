import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/constants/music_constants.dart';
import '../../core/utils/chordpro_parser.dart';
import '../../core/utils/ug_text_converter.dart';
import '../../services/import/ultimate_guitar_import_service.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../widgets/tag_edit_dialog.dart';

/// Screen for creating or editing a song
class SongEditorScreen extends StatefulWidget {
  final Song? song; // If null, create new song; if provided, edit existing

  const SongEditorScreen({super.key, this.song});

  @override
  State<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends State<SongEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bpmController = TextEditingController();
  final _durationController = TextEditingController();

  String _selectedKey = 'C';
  int _selectedCapo = 0;
  String _selectedTimeSignature = '4/4';
  List<String> _tags = [];
  bool _isSaving = false;
  String _lastBodyText = '';
  bool _isAutoCompleting = false;

  // Available options
  static const List<String> _keys = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
    'Cm',
    'C#m',
    'Dm',
    'D#m',
    'Em',
    'Fm',
    'F#m',
    'Gm',
    'G#m',
    'Am',
    'A#m',
    'Bm'
  ];

  static const List<String> _timeSignatures = ['4/4', '3/4', '6/8', '2/4'];
  static const Map<String, String> _flatToSharpMap = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
  };

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _bodyController.addListener(_onBodyTextChanged);
  }

  String _ensureDirectiveValue(String body, String directive, String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return body;

    final regex = RegExp('\\{$directive:[^}]*\\}', caseSensitive: false);
    if (regex.hasMatch(body)) {
      return body.replaceFirst(
          regex, '{${directive.toLowerCase()}:$trimmedValue}');
    }

    final lines = body.split('\n');
    int insertIndex = 0;
    while (insertIndex < lines.length &&
        lines[insertIndex].trim().startsWith('{')) {
      insertIndex++;
    }
    lines.insert(insertIndex, '{${directive.toLowerCase()}:$trimmedValue}');
    return lines.join('\n');
  }

  /// Initialize form fields with existing song data if editing
  void _initializeFields() {
    if (widget.song != null) {
      final song = widget.song!;
      _titleController.text = song.title;
      _artistController.text = song.artist;
      _bodyController.text = song.body;
      _bpmController.text = song.bpm.toString();
      _selectedKey = song.key;
      _selectedCapo = song.capo;
      _selectedTimeSignature = song.timeSignature;
      _tags = List.from(song.tags);

      // Extract duration from ChordPro metadata if available
      final metadata = ChordProParser.extractMetadata(song.body);
      if (metadata.duration != null) {
        _durationController.text = metadata.duration!;
      }
    } else {
      // Default values for new song
      _bpmController.text = '120';
    }
  }

  int? _keyToSemitone(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^([A-Ga-g])([#b]?)(.*)$').firstMatch(trimmed);
    if (match == null) return null;

    final rootLetter = match.group(1)!.toUpperCase();
    final accidental = match.group(2) ?? '';
    String root = '$rootLetter$accidental';
    root = _flatToSharpMap[root] ?? root;

    return MusicConstants.chromaticScale.indexOf(root);
  }

  int? _calculateKeyDifference(String fromKey, String toKey) {
    final fromIndex = _keyToSemitone(fromKey);
    final toIndex = _keyToSemitone(toKey);
    if (fromIndex == null || toIndex == null) return null;

    int diff = toIndex - fromIndex;
    if (diff.abs() > 6) {
      diff += diff > 0 ? -12 : 12;
    }
    return diff;
  }

  void _transposeBody(int semitones) {
    if (semitones == 0) return;
    final currentText = _bodyController.text;
    if (currentText.trim().isEmpty) return;

    final selection = _bodyController.selection;
    final updatedText =
        ChordProParser.transposeChordProText(currentText, semitones);
    _bodyController.text = updatedText;

    int baseOffset = selection.baseOffset;
    if (!selection.isValid) {
      baseOffset = updatedText.length;
    } else {
      baseOffset = baseOffset.clamp(0, updatedText.length);
    }
    _bodyController.selection = TextSelection.collapsed(offset: baseOffset);
    _lastBodyText = updatedText;
  }

  void _handleKeySelection(String newKey) {
    if (newKey == _selectedKey) return;
    final diff = _calculateKeyDifference(_selectedKey, newKey);
    if (diff != null && diff != 0) {
      _transposeBody(diff);
    }
    setState(() {
      _selectedKey = newKey;
    });
  }

  void _handleCapoSelection(int newCapo) {
    if (newCapo == _selectedCapo) return;
    final diff = _selectedCapo - newCapo;
    if (diff != 0) {
      _transposeBody(diff);
    }
    setState(() {
      _selectedCapo = newCapo;
    });
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onBodyTextChanged);
    _titleController.dispose();
    _artistController.dispose();
    _bodyController.dispose();
    _bpmController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  /// Handle body text changes to auto-complete tab sections
  void _onBodyTextChanged() {
    // Avoid recursive calls during auto-completion
    if (_isAutoCompleting) return;

    final currentText = _bodyController.text;

    // Only process if text actually changed
    if (currentText == _lastBodyText) {
      return;
    }

    // Check if user just completed typing {sot}
    // We detect this by checking if the text ends with {sot} at the cursor position
    if (currentText.length > _lastBodyText.length) {
      final cursorPos = _bodyController.selection.baseOffset;

      // Check if we just typed the closing } of {sot}
      if (cursorPos >= 5) {
        final beforeCursor = currentText.substring(0, cursorPos);
        if (beforeCursor.endsWith('{sot}')) {
          // Check if there's already a matching {eot} after this position
          final hasMatchingEot = _hasMatchingEot(currentText, cursorPos);

          if (!hasMatchingEot) {
            _insertEotAfterSot(cursorPos);
          }
        }
      }
    }

    _lastBodyText = currentText;
  }

  /// Check if there's a matching {eot} for the {sot} at the given position
  bool _hasMatchingEot(String text, int sotEndPos) {
    // Look ahead for {eot} within reasonable distance (50 lines)
    final afterSot = text.substring(sotEndPos);
    final lines = afterSot.split('\n');

    // Check up to 50 lines ahead
    final linesToCheck = lines.take(50).join('\n');
    return linesToCheck.toLowerCase().contains('{eot}');
  }

  /// Insert {eot} immediately after {sot} is typed
  /// If tab content already exists, place {eot} at the end of it
  /// Otherwise, insert {eot} with space for typing
  void _insertEotAfterSot(int sotEndPos) {
    _isAutoCompleting = true;

    try {
      final currentText = _bodyController.text;
      final before = currentText.substring(0, sotEndPos);
      final after = currentText.substring(sotEndPos);

      // Split the text after {sot} into lines
      final afterLines = after.split('\n');

      // Check if there's tab content in the next few lines
      int tabEndLineIndex = -1;
      bool foundTab = false;
      int emptyLineCount = 0;

      for (int i = 0; i < afterLines.length && i < 20; i++) {
        final line = afterLines[i].trim();

        // Count empty lines before finding first tab
        if (!foundTab && line.isEmpty) {
          emptyLineCount++;
          // If more than 2 empty lines before any tab, give up
          if (emptyLineCount > 2) {
            break;
          }
          continue;
        }

        // Check if this line looks like tab
        if (_looksLikeTabLine(line)) {
          if (!foundTab) {
            foundTab = true;
          }
          tabEndLineIndex = i;
          emptyLineCount = 0; // Reset empty line counter
        } else if (foundTab && line.isNotEmpty) {
          // Found non-tab content after tab, stop here
          break;
        } else if (foundTab && line.isEmpty) {
          // Count empty lines within tab block
          emptyLineCount++;
          // If more than 2 empty lines within tab block, stop
          if (emptyLineCount > 2) {
            break;
          }
        }
      }

      String newText;
      int newCursorPos;

      if (foundTab && tabEndLineIndex >= 0) {
        // Tab content exists - insert {eot} after the last tab line
        final beforeTab = afterLines.sublist(0, tabEndLineIndex + 1).join('\n');
        final afterTab = afterLines.sublist(tabEndLineIndex + 1).join('\n');

        newText = '$before$beforeTab\n{eot}$afterTab';
        // Keep cursor at current position (after {sot})
        newCursorPos = sotEndPos;
      } else {
        // No tab content yet - insert {eot} with space for typing
        newText = '$before\n\n{eot}$after';
        // Position cursor right after {sot} and the newline, ready to type tab
        newCursorPos = sotEndPos + 1;
      }

      _bodyController.text = newText;
      _lastBodyText = newText;

      _bodyController.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursorPos),
      );
    } finally {
      _isAutoCompleting = false;
    }
  }

  /// Check if a line looks like guitar tablature
  bool _looksLikeTabLine(String line) {
    if (line.isEmpty) return false;

    // Check for standard guitar string notation (E|, A|, D|, G|, B|, e|)
    final tabLineRegex = RegExp(r'^[EADGBe]\|[\-0-9|]+', caseSensitive: true);
    if (tabLineRegex.hasMatch(line)) return true;

    // Also check for lines that are mostly dashes, numbers, and pipes
    final tabChars = RegExp(r'[\-0-9|]');
    final nonSpaceChars = line.replaceAll(' ', '');
    if (nonSpaceChars.length < 3) return false;

    final tabCharCount = tabChars.allMatches(nonSpaceChars).length;
    return tabCharCount / nonSpaceChars.length > 0.5;
  }

  /// Validate and save the song
  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();

      // Update ChordPro body with duration if provided
      String updatedBody = _bodyController.text.trim();
      final duration = _durationController.text.trim();

      if (duration.isNotEmpty) {
        // Check if duration directive already exists
        final durationRegex =
            RegExp(r'\{duration:[^}]*\}', caseSensitive: false);
        if (durationRegex.hasMatch(updatedBody)) {
          // Update existing duration
          updatedBody =
              updatedBody.replaceFirst(durationRegex, '{duration:$duration}');
        } else {
          // Add duration directive at the beginning (after title/artist if present)
          final lines = updatedBody.split('\n');
          int insertIndex = 0;

          // Find position after title/artist/key directives
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].trim().startsWith('{') &&
                (lines[i].contains('title:') ||
                    lines[i].contains('artist:') ||
                    lines[i].contains('subtitle:') ||
                    lines[i].contains('key:'))) {
              insertIndex = i + 1;
            } else if (!lines[i].trim().startsWith('{')) {
              break;
            }
          }

          lines.insert(insertIndex, '{duration:$duration}');
          updatedBody = lines.join('\n');
        }
      }

      final song = Song(
        id: widget.song?.id ?? '',
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        body: updatedBody,
        key: _selectedKey,
        capo: _selectedCapo,
        bpm: int.parse(_bpmController.text.trim()),
        timeSignature: _selectedTimeSignature,
        tags: _tags,
        audioFilePath: null,
        notes: widget.song?.notes,
        createdAt: widget.song?.createdAt ?? now,
        updatedAt: now,
      );

      final songProvider = context.read<SongProvider>();
      Song savedSong = song;

      if (widget.song != null) {
        // Update existing song - use provider to ensure UI updates
        await songProvider.updateSong(song);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new song - use provider to ensure UI updates
        final newSongId = await songProvider.addSong(song);
        savedSong = song.copyWith(id: newSongId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.read<GlobalSidebarProvider>().navigateToSong(savedSong);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving song: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Import from ChordPro file and auto-populate fields
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pro', 'cho', 'crd', 'chopro', 'chordpro', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // Parse as ChordPro text file
        final file = File(filePath);
        final content = await file.readAsString();

        // Extract metadata from ChordPro
        final metadata = ChordProParser.extractMetadata(content);

        // Update UI with initial metadata
        setState(() {
          if (metadata.title != null) {
            _titleController.text = metadata.title!;
          }
          if (metadata.artist != null) {
            _artistController.text = metadata.artist!;
          }
          if (metadata.key != null && _keys.contains(metadata.key)) {
            _selectedKey = metadata.key!;
          }
          if (metadata.capo != null) {
            _selectedCapo = metadata.capo!;
          }
          if (metadata.tempo != null) {
            final tempo = int.tryParse(metadata.tempo!);
            if (tempo != null) {
              _bpmController.text = tempo.toString();
            }
          }
          if (metadata.time != null &&
              _timeSignatures.contains(metadata.time)) {
            _selectedTimeSignature = metadata.time!;
          }
          if (metadata.duration != null) {
            _durationController.text = metadata.duration!;
          }

          // Set the body content
          _bodyController.text = content;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Imported: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Convert pasted Ultimate Guitar text to ChordPro format
  Future<void> _convertToChordPro() async {
    final currentText = _bodyController.text.trim();

    if (currentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste some Ultimate Guitar text first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Convert the text
      final result = UGTextConverter.convertToChordPro(currentText);
      final chordProContent = result['chordpro'] as String;
      final metadata = result['metadata'] as Map<String, String>;

      setState(() {
        // Populate metadata fields
        if (metadata['title'] != null && _titleController.text.isEmpty) {
          _titleController.text = metadata['title']!;
        }
        if (metadata['artist'] != null && _artistController.text.isEmpty) {
          _artistController.text = metadata['artist']!;
        }
        if (metadata['key'] != null && _keys.contains(metadata['key'])) {
          _selectedKey = metadata['key']!;
        }
        if (metadata['capo'] != null) {
          final capo = int.tryParse(metadata['capo']!);
          if (capo != null) {
            _selectedCapo = capo;
          }
        }
        if (metadata['bpm'] != null) {
          final tempo = int.tryParse(metadata['bpm']!);
          if (tempo != null) {
            _bpmController.text = tempo.toString();
          }
        }
        if (metadata['timeSignature'] != null &&
            _timeSignatures.contains(metadata['timeSignature'])) {
          _selectedTimeSignature = metadata['timeSignature']!;
        }

        // Replace the body with converted content
        _bodyController.text = chordProContent;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Converted to ChordPro'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting text: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Import from Ultimate Guitar URL
  Future<void> _importFromUltimateGuitar() async {
    final urlController = TextEditingController();

    // Show dialog to get URL
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from Ultimate Guitar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the Ultimate Guitar tab URL:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Example:\nhttps://tabs.ultimate-guitar.com/tab/artist/song-chords-123456',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'Paste URL here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              autofocus: true,
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context, url);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Importing from Ultimate Guitar...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final importService = UltimateGuitarImportService();
      final result = await importService.importFromUrl(url);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        // Populate fields with imported data
        setState(() {
          _titleController.text = result.title!;
          _artistController.text = result.artist!;
          _bodyController.text = result.chordProContent!;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported: ${result.title}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Import Failed'),
              content: Text(result.errorMessage ?? 'Unknown error'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to import: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
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
    await showDialog(
      context: context,
      builder: (context) => TagEditDialog(
        title: 'Edit Tags',
        initialTags: _tags.toSet(),
        onTagsUpdated: (updatedTags) {
          setState(() {
            _tags = updatedTags;
          });
        },
      ),
    );
  }

  /// Delete the current song
  Future<void> _deleteSong() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text(
          'Are you sure you want to delete "${_titleController.text}"?\n\nThis action cannot be undone.',
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

    if (confirmed != true) return;

    try {
      final repository = context.read<SongRepository>();
      await repository.deleteSong(widget.song!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song deleted successfully'),
          ),
        );
        // Refresh the song list in the provider
        if (context.mounted) {
          await context.read<SongProvider>().loadSongs();
        }
        // Return a special value to indicate deletion occurred
        if (mounted) {
          Navigator.of(context).pop('deleted');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.song != null;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final actionColor =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Scrollable metadata section
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16.0, 60.0, 16.0, 0),
                    child: Column(
                      children: [
                        // Title field
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            labelStyle: TextStyle(fontSize: 13),
                            hintText: 'Enter song title',
                            hintStyle: TextStyle(fontSize: 13),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.music_note, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Artist field
                        TextFormField(
                          controller: _artistController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Artist',
                            labelStyle: TextStyle(fontSize: 13),
                            hintText: 'Enter artist name',
                            hintStyle: TextStyle(fontSize: 13),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Artist is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Single row with Key, BPM, Capo, Time Signature, Duration
                        Row(
                          children: [
                            // Key dropdown
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedKey,
                                style:
                                    TextStyle(fontSize: 14, color: textColor),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.piano, size: 18),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                items: _keys.map((key) {
                                  return DropdownMenuItem(
                                    value: key,
                                    child: Text(key,
                                        style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    _handleKeySelection(value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // BPM field
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _bpmController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: CustomPaint(
                                      size: const Size(18, 18),
                                      painter: MetronomeIconPainter(
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  hintText: '120',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final bpm = int.tryParse(value.trim());
                                  if (bpm == null || bpm < 1 || bpm > 300) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Capo dropdown
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedCapo,
                                style:
                                    TextStyle(fontSize: 14, color: textColor),
                                decoration: InputDecoration(
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: CustomPaint(
                                      size: const Size(18, 18),
                                      painter: CapoIconPainter(
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                items: List.generate(13, (index) => index)
                                    .map((capo) {
                                  return DropdownMenuItem(
                                    value: capo,
                                    child: Text(capo.toString(),
                                        style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    _handleCapoSelection(value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Time Signature dropdown
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedTimeSignature,
                                style:
                                    TextStyle(fontSize: 14, color: textColor),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.timer, size: 18),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                items: _timeSignatures.map((sig) {
                                  return DropdownMenuItem(
                                    value: sig,
                                    child: Text(sig,
                                        style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedTimeSignature = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Duration field
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _durationController,
                                style: const TextStyle(fontSize: 14),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.play_arrow, size: 18),
                                  hintText: '3:00',
                                  hintStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  final pattern =
                                      RegExp(r'^(\d{1,2}:)?\d{1,2}:\d{2}$');
                                  if (!pattern.hasMatch(value.trim())) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Tags row matching viewer behavior
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Wrap(
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
                              if (_tags.isNotEmpty)
                                ..._tags.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final tag = entry.value;
                                  final (bgColor, tagTextColor) =
                                      _getTagColors(tag, context);
                                  return DragTarget<int>(
                                    onWillAccept: (dragIndex) =>
                                        dragIndex != index,
                                    onAccept: (dragIndex) {
                                      setState(() {
                                        final tagToMove =
                                            _tags.removeAt(dragIndex);
                                        _tags.insert(index, tagToMove);
                                      });
                                    },
                                    builder: (context, candidate, rejected) {
                                      return Draggable<int>(
                                        data: index,
                                        feedback: Opacity(
                                          opacity: 0.7,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: _TagChip(
                                              key: ValueKey('drag_tag_$tag'),
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
                                            key: ValueKey(
                                                'tag_drag_${index}_$tag'),
                                            tag: tag,
                                            bgColor: bgColor,
                                            textColor: tagTextColor,
                                            onRemove: () {
                                              setState(() {
                                                _tags.removeAt(index);
                                              });
                                            },
                                          ),
                                        ),
                                        child: _TagChip(
                                          key: ValueKey('tag_${index}_$tag'),
                                          tag: tag,
                                          bgColor: bgColor,
                                          textColor: tagTextColor,
                                          onRemove: () {
                                            setState(() {
                                              _tags.removeAt(index);
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  );
                                })
                              else
                                Text(
                                  'No tags yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              GestureDetector(
                                onTap: _openTagsDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color:
                                            textColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit,
                                          size: 14,
                                          color:
                                              textColor.withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Edit',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: textColor.withValues(
                                                alpha: 0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  // Body (ChordPro text) field - borderless editing area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        controller: _bodyController,
                        style: const TextStyle(
                            fontSize: 14, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText:
                              '[C]Amazing [G]grace, how [Am]sweet the [F]sound\n[C]That saved a [G]wretch like [C]me',
                          hintStyle: TextStyle(
                              fontSize: 13,
                              color: textColor.withValues(alpha: 0.3)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Song body is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header with title
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                color: backgroundColor,
                child: Center(
                  child: Text(
                    isEditing ? 'Edit Song' : 'Create Song',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),

            // Back button (top left)
            Positioned(
              top: 8,
              left: 8,
              child: _buildActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                color: textColor,
                isDarkMode: isDarkMode,
              ),
            ),

            // Convert button available in both create & edit modes
            Positioned(
              top: 8,
              right: 152,
              child: _buildActionButton(
                icon: Icons.auto_fix_high,
                tooltip: 'Convert to ChordPro',
                onPressed: _convertToChordPro,
                color: actionColor,
                isDarkMode: isDarkMode,
              ),
            ),

            // Delete button (top right, only when editing)
            if (isEditing)
              Positioned(
                top: 8,
                right: 56,
                child: _buildActionButton(
                  icon: Icons.delete,
                  tooltip: 'Delete Song',
                  onPressed: _deleteSong,
                  color: Colors.red,
                  isDarkMode: isDarkMode,
                ),
              ),

            // Import buttons (top right, only when creating)
            if (!isEditing) ...[
              Positioned(
                top: 8,
                right: 104,
                child: _buildActionButton(
                  icon: Icons.cloud_download,
                  tooltip: 'Import from Ultimate Guitar',
                  onPressed: _importFromUltimateGuitar,
                  color: actionColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              Positioned(
                top: 8,
                right: 56,
                child: _buildActionButton(
                  icon: Icons.file_upload,
                  tooltip: 'Import from File',
                  onPressed: _importFromFile,
                  color: actionColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],

            // Save button (top right)
            Positioned(
              top: 8,
              right: 8,
              child: _isSaving
                  ? Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                          width: 1.0,
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
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(actionColor),
                          ),
                        ),
                      ),
                    )
                  : _buildActionButton(
                      icon: Icons.save,
                      tooltip: 'Save',
                      onPressed: _saveSong,
                      color: actionColor,
                      isDarkMode: isDarkMode,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
    required bool isDarkMode,
  }) {
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
      child: IconButton(
        icon: Icon(icon),
        color: color,
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

/// Custom widget for displaying a tag chip with remove button
class _TagChip extends StatelessWidget {
  final String tag;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onRemove;

  const _TagChip({
    super.key,
    required this.tag,
    required this.bgColor,
    required this.textColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom reorderable wrap widget for drag-and-drop tag reordering
class ReorderableWrap extends StatefulWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final Function(int oldIndex, int newIndex) onReorder;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.spacing,
    required this.runSpacing,
    required this.onReorder,
  });

  @override
  State<ReorderableWrap> createState() => _ReorderableWrapState();
}

class _ReorderableWrapState extends State<ReorderableWrap> {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            return details.data != index;
          },
          onAcceptWithDetails: (details) {
            widget.onReorder(details.data, index);
          },
          builder: (context, candidateData, rejectedData) {
            final isHovered = candidateData.isNotEmpty;
            return Draggable<int>(
              data: index,
              feedback: Opacity(
                opacity: 0.7,
                child: Material(
                  color: Colors.transparent,
                  child: child,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: child,
              ),
              child: Container(
                decoration: isHovered
                    ? BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                child: child,
              ),
            );
          },
        );
      }).toList(),
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
