import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/midi_profile.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../widgets/tag_edit_dialog.dart';
import '../widgets/song_editor/song_editor_header.dart';
import '../widgets/song_editor/song_metadata_form.dart';
import '../widgets/song_editor/midi_profile_selector.dart';
import '../widgets/song_editor/tag_editor.dart';
import '../../services/song_editor/song_import_service.dart';
import '../../services/song_editor/transposition_service.dart';
import '../../services/song_editor/tab_auto_completion_service.dart';
import '../../services/song_editor/song_persistence_service.dart';

/// Screen for creating or editing a song - Refactored version
class SongEditorScreenRefactored extends StatefulWidget {
  final Song? song; // If null, create new song; if provided, edit existing
  final SetlistSongItem? setlistContext; // Setlist context for adjustments

  const SongEditorScreenRefactored({super.key, this.song, this.setlistContext});

  @override
  State<SongEditorScreenRefactored> createState() =>
      _SongEditorScreenRefactoredState();
}

class _SongEditorScreenRefactoredState
    extends State<SongEditorScreenRefactored> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bpmController = TextEditingController();
  final _durationController = TextEditingController();
  final FocusNode _bodyFocusNode = FocusNode();

  String _selectedKey = 'C';
  int _selectedCapo = 0;
  String _selectedTimeSignature = '4/4';
  List<String> _tags = [];
  bool _isSaving = false;
  String _lastBodyText = '';
  bool _isAutoCompleting = false;

  // MIDI Profile state
  List<MidiProfile> _midiProfiles = [];
  MidiProfile? _selectedMidiProfile;
  bool _isLoadingProfiles = false;

  // Local keyboard toggle state to avoid timing issues
  bool _isMetadataHidden = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadMidiProfiles();
    _bodyController.addListener(_onBodyTextChanged);
    _bodyFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// Load MIDI profiles for dropdown
  Future<void> _loadMidiProfiles() async {
    setState(() => _isLoadingProfiles = true);
    try {
      final songProvider = context.read<SongProvider>();
      final profiles = await SongPersistenceService.loadMidiProfiles(
        repository: songProvider.repository,
      );
      if (mounted) {
        setState(() {
          _midiProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading MIDI profiles: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Initialize form fields with existing song data if editing
  void _initializeFields() async {
    if (widget.song != null) {
      final song = widget.song!;
      _titleController.text = song.title;
      _artistController.text = song.artist;
      _bodyController.text = song.body;
      _bpmController.text = song.bpm.toString();

      // Load MIDI profile for song
      try {
        final songProvider = context.read<SongProvider>();
        _selectedMidiProfile = await SongPersistenceService.loadSongMidiProfile(
          songId: song.id,
          repository: songProvider.repository,
        );
      } catch (e) {
        _selectedMidiProfile = null;
      }

      // Apply setlist context adjustments if available
      if (widget.setlistContext != null) {
        // Start with base song key and apply transpose
        _selectedKey = song.key;
        if (widget.setlistContext!.transposeSteps != null &&
            widget.setlistContext!.transposeSteps != 0 &&
            song.key.isNotEmpty) {
          _selectedKey = TranspositionService.transposeChord(
              song.key, widget.setlistContext!.transposeSteps!);
        }

        // Use setlist capo if set, otherwise use song capo
        _selectedCapo = widget.setlistContext!.capo ?? song.capo;
      } else {
        // No setlist context - use base song values
        _selectedKey = song.key;
        _selectedCapo = song.capo;
      }

      _selectedTimeSignature = song.timeSignature;
      _tags = List.from(song.tags);

      // Extract duration from ChordPro metadata if available
      final metadata = SongImportService.extractMetadata(song.body);
      if (metadata.duration != null) {
        _durationController.text = metadata.duration!;
      }
    } else {
      // Default values for new song
      _bpmController.text = '120';
    }
  }

  void _handleKeySelection(String newKey) {
    if (newKey == _selectedKey) return;
    final diff =
        TranspositionService.calculateKeyDifference(_selectedKey, newKey);
    if (diff != null && diff != 0) {
      _transposeBody(diff);
    }
    setState(() {
      _selectedKey = newKey;
    });
  }

  void _handleCapoSelection(int newCapo) {
    if (newCapo == _selectedCapo) return;
    final diff = TranspositionService.calculateCapoTransposeDifference(
        _selectedCapo, newCapo);
    if (diff != 0) {
      _transposeBody(diff);
    }
    setState(() {
      _selectedCapo = newCapo;
    });
  }

  void _handleTimeSignatureChanged(String newTimeSignature) {
    setState(() {
      _selectedTimeSignature = newTimeSignature;
    });
  }

  void _handleTagsChanged(List<String> newTags) {
    setState(() {
      _tags = newTags;
    });
  }

  /// Handle keyboard toggle to match iOS Hide Keyboard button behavior
  void _handleKeyboardToggle() {
    final hasHardwareKb =
        _bodyFocusNode.hasFocus && MediaQuery.viewInsetsOf(context).bottom == 0;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (isKeyboardVisible) {
      // iOS behavior: if keyboard is visible, dismiss it (metadata will auto-show)
      _bodyFocusNode.unfocus();
      setState(() {
        _isMetadataHidden =
            false; // Ensure metadata shows when keyboard is dismissed
      });
    } else {
      // No keyboard visible - toggle metadata manually
      setState(() {
        _isMetadataHidden = !_isMetadataHidden;

        // If hiding metadata and no hardware keyboard, show keyboard
        if (_isMetadataHidden && !hasHardwareKb) {
          // Use postFrameCallback to avoid timing issues
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _bodyFocusNode.requestFocus();
            }
          });
        }
      });
    }
  }

  void _handleMidiProfileChanged(MidiProfile? newProfile) {
    setState(() {
      _selectedMidiProfile = newProfile;
    });
  }

  void _transposeBody(int semitones) {
    if (semitones == 0) return;
    final currentText = _bodyController.text;
    if (currentText.trim().isEmpty) return;

    final selection = _bodyController.selection;
    final updatedText =
        TranspositionService.transposeChordProText(currentText, semitones);
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

  @override
  void dispose() {
    _bodyController.removeListener(_onBodyTextChanged);
    _bodyFocusNode.dispose();
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
    final cursorPos = _bodyController.selection.baseOffset;

    // Check for auto-completion
    final result = TabAutoCompletionService.checkForAutoCompletion(
      currentText,
      _lastBodyText,
      cursorPos,
    );

    if (result != null) {
      _isAutoCompleting = true;
      _bodyController.text = result.updatedText;
      _lastBodyText = result.updatedText;
      _bodyController.selection = TextSelection.fromPosition(
        TextPosition(offset: result.newCursorPosition),
      );
      _isAutoCompleting = false;
    } else {
      _lastBodyText = currentText;
    }
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
      String updatedBody = SongPersistenceService.updateBodyWithDuration(
        _bodyController.text.trim(),
        _durationController.text.trim(),
      );

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
      SongPersistenceResult result;

      if (widget.song != null) {
        // Update existing song
        result = await SongPersistenceService.updateSong(
          song: song,
          midiProfileId: _selectedMidiProfile?.id,
          repository: songProvider.repository,
        );

        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new song
        result = await SongPersistenceService.saveSong(
          song: song,
          midiProfileId: _selectedMidiProfile?.id,
          repository: songProvider.repository,
        );

        if (result.success && result.song != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Song created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<GlobalSidebarProvider>().navigateToSong(result.song!);
          }
        }
      }

      if (!result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Unknown error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (result.success && mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
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
    final result = await SongImportService.importFromFile();

    if (result != null && result.success && mounted) {
      setState(() {
        if (result.title != null) {
          _titleController.text = result.title!;
        }
        if (result.artist != null) {
          _artistController.text = result.artist!;
        }
        if (result.key != null &&
            TranspositionService.getAvailableKeys().contains(result.key)) {
          _selectedKey = result.key!;
        }
        if (result.capo != null) {
          _selectedCapo = result.capo!;
        }
        if (result.tempo != null) {
          final tempo = int.tryParse(result.tempo!);
          if (tempo != null) {
            _bpmController.text = tempo.toString();
          }
        }
        if (result.timeSignature != null &&
            ['4/4', '3/4', '6/8', '2/4'].contains(result.timeSignature)) {
          _selectedTimeSignature = result.timeSignature!;
        }
        if (result.duration != null) {
          _durationController.text = result.duration!;
        }

        // Set the body content
        _bodyController.text = result.body!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Imported: ${result.fileName ?? 'File'}'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result != null && !result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Import failed'),
          backgroundColor: Colors.red,
        ),
      );
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

    final result = SongImportService.convertToChordPro(currentText);

    if (result.success && mounted) {
      setState(() {
        // Populate metadata fields
        if (result.title != null && _titleController.text.isEmpty) {
          _titleController.text = result.title!;
        }
        if (result.artist != null && _artistController.text.isEmpty) {
          _artistController.text = result.artist!;
        }
        if (result.key != null &&
            TranspositionService.getAvailableKeys().contains(result.key)) {
          _selectedKey = result.key!;
        }
        if (result.capo != null) {
          _selectedCapo = result.capo!;
        }
        if (result.tempo != null) {
          final tempo = int.tryParse(result.tempo!);
          if (tempo != null) {
            _bpmController.text = tempo.toString();
          }
        }
        if (result.timeSignature != null &&
            ['4/4', '3/4', '6/8', '2/4'].contains(result.timeSignature)) {
          _selectedTimeSignature = result.timeSignature!;
        }

        // Replace the body with converted content
        _bodyController.text = result.body!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Converted to ChordPro'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Conversion failed'),
          backgroundColor: Colors.red,
        ),
      );
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

    final result = await SongImportService.importFromUltimateGuitar(url);

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (result.success && mounted) {
      // Populate fields with imported data
      setState(() {
        _titleController.text = result.title ?? '';
        _artistController.text = result.artist ?? '';
        _bodyController.text = result.body ?? '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported: ${result.title ?? 'Song'}'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (!result.success && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Failed'),
          content: Text(result.error ?? 'Unknown error'),
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

  /// Delete the current song
  Future<void> _deleteSong() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text(
          'Are you sure you want to delete "${_titleController.text}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final songProvider = context.read<SongProvider>();
      final result = await SongPersistenceService.deleteSong(
        songId: widget.song!.id,
        repository: songProvider.repository,
      );

      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song deleted successfully'),
          ),
        );
        // Refresh the song list in the provider
        await songProvider.loadSongs();
        // Return a special value to indicate deletion occurred
        if (mounted) {
          Navigator.of(context).pop('deleted');
        }
      } else if (!result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Delete failed'),
            backgroundColor: Colors.red,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.song != null;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final actionColor =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hideMetadata = _isMetadataHidden || isKeyboardOpen;

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
                  // Setlist mode indicator banner
                  if (widget.setlistContext != null && !hideMetadata)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.05),
                        border: Border(
                          bottom: BorderSide(
                            color: isDarkMode
                                ? Colors.blue.withValues(alpha: 0.3)
                                : Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_play,
                            size: 16,
                            color: isDarkMode
                                ? Colors.blue.shade300
                                : Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Setlist Mode: Adjusted key and capo are displayed',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Scrollable metadata section
                  if (!hideMetadata)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          16.0,
                          widget.setlistContext != null ? 16.0 : 60.0,
                          16.0,
                          16.0),
                      child: Column(
                        children: [
                          // Metadata form
                          SongMetadataForm(
                            titleController: _titleController,
                            artistController: _artistController,
                            bpmController: _bpmController,
                            durationController: _durationController,
                            selectedKey: _selectedKey,
                            selectedCapo: _selectedCapo,
                            selectedTimeSignature: _selectedTimeSignature,
                            textColor: textColor,
                            isDarkMode: isDarkMode,
                            hasSetlistContext: widget.setlistContext != null,
                            onKeyChanged: _handleKeySelection,
                            onCapoChanged: _handleCapoSelection,
                            onTimeSignatureChanged: _handleTimeSignatureChanged,
                          ),
                          const SizedBox(height: 12),

                          // MIDI Sends and Tags in the same row
                          Row(
                            children: [
                              // MIDI Sends section - left half
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade400,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: MidiProfileSelector(
                                    selectedProfile: _selectedMidiProfile,
                                    onProfileChanged: _handleMidiProfileChanged,
                                    profiles: _midiProfiles,
                                    isLoading: _isLoadingProfiles,
                                    onProfilesReloaded: _loadMidiProfiles,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Tags section - right half
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade400,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: TagEditor(
                                    tags: _tags,
                                    textColor: textColor,
                                    isDarkMode: isDarkMode,
                                    onTagsChanged: _handleTagsChanged,
                                    onEditTags: _openTagsDialog,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  // Body (ChordPro text) field - borderless editing area
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextFormField(
                        controller: _bodyController,
                        focusNode: _bodyFocusNode,
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

            // Header with action buttons
            SongEditorHeader(
              title: isEditing ? 'Edit Song' : 'Create Song',
              isEditing: isEditing,
              isSaving: _isSaving,
              textColor: textColor,
              actionColor: actionColor,
              isDarkMode: isDarkMode,
              onBackPressed: () => Navigator.of(context).pop(),
              onSavePressed: _saveSong,
              onDeletePressed: _deleteSong,
              onConvertPressed: _convertToChordPro,
              onImportFromUltimateGuitarPressed: _importFromUltimateGuitar,
              onImportFromFilePressed: _importFromFile,
              onToggleMetadata: _handleKeyboardToggle,
              isMetadataHidden: _isMetadataHidden,
            ),
          ],
        ),
      ),
    );
  }
}
