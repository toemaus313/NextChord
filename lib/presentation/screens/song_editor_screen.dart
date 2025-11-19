import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/chordpro_parser.dart';
import '../../services/import/ultimate_guitar_import_service.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
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
    'B'
  ];

  static const List<String> _timeSignatures = ['4/4', '3/4', '6/8'];

  @override
  void initState() {
    super.initState();
    _initializeFields();
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

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _bodyController.dispose();
    _bpmController.dispose();
    _durationController.dispose();
    super.dispose();
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
        final durationRegex = RegExp(r'\{duration:[^}]*\}', caseSensitive: false);
        if (durationRegex.hasMatch(updatedBody)) {
          // Update existing duration
          updatedBody = updatedBody.replaceFirst(durationRegex, '{duration:$duration}');
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

      if (widget.song != null) {
        // Update existing song - use provider to ensure UI updates
        final provider = context.read<SongProvider>();
        await provider.updateSong(song);
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
        final provider = context.read<SongProvider>();
        await provider.addSong(song);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song created successfully'),
              backgroundColor: Colors.green,
            ),
          );
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

  /// Import a ChordPro file and auto-populate fields
  Future<void> _importChordProFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pro', 'cho', 'crd', 'chopro', 'chordpro', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        // Parse metadata from ChordPro file
        final metadata = ChordProParser.extractMetadata(content);
        
        setState(() {
          // Populate form fields from metadata
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
          if (metadata.time != null && _timeSignatures.contains(metadata.time)) {
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
              content: Text('Imported: ${result.files.single.name}'),
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
        Navigator.pop(context);
      }

      if (result.success) {
        // Populate form fields
        setState(() {
          _titleController.text = result.title ?? '';
          _artistController.text = result.artist ?? '';
          _bodyController.text = result.chordProContent ?? '';
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
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final actionColor = isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);

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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    value: _selectedKey,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.piano, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    items: _keys.map((key) {
                      return DropdownMenuItem(
                        value: key,
                        child: Text(key, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedKey = value;
                        });
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
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      hintText: '120',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    value: _selectedCapo,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CustomPaint(
                          size: const Size(18, 18),
                          painter: CapoIconPainter(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    items: List.generate(13, (index) => index).map((capo) {
                      return DropdownMenuItem(
                        value: capo,
                        child: Text(capo.toString(), style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCapo = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Time Signature dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedTimeSignature,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.timer, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    items: _timeSignatures.map((sig) {
                      return DropdownMenuItem(
                        value: sig,
                        child: Text(sig, style: const TextStyle(fontSize: 13)),
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
                      hintText: '3:45',
                      hintStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }
                      final pattern = RegExp(r'^(\d{1,2}:)?\d{1,2}:\d{2}$');
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

            // Tags section - single row
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    'Tags:',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tags.isNotEmpty
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _tags.asMap().entries.map((entry) {
                                final index = entry.key;
                                final tag = entry.value;
                                final (bgColor, tagTextColor) = _getTagColors(tag, context);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _TagChip(
                                    key: ValueKey('tag_$index\_$tag'),
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
                              }).toList(),
                            ),
                          )
                        : Text(
                            'No tags',
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: _openTagsDialog,
                    tooltip: 'Edit tags',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc),
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
                        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: '[C]Amazing [G]grace, how [Am]sweet the [F]sound\n[C]That saved a [G]wretch like [C]me',
                          hintStyle: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.3)),
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
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
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
                  tooltip: 'Import ChordPro File',
                  onPressed: _importChordProFile,
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
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(actionColor),
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
