import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/midi_profile.dart';
import '../../../services/song_metadata_service.dart';

/// Status enum for online metadata lookup
enum OnlineMetadataStatus {
  idle,
  searching,
  pendingConfirmation,
  found,
  notFound,
  error,
}

/// Controller for managing song editor state and logic
class SongEditorController extends ChangeNotifier {
  final Song? song;

  // Form controllers
  final TextEditingController titleController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController bpmController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // Form state
  String _selectedKey = 'C';
  int _selectedCapo = 0;
  String _timeSignature = '4/4';
  List<String> _tags = [];
  String? _audioFilePath;
  MidiProfile? _selectedMidiProfile;
  bool _showKeyboard = false;
  bool _hasUnsavedChanges = false;

  // Online lookup state tracking
  bool _titleArtistAutoPopulated =
      false; // Set to true by import services when title/artist are auto-populated
  bool _hasAttemptedOnlineLookup = false;
  bool _onlineLookupCompletedSuccessfully = false;
  OnlineMetadataStatus _onlineMetadataStatus = OnlineMetadataStatus.idle;

  // Title-only confirmation flow state
  SongMetadataLookupResult? _pendingTitleOnlyResult;

  // Last complete lookup result for UI access
  SongMetadataLookupResult? _lastLookupResult;

  // Metadata lookup service and debouncing
  final SongMetadataService _metadataService = SongMetadataService();
  Timer? _lookupDebounceTimer;

  // Original values for comparison
  late final String _originalTitle;
  late final String _originalArtist;
  late final String _originalBody;
  late final String _originalKey;
  late final int _originalCapo;
  late final int _originalBpm;
  late final String _originalTimeSignature;
  late final List<String> _originalTags;
  late final String? _originalAudioFilePath;
  late final String? _originalMidiProfileId;
  late final String? _originalDuration;

  // Available options
  static const List<String> availableKeys = [
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
    'Am',
    'A#m',
    'Bm',
    'Cm',
    'C#m',
    'Dm',
    'D#m',
    'Em',
    'Fm',
    'F#m',
    'Gm',
    'G#m'
  ];

  static final List<int> availableCapoFrets = List.generate(13, (i) => i);
  static const List<String> availableTimeSignatures = [
    '4/4',
    '3/4',
    '2/4',
    '6/8',
    '12/8',
    '5/4',
    '7/8'
  ];

  SongEditorController({this.song}) {
    _initializeFromSong();
  }

  void _initializeFromSong() {
    if (song != null) {
      _originalTitle = song!.title;
      _originalArtist = song!.artist;
      _originalBody = song!.body;
      _originalKey = song!.key;
      _originalCapo = song!.capo;
      _originalBpm = song!.bpm;
      _originalTimeSignature = song!.timeSignature;
      _originalTags = List.from(song!.tags);
      _originalAudioFilePath = song!.audioFilePath;
      _originalMidiProfileId = song!.profileId;
      _originalDuration = song!.duration;

      titleController.text = _originalTitle;
      artistController.text = _originalArtist;
      bodyController.text = _originalBody;
      bpmController.text = _originalBpm.toString();
      durationController.text = _originalDuration ?? '';
      _selectedKey = _originalKey;
      _selectedCapo = _originalCapo;
      _timeSignature = _originalTimeSignature;
      _tags = List.from(_originalTags);
      _audioFilePath = _originalAudioFilePath;
      // MIDI profile would be set via provider
    } else {
      _originalTitle = '';
      _originalArtist = '';
      _originalBody = '';
      _originalKey = 'C';
      _originalCapo = 0;
      _originalBpm = 120;
      _originalTimeSignature = '4/4';
      _originalTags = [];
      _originalAudioFilePath = null;
      _originalMidiProfileId = null;
      _originalDuration = null;

      bpmController.text = '120';
      durationController.text = '';
      _selectedKey = 'C';
      _selectedCapo = 0;
      _timeSignature = '4/4';
      _tags = [];
    }

    // Add listeners to track changes
    titleController.addListener(_onFormChanged);
    artistController.addListener(_onFormChanged);
    bodyController.addListener(_onFormChanged);
    bpmController.addListener(_onFormChanged);
    durationController.addListener(_onFormChanged);
    notesController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    final currentTitle = titleController.text;
    final currentArtist = artistController.text;
    final currentBody = bodyController.text;
    final currentBpm = int.tryParse(bpmController.text) ?? 120;
    final currentDuration = durationController.text.trim();
    final currentNotes = notesController.text;

    _hasUnsavedChanges = currentTitle != _originalTitle ||
        currentArtist != _originalArtist ||
        currentBody != _originalBody ||
        _selectedKey != _originalKey ||
        _selectedCapo != _originalCapo ||
        currentBpm != _originalBpm ||
        _timeSignature != _originalTimeSignature ||
        !listEquals(_tags, _originalTags) ||
        _audioFilePath != _originalAudioFilePath ||
        _selectedMidiProfile?.id != _originalMidiProfileId ||
        currentDuration != (_originalDuration ?? '') ||
        currentNotes != (song?.notes ?? '');

    // Trigger online lookup if conditions are met
    _debounceOnlineLookup(currentTitle, currentArtist);

    notifyListeners();
  }

  /// Normalize the duration field into a canonical M:SS or MM:SS string.
  ///
  /// Supports:
  /// - Empty string -> null
  /// - Existing M:SS / MM:SS formats -> unchanged
  /// - 1-4 digit numeric input (e.g. 300) -> minutes/seconds, where the
  ///   last two digits are seconds. For example:
  ///   3   -> 0:03
  ///   45  -> 0:45
  ///   300 -> 3:00
  ///   123 -> 1:23
  /// If the derived seconds are >= 60, the raw value is returned so that
  /// validation can flag it instead of silently changing it.
  String? _normalizedDurationOrNull() {
    final raw = durationController.text.trim();
    if (raw.isEmpty) {
      return null;
    }

    // If the user already entered a colon-based duration, keep it as-is.
    if (raw.contains(':')) {
      return raw;
    }

    // Support 1–4 digit numeric input.
    final digitsOnly = RegExp(r'^\d{1,4}$');
    if (!digitsOnly.hasMatch(raw)) {
      // Something unexpected – let the validator handle it.
      return raw;
    }

    final value = int.tryParse(raw);
    if (value == null) {
      return raw;
    }

    // Interpret last two digits as seconds.
    final minutes = value ~/ 100;
    final seconds = value % 100;
    if (seconds >= 60) {
      // Obviously invalid (e.g. 367 -> 3:67); let validator complain.
      return raw;
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Getters
  String get selectedKey => _selectedKey;
  int get selectedCapo => _selectedCapo;
  String get timeSignature => _timeSignature;
  List<String> get tags => List.unmodifiable(_tags);
  String? get audioFilePath => _audioFilePath;
  MidiProfile? get selectedMidiProfile => _selectedMidiProfile;
  bool get showKeyboard => _showKeyboard;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isValid => titleController.text.trim().isNotEmpty;

  // Online lookup state getters
  bool get titleArtistAutoPopulated => _titleArtistAutoPopulated;
  bool get hasAttemptedOnlineLookup => _hasAttemptedOnlineLookup;
  bool get onlineLookupCompletedSuccessfully =>
      _onlineLookupCompletedSuccessfully;
  OnlineMetadataStatus get onlineMetadataStatus => _onlineMetadataStatus;

  /// Get the last complete lookup result (for UI access like warning snackbars)
  SongMetadataLookupResult? get lastLookupResult => _lastLookupResult;

  /// Pending title-only result for confirmation flow
  SongMetadataLookupResult? get pendingTitleOnlyResult =>
      _pendingTitleOnlyResult;

  // Setters
  void setSelectedKey(String key) {
    _selectedKey = key;
    _onFormChanged();
  }

  void setSelectedCapo(int capo) {
    _selectedCapo = capo;
    _onFormChanged();
  }

  void setTimeSignature(String timeSignature) {
    _timeSignature = timeSignature;
    _onFormChanged();
  }

  void setTags(List<String> tags) {
    _tags = List.from(tags);
    _onFormChanged();
  }

  void setAudioFilePath(String? path) {
    _audioFilePath = path;
    _onFormChanged();
  }

  void setSelectedMidiProfile(MidiProfile? profile) {
    _selectedMidiProfile = profile;
    _onFormChanged();
  }

  void toggleKeyboard() {
    _showKeyboard = !_showKeyboard;
    notifyListeners();
  }

  // Online lookup state setters
  void setTitleArtistAutoPopulated(bool autoPopulated) {
    _titleArtistAutoPopulated = autoPopulated;
    notifyListeners();
  }

  void setOnlineMetadataStatus(OnlineMetadataStatus status) {
    _onlineMetadataStatus = status;
    notifyListeners();
  }

  void setHasAttemptedOnlineLookup(bool attempted) {
    _hasAttemptedOnlineLookup = attempted;
    notifyListeners();
  }

  void setOnlineLookupCompletedSuccessfully(bool completed) {
    _onlineLookupCompletedSuccessfully = completed;
    notifyListeners();
  }

  /// Debounce online lookup to avoid rapid API calls during typing
  void _debounceOnlineLookup(String title, String artist) {
    // Cancel existing timer
    _lookupDebounceTimer?.cancel();

    // Check if lookup should be triggered
    if (!_shouldTriggerOnlineLookup(title, artist)) {
      return;
    }

    // Set new timer for 1.5 seconds delay
    _lookupDebounceTimer =
        Timer(const Duration(seconds: 1, milliseconds: 500), () {
      _triggerOnlineLookup(title, artist);
    });
  }

  /// Check if online lookup should be triggered based on current conditions
  bool _shouldTriggerOnlineLookup(String title, String artist) {
    // Don't trigger if title/artist were auto-populated by parser
    if (_titleArtistAutoPopulated) {
      return false;
    }

    // Don't trigger if title is empty (artist is now optional)
    if (title.trim().isEmpty) {
      return false;
    }

    // Don't trigger if we've already attempted lookup for this song
    if (_hasAttemptedOnlineLookup) {
      return false;
    }

    // Don't trigger if we've already successfully completed lookup
    if (_onlineLookupCompletedSuccessfully) {
      return false;
    }

    return true;
  }

  /// Trigger the online metadata lookup
  Future<void> _triggerOnlineLookup(String title, String artist) async {
    if (!_shouldTriggerOnlineLookup(title, artist)) return;

    setOnlineMetadataStatus(OnlineMetadataStatus.searching);
    setHasAttemptedOnlineLookup(true);

    try {
      // Check if this is a title-only search
      if (artist.trim().isEmpty) {
        // Title-only flow: fetch from SongBPM only and show confirmation
        final result = await _metadataService.fetchTitleOnlyMetadata(
          title: title.trim(),
        );

        if (result.success) {
          _pendingTitleOnlyResult = result;
          setOnlineMetadataStatus(OnlineMetadataStatus.pendingConfirmation);
        } else if (result.error != null) {
          setOnlineMetadataStatus(OnlineMetadataStatus.error);
        } else {
          setOnlineMetadataStatus(OnlineMetadataStatus.notFound);
        }
      } else {
        // Title + Artist flow: use existing parallel API calls
        final result = await _metadataService.fetchMetadata(
          title: title.trim(),
          artist: artist.trim(),
        );

        if (result.success) {
          _applyMetadataResult(result);
          setOnlineMetadataStatus(OnlineMetadataStatus.found);
          setOnlineLookupCompletedSuccessfully(true);
        } else if (result.error != null) {
          setOnlineMetadataStatus(OnlineMetadataStatus.error);
        } else {
          setOnlineMetadataStatus(OnlineMetadataStatus.notFound);
        }
      }
    } catch (e) {
      setOnlineMetadataStatus(OnlineMetadataStatus.error);
    }
  }

  /// Complete title-only lookup after user confirmation
  Future<void> confirmTitleOnlyLookup() async {
    if (_pendingTitleOnlyResult == null) return;

    setOnlineMetadataStatus(OnlineMetadataStatus.searching);

    try {
      final result = await _metadataService.completeTitleOnlyLookup(
        title: _pendingTitleOnlyResult!.correctedTitle ??
            titleController.text.trim(),
        artist: _pendingTitleOnlyResult!.correctedArtist,
        tempo: _pendingTitleOnlyResult!.tempoBpm?.toInt() ?? 0,
        key: _pendingTitleOnlyResult!.key,
        timeSignature: _pendingTitleOnlyResult!.timeSignature,
      );

      if (result.success) {
        _applyMetadataResult(result);
        setOnlineMetadataStatus(OnlineMetadataStatus.found);
        setOnlineLookupCompletedSuccessfully(true);
        _pendingTitleOnlyResult = null; // Clear pending result
        setHasAttemptedOnlineLookup(false); // Reset flag to allow retries
        setOnlineLookupCompletedSuccessfully(
            false); // Reset flag to allow retries
      } else if (result.error != null) {
        setOnlineMetadataStatus(OnlineMetadataStatus.error);
        setHasAttemptedOnlineLookup(false); // Reset flag to allow retries
        setOnlineLookupCompletedSuccessfully(
            false); // Reset flag to allow retries
      } else {
        setOnlineMetadataStatus(OnlineMetadataStatus.notFound);
        setHasAttemptedOnlineLookup(false); // Reset flag to allow retries
        setOnlineLookupCompletedSuccessfully(
            false); // Reset flag to allow retries
      }
    } catch (e) {
      setOnlineMetadataStatus(OnlineMetadataStatus.error);
      setHasAttemptedOnlineLookup(false); // Reset flag to allow retries
      setOnlineLookupCompletedSuccessfully(
          false); // Reset flag to allow retries
      print('Exception in confirmTitleOnlyLookup: $e');
    }
  }

  /// Reject title-only lookup and return to editor
  void rejectTitleOnlyLookup() {
    _pendingTitleOnlyResult = null;
    setOnlineMetadataStatus(OnlineMetadataStatus.idle);
    setHasAttemptedOnlineLookup(false); // Reset flag to allow retries
    setOnlineLookupCompletedSuccessfully(false); // Reset flag to allow retries
  }

  /// Public method to trigger online metadata lookup (for manual "Get Song Info" button)
  void triggerOnlineLookup(String title, String artist) {
    _triggerOnlineLookup(title, artist);
  }

  /// Apply metadata from lookup result, respecting user-entered values
  void _applyMetadataResult(SongMetadataLookupResult result) {
    // Store the complete result for UI access (e.g., warning snackbars)
    _lastLookupResult = result;

    // Only apply tempo if field is at default value or empty
    final currentBpm = int.tryParse(bpmController.text);
    if (result.tempoBpm != null && (currentBpm == null || currentBpm == 120)) {
      bpmController.text = result.tempoBpm!.round().toString();
    }

    // Only apply key if at default value
    if (result.key != null && _selectedKey == 'C') {
      setSelectedKey(result.key!);
    }

    // Only apply time signature if at default value
    if (result.timeSignature != null && _timeSignature == '4/4') {
      setTimeSignature(result.timeSignature!);
    }

    // Only apply duration if empty
    if (result.durationMs != null && durationController.text.trim().isEmpty) {
      final formattedDuration =
          SongMetadataLookupResult.formatDuration(result.durationMs);
      if (formattedDuration != null) {
        durationController.text = formattedDuration;
      }
    }

    // Update title and artist if they were auto-corrected
    if (result.correctedTitle != null && result.correctedTitle!.isNotEmpty) {
      titleController.text = result.correctedTitle!;
    }
    if (result.correctedArtist != null && result.correctedArtist!.isNotEmpty) {
      artistController.text = result.correctedArtist!;
    }

    notifyListeners(); // Notify screen of metadata changes
  }

  void transposeBody(int semitones) {
    if (semitones == 0) return;

    // Simple transposition logic - in a real app, this would be more sophisticated
    final currentKeyIndex = availableKeys.indexOf(_selectedKey);
    if (currentKeyIndex == -1) return;

    final keyCount = availableKeys.length;
    var newIndex = (currentKeyIndex + semitones) % keyCount;
    if (newIndex < 0) newIndex += keyCount;

    _selectedKey = availableKeys[newIndex];

    // Transpose capo if possible
    if (_selectedCapo > 0) {
      final newCapo = _selectedCapo - semitones;
      if (newCapo >= 0 && newCapo <= 12) {
        _selectedCapo = newCapo;
      }
    }

    _onFormChanged();
  }

  Song createSong() {
    final bpm = int.tryParse(bpmController.text) ?? 120;
    final normalizedDuration = _normalizedDurationOrNull();

    return Song(
      id: song?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      artist: artistController.text.trim(),
      body: bodyController.text.trim(),
      key: _selectedKey,
      capo: _selectedCapo,
      bpm: bpm,
      timeSignature: _timeSignature,
      tags: _tags,
      audioFilePath: _audioFilePath,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      profileId: _selectedMidiProfile?.id,
      duration: normalizedDuration,
      createdAt: song?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void restoreOriginalValues() {
    titleController.text = _originalTitle;
    artistController.text = _originalArtist;
    bodyController.text = _originalBody;
    bpmController.text = _originalBpm.toString();
    durationController.text = _originalDuration ?? '';
    notesController.text = song?.notes ?? '';
    _selectedKey = _originalKey;
    _selectedCapo = _originalCapo;
    _timeSignature = _originalTimeSignature;
    _tags = List.from(_originalTags);
    _audioFilePath = _originalAudioFilePath;
    // MIDI profile would need to be restored via provider
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void reset() {
    titleController.clear();
    artistController.clear();
    bodyController.clear();
    bpmController.text = '120';
    durationController.clear();
    notesController.clear();
    _selectedKey = 'C';
    _selectedCapo = 0;
    _timeSignature = '4/4';
    _tags = [];
    _audioFilePath = null;
    _selectedMidiProfile = null;
    _showKeyboard = false;
    _hasUnsavedChanges = false;

    // Reset online lookup state
    _titleArtistAutoPopulated = false;
    _hasAttemptedOnlineLookup = false;
    _onlineLookupCompletedSuccessfully = false;
    _onlineMetadataStatus = OnlineMetadataStatus.idle;

    notifyListeners();
  }

  @override
  void dispose() {
    _lookupDebounceTimer?.cancel();
    titleController.dispose();
    artistController.dispose();
    bodyController.dispose();
    bpmController.dispose();
    durationController.dispose();
    notesController.dispose();
    super.dispose();
  }
}
