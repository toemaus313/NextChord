import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/midi_profile.dart';

/// Controller for managing song editor state and logic
class SongEditorController extends ChangeNotifier {
  final Song? song;

  // Form controllers
  final TextEditingController titleController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController bpmController = TextEditingController();
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

      titleController.text = _originalTitle;
      artistController.text = _originalArtist;
      bodyController.text = _originalBody;
      bpmController.text = _originalBpm.toString();
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

      bpmController.text = '120';
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
    notesController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    final currentTitle = titleController.text;
    final currentArtist = artistController.text;
    final currentBody = bodyController.text;
    final currentBpm = int.tryParse(bpmController.text) ?? 120;
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
        currentNotes != (song?.notes ?? '');

    notifyListeners();
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
      createdAt: song?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void restoreOriginalValues() {
    titleController.text = _originalTitle;
    artistController.text = _originalArtist;
    bodyController.text = _originalBody;
    bpmController.text = _originalBpm.toString();
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
    notesController.clear();
    _selectedKey = 'C';
    _selectedCapo = 0;
    _timeSignature = '4/4';
    _tags = [];
    _audioFilePath = null;
    _selectedMidiProfile = null;
    _showKeyboard = false;
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    artistController.dispose();
    bodyController.dispose();
    bpmController.dispose();
    notesController.dispose();
    super.dispose();
  }
}
