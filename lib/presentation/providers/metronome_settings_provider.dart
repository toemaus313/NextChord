import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing metronome settings persistence
/// Uses SharedPreferences for storing metronome configuration
class MetronomeSettingsProvider extends ChangeNotifier {
  static const String _countInOnlyKey = 'metronome_count_in_only';
  static const String _countInMeasuresKey = 'metronome_count_in_measures';
  static const String _tickActionKey = 'metronome_tick_action';
  static const String _midiSendOnTickKey = 'metronome_midi_send_on_tick';

  bool _countInOnly = false;
  int _countInMeasures = 1; // Default to 1 measure
  String _tickAction = 'Flash'; // Default to Flash
  String _midiSendOnTick = ''; // Default empty
  SharedPreferences? _prefs;

  // Getters
  bool get countInOnly => _countInOnly;
  int get countInMeasures => _countInMeasures;
  String get tickAction => _tickAction;
  String get midiSendOnTick => _midiSendOnTick;

  MetronomeSettingsProvider() {
    _loadSettings();
  }

  /// Load all metronome settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _countInOnly = _prefs?.getBool(_countInOnlyKey) ?? false;
      _countInMeasures = _prefs?.getInt(_countInMeasuresKey) ?? 1;
      _tickAction = _prefs?.getString(_tickActionKey) ?? 'Flash';
      _midiSendOnTick = _prefs?.getString(_midiSendOnTickKey) ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading metronome settings: $e');
      // Use defaults if loading fails
      _countInOnly = false;
      _countInMeasures = 1;
      _tickAction = 'Flash';
      _midiSendOnTick = '';
    }
  }

  /// Update count in only setting
  Future<void> setCountInOnly(bool value) async {
    if (_countInOnly != value) {
      _countInOnly = value;
      await _prefs?.setBool(_countInOnlyKey, _countInOnly);
      notifyListeners();
    }
  }

  /// Update tick action setting
  Future<void> setTickAction(String value) async {
    if (_tickAction != value) {
      _tickAction = value;
      await _prefs?.setString(_tickActionKey, _tickAction);
      notifyListeners();
    }
  }

  /// Update count in measures setting
  Future<void> setCountInMeasures(int value) async {
    if (_countInMeasures != value) {
      _countInMeasures = value;
      await _prefs?.setInt(_countInMeasuresKey, _countInMeasures);
      notifyListeners();
    }
  }

  /// Update MIDI send on tick setting
  Future<void> setMidiSendOnTick(String value) async {
    if (_midiSendOnTick != value) {
      _midiSendOnTick = value;
      await _prefs?.setString(_midiSendOnTickKey, _midiSendOnTick);
      notifyListeners();
    }
  }

  /// Get available tick actions
  static List<String> get availableTickActions => [
        'Flash',
        'Tick',
        'Flash + Tick',
        'Count In Only',
      ];

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _countInOnly = false;
    _countInMeasures = 1;
    _tickAction = 'Flash';
    _midiSendOnTick = '';

    await _prefs?.setBool(_countInOnlyKey, _countInOnly);
    await _prefs?.setInt(_countInMeasuresKey, _countInMeasures);
    await _prefs?.setString(_tickActionKey, _tickAction);
    await _prefs?.setString(_midiSendOnTickKey, _midiSendOnTick);

    notifyListeners();
  }
}
