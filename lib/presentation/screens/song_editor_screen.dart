import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/utils/chordpro_parser.dart';

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
  final _tagInputController = TextEditingController();

  String _selectedKey = 'C';
  int _selectedCapo = 0;
  String _selectedTimeSignature = '4/4';
  List<String> _tags = [];
  String? _audioFilePath;
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
      _audioFilePath = song.audioFilePath;
      
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
    _tagInputController.dispose();
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
      final repository = context.read<SongRepository>();
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
        audioFilePath: _audioFilePath,
        notes: widget.song?.notes,
        createdAt: widget.song?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.song != null) {
        // Update existing song
        await repository.updateSong(song);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new song
        await repository.insertSong(song);
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

  /// Pick an audio file
  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _audioFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Add a tag to the list
  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagInputController.clear();
      });
    }
  }

  /// Remove a tag from the list
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.song != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Song' : 'Create Song'),
        actions: [
          // Import ChordPro file button
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.file_upload),
              onPressed: _importChordProFile,
              tooltip: 'Import ChordPro File',
            ),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSong,
              tooltip: 'Save',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter song title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.music_note),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Artist field
            TextFormField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: 'Artist',
                hintText: 'Enter artist name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Artist is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Key and Capo row
            Row(
              children: [
                // Key dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedKey,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.piano),
                    ),
                    items: _keys.map((key) {
                      return DropdownMenuItem(
                        value: key,
                        child: Text(key),
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
                const SizedBox(width: 16),

                // Capo spinner
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedCapo,
                    decoration: const InputDecoration(
                      labelText: 'Capo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: List.generate(13, (index) => index).map((capo) {
                      return DropdownMenuItem(
                        value: capo,
                        child: Text(capo.toString()),
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
              ],
            ),
            const SizedBox(height: 16),

            // BPM and Time Signature row
            Row(
              children: [
                // BPM field
                Expanded(
                  child: TextFormField(
                    controller: _bpmController,
                    decoration: const InputDecoration(
                      labelText: 'BPM',
                      hintText: '120',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'BPM is required';
                      }
                      final bpm = int.tryParse(value.trim());
                      if (bpm == null || bpm < 1 || bpm > 300) {
                        return 'Enter valid BPM (1-300)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Time Signature dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTimeSignature,
                    decoration: const InputDecoration(
                      labelText: 'Time Signature',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    items: _timeSignatures.map((sig) {
                      return DropdownMenuItem(
                        value: sig,
                        child: Text(sig),
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
              ],
            ),
            const SizedBox(height: 16),

            // Duration field
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (optional)',
                hintText: '3:45 or 1:30:15',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
                helperText: 'Format: MM:SS or HH:MM:SS',
              ),
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null; // Duration is optional
                }
                // Validate format: MM:SS or HH:MM:SS
                final pattern = RegExp(r'^(\d{1,2}:)?\d{1,2}:\d{2}$');
                if (!pattern.hasMatch(value.trim())) {
                  return 'Use format MM:SS or HH:MM:SS';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tags section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagInputController,
                            decoration: const InputDecoration(
                              hintText: 'Add a tag',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                          tooltip: 'Add tag',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeTag(tag),
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        'No tags added',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Body (ChordPro text) field
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Lyrics & Chords (ChordPro)',
                hintText:
                    'Enter song lyrics with chords...\n\n[C]Amazing [G]grace, how [Am]sweet the [F]sound',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 12,
              minLines: 6,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Song body is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Audio file picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio File (Optional)',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_audioFilePath != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.audiotrack, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _audioFilePath!.split('/').last,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _audioFilePath = null;
                              });
                            },
                            tooltip: 'Remove file',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.folder_open),
                      label: Text(_audioFilePath != null
                          ? 'Change Audio File'
                          : 'Pick Audio File'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveSong,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving
                  ? 'Saving...'
                  : (isEditing ? 'Update Song' : 'Create Song')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
