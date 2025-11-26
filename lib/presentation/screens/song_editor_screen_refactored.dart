import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import '../../services/import/content_type_detector.dart';
import '../../services/import/share_import_service.dart';
import '../../services/song_metadata_service.dart';
import '../../core/utils/ug_text_converter.dart';

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
  final ScrollController _scrollController = ScrollController();
  final SongMetadataService _metadataService = SongMetadataService();

  String _selectedKey = 'C';
  int _selectedCapo = 0;
  String _selectedTimeSignature = '4/4';
  List<String> _tags = [];
  bool _isSaving = false;
  String _lastBodyText = '';
  bool _isAutoCompleting = false;

  // Text sizing state for editor
  double _editorFontSize = 14.0;
  double _baseScaleFontSize = 14.0; // Track base font size for pinch gestures
  static const double _minEditorFontSize = 8.0;
  static const double _maxEditorFontSize = 32.0;
  static const double _scrollZoomSensitivity = 0.05;

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
      if (mounted) {}
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _bodyController.dispose();
    _bpmController.dispose();
    _durationController.dispose();
    _bodyFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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

  /// Test method to verify SongBPM API works
  Future<void> _testSongMetadataAPI() async {
    // Check if title and artist are provided
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();

    if (title.isEmpty || artist.isEmpty) {
      _showRetrieveInfoDialog(
        title: 'Missing Information',
        content:
            'Please enter both a song title and artist name before retrieving song information.',
        showRetry: false,
      );
      return;
    }

    // Show progress dialog
    _showRetrieveInfoDialog(
      title: 'Retrieving Song Info',
      content:
          'Searching for song information...\n\nThis can take up to 60 seconds.\nPlease wait.',
      showRetry: false,
      isLoading: true,
    );

    try {
      final result = await _metadataService.fetchMetadata(
        title: title,
        artist: artist,
      );

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      // Check if ALL required metadata fields are present
      final hasAllFields = result.success &&
          result.tempoBpm != null &&
          result.key != null &&
          result.timeSignature != null &&
          result.durationMs != null;

      if (hasAllFields) {
        // Auto-populate the form fields with retrieved data
        setState(() {
          if (result.correctedTitle != null &&
              result.correctedTitle!.isNotEmpty) {
            _titleController.text = result.correctedTitle!;
          }
          if (result.correctedArtist != null &&
              result.correctedArtist!.isNotEmpty) {
            _artistController.text = result.correctedArtist!;
          }
          _bpmController.text = result.tempoBpm.toString();
          _selectedKey = result.key!;
          _selectedTimeSignature = result.timeSignature!;

          // Format duration as MM:SS
          final formattedDuration =
              SongMetadataLookupResult.formatDuration(result.durationMs);
          if (formattedDuration != null) {
            _durationController.text = formattedDuration;
          }
        });

        _showRetrieveInfoDialog(
          title: '✅ Song Information Found',
          content: 'Successfully retrieved complete metadata:\n\n'
              '🎵 Tempo: ${result.tempoBpm} BPM\n'
              '🎹 Key: ${result.key}\n'
              '⏱️ Time Signature: ${result.timeSignature}\n'
              '⏳ Duration: ${SongMetadataLookupResult.formatDuration(result.durationMs)}\n\n'
              'Form fields have been updated automatically.\n'
              'Title and artist have been corrected to match the database.',
          showRetry: false,
        );
      } else {
        // Handle partial success or no results
        final missingFields = <String>[];
        if (result.tempoBpm == null) missingFields.add('tempo');
        if (result.key == null) missingFields.add('key');
        if (result.timeSignature == null) missingFields.add('time signature');
        if (result.durationMs == null) missingFields.add('duration');

        if (result.error != null) {
          // Check if this is likely a spelling error
          final isLikelySpellingError =
              result.error!.contains('No matches found') ||
                  result.error!.contains('check spelling');

          if (isLikelySpellingError) {
            _showRetrieveInfoDialog(
              title: '🔍 Song Not Found',
              content: '${result.error}\n\n'
                  'Tips for finding songs:\n'
                  '• Use the official song title (not remixes or live versions)\n'
                  '• Check artist name spelling exactly\n'
                  '• Try shorter versions of the title\n'
                  '• Some new/obscure songs may not be in our database yet',
              showRetry: true,
            );
          } else {
            _showRetrieveInfoDialog(
              title: '❌ Retrieval Error',
              content:
                  'Failed to retrieve song information:\n\n${result.error}\n\n'
                  'Please check:\n'
                  '• Song title and artist are spelled correctly\n'
                  '• Internet connection is active\n'
                  '• Try again in a few moments',
              showRetry: true,
            );
          }
        } else if (missingFields.isNotEmpty) {
          _showRetrieveInfoDialog(
            title: '⚠️ Incomplete Information',
            content: 'Found some information but missing:\n\n'
                '${missingFields.map((field) => '• $field').join('\n')}\n\n'
                'Available data has been applied to the form.\n'
                'Missing fields will need to be filled manually.',
            showRetry: true,
          );
        } else {
          _showRetrieveInfoDialog(
            title: '🔍 No Information Found',
            content: 'No song information found for:\n\n'
                'Title: $title\n'
                'Artist: $artist\n\n'
                'Suggestions:\n'
                '• Check spelling of title and artist\n'
                '• Try using the original song title\n'
                '• Some songs may not be in the database',
            showRetry: true,
          );
        }
      }
    } catch (e) {
      // Close progress dialog if still showing
      if (mounted) Navigator.of(context).pop();

      _showRetrieveInfoDialog(
        title: '❌ Network Error',
        content: 'Failed to connect to song information service:\n\n$e\n\n'
            'Please check your internet connection and try again.',
        showRetry: true,
      );
    }
  }

  /// Show retrieve dialog with status and retry options
  void _showRetrieveInfoDialog({
    required String title,
    required String content,
    bool showRetry = true,
    bool isLoading = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => !isLoading,
          child: AlertDialog(
            title: Row(
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 12),
                Expanded(child: Text(title)),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(content),
            ),
            actions: [
              if (!isLoading && showRetry)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _testSongMetadataAPI();
                  },
                  child: const Text('Retry'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

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
      '$textBeforeTab\t',
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
    final formValid = _formKey.currentState!.validate();
    if (!formValid) {
      return;
    }

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

      // Check if ID is empty to decide between insert and update
      // Imported songs have empty ID even though widget.song != null
      if (song.id.isNotEmpty) {
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
        // Create new song (including imported songs with empty ID)
        result = await SongPersistenceService.saveSong(
          song: song,
          midiProfileId: _selectedMidiProfile?.id,
          repository: songProvider.repository,
        );

        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.read<GlobalSidebarProvider>().navigateToSong(result.song!);
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
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

  Future<void> _importFromFile() async {
    // For now, show a placeholder - this would need file picker implementation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File import feature coming soon'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _convertToChordPro() {
    final currentText = _bodyController.text;
    if (currentText.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text to convert'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Detect content type
    final isTab = ContentTypeDetector.isTabContent(currentText);

    String convertedText;
    String conversionType;

    try {
      if (isTab) {
        // Convert tab content using ShareImportService
        final shareImportService = ShareImportService();
        convertedText = shareImportService
            .convertUltimateGuitarTabExportToChordPro(currentText);
        conversionType = 'tab';
      } else {
        // Convert chord content using UGTextConverter
        final result = UGTextConverter.convertToChordPro(currentText);
        convertedText = result['chordpro'] as String;
        conversionType = 'chord';
      }

      // Update the body controller with converted text
      _bodyController.text = convertedText;

      // Show success message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Detected $conversionType format and converted to ChordPro'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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

  /// Update editor font size with clamping
  void _updateEditorFontSize(double newSize) {
    setState(() {
      _editorFontSize = newSize.clamp(_minEditorFontSize, _maxEditorFontSize);
    });
  }

  /// Handle pinch to zoom gesture in editor
  void _handlePinchToZoom(ScaleUpdateDetails details) {
    final newSize = _baseScaleFontSize * details.scale;
    _updateEditorFontSize(newSize);
  }

  /// Handle scale start for pinch gesture in editor
  void _handleScaleStart() {
    _baseScaleFontSize = _editorFontSize;
  }

  /// Handle scroll wheel zoom with Shift/Ctrl in editor
  void _handleScrollWheelZoom(PointerScrollEvent event) {
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

    if (isShiftPressed || isCtrlPressed) {
      final delta = event.scrollDelta.dy;
      // Scroll down = negative delta = increase font size
      // Scroll up = positive delta = decrease font size
      final fontSizeChange = -delta * _scrollZoomSensitivity;
      final newSize = _editorFontSize + fontSizeChange;
      _updateEditorFontSize(newSize);
    }
  }

  /// Check if text sizing gestures should be handled in editor
  bool _shouldHandleTextSizingGesture() {
    // Allow text sizing in editor unless a dialog is showing
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.song != null;
    final themeProvider = context.read<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final actionColor =
        isDarkMode ? const Color(0xFF00D9FF) : const Color(0xFF0468cc);
    final hideMetadata = _isMetadataHidden;

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
                          Column(
                            children: [
                              // Debug API test button
                              ElevatedButton(
                                onPressed: _testSongMetadataAPI,
                                child: const Text('Retrieve Song Info'),
                              ),
                              const SizedBox(height: 8),
                              // Actual metadata form
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
                                hasSetlistContext:
                                    widget.setlistContext != null,
                                onKeyChanged: _handleKeySelection,
                                onCapoChanged: _handleCapoSelection,
                                onTimeSignatureChanged:
                                    _handleTimeSignatureChanged,
                              ),
                            ],
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
                      child: Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent &&
                              _shouldHandleTextSizingGesture()) {
                            _handleScrollWheelZoom(event);
                          }
                        },
                        child: GestureDetector(
                          onScaleStart: (_) =>
                              _handleScaleStart(), // Track base font size
                          onScaleUpdate: (details) {
                            if (_shouldHandleTextSizingGesture()) {
                              _handlePinchToZoom(details);
                            }
                          },
                          child: TextFormField(
                            controller: _bodyController,
                            focusNode: _bodyFocusNode,
                            style: TextStyle(
                                fontSize: _editorFontSize,
                                fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText:
                                  '[C]Amazing [G]grace, how [Am]sweet the [F]sound\n[C]That saved a [G]wretch like [C]me',
                              hintStyle: TextStyle(
                                  fontSize: _editorFontSize - 1,
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
