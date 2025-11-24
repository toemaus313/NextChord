import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/setlist.dart';
import '../../domain/entities/midi_profile.dart';
import '../providers/song_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/global_sidebar_provider.dart';
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
        if (widget.setlistContext!.transposeSteps != 0 && song.key.isNotEmpty) {
          _selectedKey = TranspositionService.transposeChord(
              song.key, widget.setlistContext!.transposeSteps);
        }

        // Use setlist capo if set, otherwise use song capo
        _selectedCapo = widget.setlistContext!.capo;
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
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (isKeyboardVisible) {
      // iOS behavior: if keyboard is visible, dismiss it (metadata will auto-show)
      _bodyFocusNode.unfocus();
      setState(() {
        _isMetadataHidden =
            false; // Ensure metadata shows when keyboard is dismissed
      });
    } else {
      // iOS behavior: if keyboard is not visible but body has focus, show keyboard
      if (_bodyFocusNode.hasFocus) {
        // Toggle metadata visibility when body has focus but no keyboard
        setState(() {
          _isMetadataHidden = !_isMetadataHidden;
        });
      } else {
        // Request focus to show keyboard
        _bodyFocusNode.requestFocus();
      }
    }
  }

  void _onBodyTextChanged() {
    final currentText = _bodyController.text;
    final cursorPosition = _bodyController.selection.baseOffset;

    // Check if we should trigger auto-completion
    if (cursorPosition > _lastBodyText.length) {
      // User added text, check for tab completion trigger
      if (currentText.endsWith('\t') && !_isAutoCompleting) {
        _isAutoCompleting = true;
        _handleTabCompletion();
      }
    }

    _lastBodyText = currentText;
  }

  /// Handle tab completion for chord patterns
  void _handleTabCompletion() async {
    final cursorPosition = _bodyController.selection.baseOffset;
    if (cursorPosition <= 0) return;

    // Get the text before the tab
    final textBeforeTab = _bodyController.text.substring(0, cursorPosition - 1);

    // Use the tab auto-completion service
    final result = TabAutoCompletionService.checkForAutoCompletion(
      textBeforeTab + '\t',
      textBeforeTab,
      cursorPosition,
    );

    if (result != null && mounted) {
      // Apply the auto-completion result
      _bodyController.value = TextEditingValue(
        text: result.updatedText,
        selection: TextSelection.collapsed(offset: result.newCursorPosition),
      );

      // Reset auto-completion flag after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isAutoCompleting = false;
          });
        }
      });
    } else {
      // No completion found, just remove the tab
      _bodyController.value = TextEditingValue(
        text: textBeforeTab,
        selection: TextSelection.collapsed(offset: textBeforeTab.length),
      );
      setState(() {
        _isAutoCompleting = false;
      });
    }
  }

  /// Transpose the entire body by the specified number of steps
  void _transposeBody(int steps) {
    final transposedBody =
        TranspositionService.transposeChordProText(_bodyController.text, steps);
    _bodyController.text = transposedBody;
  }

  Future<void> _saveSong() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final updatedBody = _bodyController.text.trim();

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
          _bpmController.text = result.tempo!;
        }
        if (result.timeSignature != null) {
          _selectedTimeSignature = result.timeSignature!;
        }
        if (result.duration != null) {
          _durationController.text = result.duration!;
        }
        if (result.body != null) {
          _bodyController.text = result.body!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song imported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to import song'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importFromUltimateGuitar() async {
    // For now, show a placeholder - this would need a URL input dialog
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ultimate Guitar import requires URL - feature coming soon'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _convertToChordPro() {
    // This would convert plain text to ChordPro format
    // Implementation would depend on specific requirements
  }

  Future<void> _deleteSong() async {
    if (widget.song == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text(
            'Are you sure you want to delete "${widget.song!.title}"? This action cannot be undone.'),
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

    if (confirmed == true && mounted) {
      try {
        final songProvider = context.read<SongProvider>();
        await songProvider.deleteSong(widget.song!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
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
  }

  void _handleMidiProfileChanged(MidiProfile? profile) {
    setState(() {
      _selectedMidiProfile = profile;
    });
  }

  void _openTagsDialog() {
    // TODO: Implement tag editing dialog
    // For now, this is a placeholder to avoid compilation errors
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _bodyController.dispose();
    _bpmController.dispose();
    _durationController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
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
