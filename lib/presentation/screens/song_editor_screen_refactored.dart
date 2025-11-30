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
import '../widgets/song_editor/title_only_confirmation_dialog.dart';
import '../controllers/song_editor/song_editor_controller.dart';
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
  final SongEditorController? controller;

  const SongEditorScreenRefactored({
    super.key,
    this.song,
    this.setlistContext,
    this.controller,
  });

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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _bodyFocusNode = FocusNode();

  late final SongEditorController _controller;

  // Flag to prevent showing confirmation dialog multiple times
  bool _isShowingConfirmationDialog = false;

  String _selectedKey = 'C';
  int _selectedCapo = 0;
  String _selectedTimeSignature = '4/4';
  List<String> _tags = [];
  bool _isAutoTransposeEnabled = true;
  bool _isSaving = false;
  String _lastBodyText = '';
  bool _isAutoCompleting = false;
  bool _isImportingFromUrl = false;
  String? _lastImportedUrl;

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
    // Initialize controller - use provided one or create new one
    _controller = widget.controller ?? SongEditorController(song: widget.song);

    final mode = widget.song == null ? 'create' : 'edit';
    final hasSetlistContext = widget.setlistContext != null;

    _initializeFields();
    _loadMidiProfiles();
    _bodyController.addListener(_onBodyTextChanged);
    _bodyFocusNode.addListener(() {
      if (mounted) {}
    });

    // Listen for pending confirmation state
    _controller.addListener(_handleControllerStateChange);
  }

  @override
  void dispose() {
    // Remove listeners before disposing
    _bodyController.removeListener(_onBodyTextChanged);
    // Dispose FocusNode FIRST before controllers
    _bodyFocusNode.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _bodyController.dispose();
    _bpmController.dispose();
    _durationController.dispose();
    _scrollController.dispose();
    _controller.removeListener(_handleControllerStateChange);
    // Only dispose controller if we created it internally
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// Handle controller state changes for pending confirmation
  void _handleControllerStateChange() {
    if (_controller.onlineMetadataStatus ==
            OnlineMetadataStatus.pendingConfirmation &&
        !_isShowingConfirmationDialog) {
      final pendingResult = _controller.pendingTitleOnlyResult;
      if (pendingResult != null && mounted) {
        _isShowingConfirmationDialog = true;
        _showTitleOnlyConfirmationDialog(pendingResult).then((_) {
          _isShowingConfirmationDialog = false;
        });
      }
    }

    // Sync metadata from controller to screen controllers when lookup completes
    if (_controller.onlineMetadataStatus == OnlineMetadataStatus.found &&
        mounted) {
      // Check if no duration data was found and show warning
      if (_controller.lastLookupResult?.missingDuration == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No duration data found, importing remaining metadata'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }

      setState(() {
        // Sync BPM
        if (_controller.bpmController.text.isNotEmpty) {
          _bpmController.text = _controller.bpmController.text;
        }

        // Sync duration
        if (_controller.durationController.text.isNotEmpty) {
          _durationController.text = _controller.durationController.text;
        }

        // Sync title and artist
        if (_controller.titleController.text.isNotEmpty) {
          _titleController.text = _controller.titleController.text;
        }
        if (_controller.artistController.text.isNotEmpty) {
          _artistController.text = _controller.artistController.text;
        }

        // Sync key and time signature
        _selectedKey = _controller.selectedKey;
        _selectedTimeSignature = _controller.timeSignature;
      });
    }
  }

  /// Show title-only confirmation dialog
  Future<void> _showTitleOnlyConfirmationDialog(
      SongMetadataLookupResult result) async {
    final confirmed = await TitleOnlyConfirmationDialog.show(
      context: context,
      result: result,
    );

    if (confirmed) {
      // User accepted - complete the lookup
      await _controller.confirmTitleOnlyLookup();
    } else {
      // User rejected - return to editor
      _controller.rejectTitleOnlyLookup();
    }
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

      // Load duration from database field first, fallback to ChordPro metadata
      if (song.duration != null && song.duration!.isNotEmpty) {
        _durationController.text = song.duration!;
      } else {
        // Extract duration from ChordPro metadata if available (fallback)
        final metadata = SongImportService.extractMetadata(song.body);
        if (metadata.duration != null) {
          _durationController.text = metadata.duration!;
        }
      }
    } else {
      // Default values for new song
      _bpmController.text = '120';
    }
  }

  void _handleKeySelection(String newKey) {
    if (newKey == _selectedKey) return;

    // Only transpose if auto-transpose is enabled
    if (_isAutoTransposeEnabled) {
      final diff =
          TranspositionService.calculateKeyDifference(_selectedKey, newKey);
      if (diff != null && diff != 0) {
        _transposeBody(diff);
      }
    }

    setState(() {
      _selectedKey = newKey;
    });
  }

  void _handleAutoTransposeChanged(bool enabled) {
    setState(() {
      _isAutoTransposeEnabled = enabled;
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

  /// Test method to verify SongBPM API works
  Future<void> _testSongMetadataAPI() async {
    // Check if title is provided (artist is now optional)
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();

    if (title.isEmpty) {
      _showRetrieveInfoDialog(
        title: 'Missing Information',
        content:
            'Please enter a song title before retrieving song information.',
        showRetry: false,
      );
      return;
    }

    // Use controller's lookup method to trigger confirmation flow for title-only searches
    _controller.triggerOnlineLookup(title, artist);
  }

  /// Initialize form fields with song data and retry options
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
    setState(() {
      _isMetadataHidden = !_isMetadataHidden;
    });
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

      // Normalize duration input: support both M:SS / MM:SS and 1–4 digit
      // numeric input where the last two digits are seconds (e.g. 300 -> 3:00,
      // 518 -> 5:18).
      final rawDuration = _durationController.text.trim();
      String? normalizedDuration;
      if (rawDuration.isEmpty) {
        normalizedDuration = null;
      } else if (rawDuration.contains(':')) {
        // Already M:SS or MM:SS
        normalizedDuration = rawDuration;
      } else if (RegExp(r'^\d{1,4}$').hasMatch(rawDuration)) {
        // Pure digits: interpret last two digits as seconds
        final value = int.tryParse(rawDuration);
        if (value != null) {
          final minutes = value ~/ 100;
          final seconds = value % 100;
          if (seconds < 60) {
            normalizedDuration =
                '$minutes:${seconds.toString().padLeft(2, '0')}';
          } else {
            // 3-digit like 367 -> 3:67 (invalid seconds); let validator complain
            normalizedDuration = rawDuration;
          }
        } else {
          normalizedDuration = rawDuration;
        }
      } else {
        // Unexpected format; leave as-is and let validator handle it
        normalizedDuration = rawDuration;
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
        duration: normalizedDuration,
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
    if (_isImportingFromUrl) {
      return;
    }

    final url = await _promptForUltimateGuitarUrl();
    if (!mounted || url == null || url.trim().isEmpty) {
      return;
    }

    setState(() {
      _isImportingFromUrl = true;
    });

    try {
      final importResult =
          await SongImportService.importFromUltimateGuitar(url);

      if (!mounted) {
        return;
      }

      if (!importResult.success ||
          importResult.body == null ||
          importResult.body!.trim().isEmpty) {
        final error = importResult.error ?? 'Unknown error';
        _showImportError(error);
        return;
      }

      _applyImportedContent(
        body: importResult.body!,
        title: importResult.title,
        artist: importResult.artist,
        key: importResult.key,
        capo: importResult.capo,
        tempo: importResult.tempo,
        timeSignature: importResult.timeSignature,
        duration: importResult.duration,
      );

      _lastImportedUrl = url;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported song from Ultimate Guitar'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Trigger metadata lookup if title (and optional artist) were detected
      final title = importResult.title?.trim() ?? '';
      final artist = importResult.artist?.trim() ?? '';
      if (title.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _controller.triggerOnlineLookup(title, artist);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showImportError('Failed to import tab. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingFromUrl = false;
        });
      }
    }
  }

  Future<String?> _promptForUltimateGuitarUrl() async {
    final controller = TextEditingController(text: _lastImportedUrl ?? '');

    final url = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import from Ultimate Guitar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste the Ultimate Guitar tab URL. Supported format: https://tabs.ultimate-guitar.com/tab/...',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'https://tabs.ultimate-guitar.com/tab/...',
                ),
                autofocus: true,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    // Dispose controller after a short delay to allow dialog animation to complete
    // Disposing immediately causes "TextEditingController used after being disposed" errors
    Future.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });

    // Avoid disposing immediately because the dialog's closing animation may still
    // reference this controller on Android, which would trigger a use-after-dispose
    // exception. Let it be garbage-collected instead.
    return url;
  }

  void _applyImportedContent({
    required String body,
    String? title,
    String? artist,
    String? key,
    int? capo,
    String? tempo,
    String? timeSignature,
    String? duration,
  }) {
    setState(() {
      _bodyController.text = body;
      if (title != null && title.isNotEmpty) {
        _titleController.text = title;
      }
      if (artist != null && artist.isNotEmpty) {
        _artistController.text = artist;
      }
      if (key != null && key.isNotEmpty) {
        _selectedKey = key;
      }
      if (capo != null) {
        _selectedCapo = capo;
      }
      if (tempo != null && tempo.isNotEmpty) {
        _bpmController.text = tempo;
      }
      if (timeSignature != null && timeSignature.isNotEmpty) {
        _selectedTimeSignature = timeSignature;
      }
      if (duration != null && duration.isNotEmpty) {
        _durationController.text = duration;
      }
    });
  }

  void _showImportError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
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

  /// Check form fields for metadata lookup before conversion
  /// Returns true if metadata lookup was performed (regardless of result)
  Future<bool> _checkFormFieldsForMetadata() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();

    // Case 1: Artist + Title entered - perform full metadata search
    if (title.isNotEmpty && artist.isNotEmpty) {
      _controller.triggerOnlineLookup(title, artist);
      return true;
    }

    // Case 2: Only Title entered - perform title-only search with confirmation
    if (title.isNotEmpty && artist.isEmpty) {
      _controller.triggerOnlineLookup(title, '');
      return true;
    }

    // Case 3: Neither entered - no lookup from form fields
    return false;
  }

  void _convertToChordPro() async {
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

    // NEW FLOW: Check form fields for metadata lookup first
    final formFieldsLookupPerformed = await _checkFormFieldsForMetadata();

    // Save current form field values to protect them from content detection overwrites
    final originalTitle = _titleController.text.trim();
    final originalArtist = _artistController.text.trim();
    final hasMetadataFromForm =
        originalTitle.isNotEmpty || originalArtist.isNotEmpty;

    // If form fields lookup was performed, show confirmation but continue with conversion
    if (formFieldsLookupPerformed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metadata lookup initiated from form fields'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    // ALWAYS proceed with text conversion, but protect metadata-populated fields
    // Detect content type
    final isTab = ContentTypeDetector.isTabContent(currentText);

    String convertedText;
    String conversionType;
    bool shouldTriggerMetadataLookup = false;

    try {
      if (isTab) {
        // Convert tab content using ShareImportService
        final shareImportService = ShareImportService();
        convertedText = shareImportService
            .convertUltimateGuitarTabExportToChordPro(currentText);
        conversionType = 'tab';
        // Tab content does NOT trigger metadata lookup
      } else {
        // Convert chord content using UGTextConverter
        final result = UGTextConverter.convertToChordPro(currentText);
        convertedText = result['chordpro'] as String;
        final metadata = result['metadata'] as Map<String, String>;
        conversionType = 'chord';

        // Only populate form fields from content if they weren't already populated from form fields
        if (!hasMetadataFromForm) {
          // Track if we have title and artist for auto-retrieval
          bool hasTitle =
              metadata['title'] != null && metadata['title']!.isNotEmpty;
          bool hasArtist =
              metadata['artist'] != null && metadata['artist']!.isNotEmpty;

          // Populate form fields with extracted metadata
          setState(() {
            if (hasTitle) {
              _titleController.text = metadata['title']!;
            }
            if (hasArtist) {
              _artistController.text = metadata['artist']!;
            }
            if (metadata['key'] != null && metadata['key']!.isNotEmpty) {
              _selectedKey = metadata['key']!;
            }
            if (metadata['bpm'] != null && metadata['bpm']!.isNotEmpty) {
              _bpmController.text = metadata['bpm']!;
            }
            if (metadata['timeSignature'] != null &&
                metadata['timeSignature']!.isNotEmpty) {
              _selectedTimeSignature = metadata['timeSignature']!;
            }
            if (metadata['capo'] != null && metadata['capo']!.isNotEmpty) {
              _selectedCapo = int.tryParse(metadata['capo']!) ?? 0;
            }
          });

          // Auto-retrieve additional metadata if title and artist are present
          if (hasTitle && hasArtist) {
            shouldTriggerMetadataLookup = true;
          }
        } else {}
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

      // Trigger metadata lookup if needed (with delay for UI update)
      if (shouldTriggerMetadataLookup) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _testSongMetadataAPI();
          }
        });
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

    // Layout tuning: on narrow/mobile screens, give metadata and body
    // approximately equal vertical space by default, but when the
    // on-screen keyboard is visible, bias more height toward the body
    // so text remains readable while still keeping metadata accessible.
    // On wider screens, keep a taller body layout but slightly increase
    // the metadata height so the scrollable frame is noticeably taller.
    final mediaQuery = MediaQuery.of(context);
    final isMobileWidth = mediaQuery.size.width < 700;
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    // These values are intentionally simple integers so you can
    // fine-tune them easily:
    // - On mobile with keyboard hidden: metadata/body roughly 50/50
    // - On mobile with keyboard visible: give the body more space
    // - On larger screens: keep existing proportions
    final int metadataFlex;
    final int bodyFlex;

    if (isMobileWidth) {
      if (isKeyboardVisible) {
        // Keyboard up on mobile: shrink metadata so the editor body
        // has more vertical space.
        metadataFlex = 2;
        bodyFlex = 1;
      } else {
        // Keyboard hidden on mobile: keep metadata and body balanced.
        metadataFlex = 1;
        bodyFlex = 1;
      }
    } else {
      // Desktop / tablet proportions remain as before.
      metadataFlex = 8;
      bodyFlex = 15;
    }

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
                  // Metadata section: allow it to shrink and scroll so it
                  // doesn't push the editor body off the bottom of the screen.
                  // On mobile, we give it explicit flex so it uses about
                  // half the height alongside the body.
                  if (!hideMetadata)
                    Expanded(
                      flex: metadataFlex,
                      child: SingleChildScrollView(
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
                                  onAutoTransposeChanged:
                                      _handleAutoTransposeChanged,
                                  isAutoTransposeEnabled:
                                      _isAutoTransposeEnabled,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // MIDI Sends section
                            Container(
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
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  // Body (ChordPro text) field - borderless editing area
                  Expanded(
                    flex: bodyFlex,
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
