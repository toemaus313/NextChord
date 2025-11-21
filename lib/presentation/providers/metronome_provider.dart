import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/midi/midi_service.dart';
import 'metronome_settings_provider.dart';

typedef MetronomeTickAction = FutureOr<void> Function(int tickCount);
typedef AutoscrollActiveCallback = bool Function();

/// Provides metronome state, timing, and extensibility hooks for UI and
/// automation features.
class MetronomeProvider extends ChangeNotifier {
  static const int _minTempo = 30;
  static const int _maxTempo = 320;
  static const Duration _flashDuration = Duration(milliseconds: 140);

  AudioPlayer? _player; // base beat (lo)
  AudioPlayer? _accentPlayer; // accent beat (hi)
  final Map<String, MetronomeTickAction> _tickActions = {};
  MetronomeSettingsProvider? _settingsProvider;
  MidiService? _midiService;
  AutoscrollActiveCallback? _isAutoscrollActiveCallback;

  Timer? _tickTimer;
  Timer? _flashTimer;
  Completer<void>? _loadingCompleter;

  int _tempoBpm = 120;
  int _beatsPerMeasure = 4;
  int _tickCounter = 0;
  bool _isRunning = false;
  bool _flashActive = false;
  bool _isDisposed = false;
  bool _audioAvailable = true; // Track if audio is working
  int _beatsSinceStart =
      0; // Track beats since metronome started for MIDI sends
  bool _isCountingIn = false; // Track if we're in count-in phase
  int _countInBeatsRemaining = 0; // Track remaining count-in beats
  int _currentCountInBeat = 0; // Track current count-in beat number for display

  MetronomeProvider() {
    _ensurePlayerReady();
    _initializeServices();
  }

  /// Initialize service references for MIDI integration
  void _initializeServices() {
    // Initialize MIDI service singleton
    _midiService = MidiService();

    // Register MIDI tick action
    registerTickAction('midi_send_on_tick', _handleMidiSendOnTick);
  }

  /// Set the metronome settings provider (called from UI)
  void setSettingsProvider(MetronomeSettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  /// Set callback to check if autoscroll is active
  void setAutoscrollActiveCallback(AutoscrollActiveCallback callback) {
    _isAutoscrollActiveCallback = callback;
  }

  void setTimeSignature(String timeSignature) {
    final parts = timeSignature.split('/');
    if (parts.length != 2) return;
    final beats = int.tryParse(parts.first.trim());
    if (beats == null || beats <= 0) return;
    if (beats == _beatsPerMeasure) {
      if (_isRunning) {
        _tickCounter = 0;
      }
      return;
    }
    _beatsPerMeasure = beats;
    if (_isRunning) {
      _tickCounter = 0;
    }
    _safeNotifyListeners();
  }

  bool get isRunning => _isRunning;
  int get tempoBpm => _tempoBpm;
  bool get flashActive => _isRunning && _flashActive;
  int get tickCounter => _tickCounter;
  bool get isCountingIn => _isCountingIn;
  int get currentCountInBeat => _currentCountInBeat;

  Future<void> start() async {
    if (_isRunning) return;
    await _ensurePlayerReady();
    _isRunning = true;
    _tickCounter = 0;
    _beatsSinceStart = 0; // Reset beat counter for MIDI sends

    // Initialize count-in if enabled
    _initializeCountIn();

    _safeNotifyListeners();
    _handleTick();
    _startTimer();
  }

  void stop({bool notifyListeners = true}) {
    if (!_isRunning) return;
    _tickTimer?.cancel();
    _tickTimer = null;
    _flashTimer?.cancel();
    _flashTimer = null;
    _flashActive = false;
    _isRunning = false;

    // Reset count-in state
    _isCountingIn = false;
    _countInBeatsRemaining = 0;
    _currentCountInBeat = 0;

    unawaited(_player?.stop());
    unawaited(_accentPlayer?.stop());
    if (notifyListeners) {
      _safeNotifyListeners();
    }
  }

  Future<void> toggle() async {
    if (_isRunning) {
      stop();
    } else {
      await start();
    }
  }

  void setTempo(int bpm) {
    final sanitized = bpm.clamp(_minTempo, _maxTempo);
    if (sanitized == _tempoBpm) return;
    _tempoBpm = sanitized;
    if (_isRunning) {
      _restartTimer();
    }
    notifyListeners();
  }

  void registerTickAction(String key, MetronomeTickAction action) {
    _tickActions[key] = action;
  }

  void unregisterTickAction(String key) {
    _tickActions.remove(key);
  }

  @override
  void dispose() {
    _isDisposed = true;
    stop(notifyListeners: false);
    // Only dispose audio players if they were successfully initialized
    if (_audioAvailable) {
      try {
        _player?.dispose();
        _accentPlayer?.dispose();
      } catch (e) {
        debugPrint('Error disposing audio players: $e');
      }
    }
    super.dispose();
  }

  Future<void> _ensurePlayerReady() async {
    if (!_audioAvailable) {
      return; // Skip audio setup if plugin failed
    }
    if (_player?.audioSource != null && _accentPlayer?.audioSource != null) {
      return;
    }
    if (_loadingCompleter != null) {
      await _loadingCompleter!.future;
      return;
    }

    _loadingCompleter = Completer<void>();
    try {
      // Lazily create players so platform initialization (which can throw
      // MissingPluginException when the plugin isn't registered) is contained
      // in this try/catch and won't crash the app.
      _player ??= AudioPlayer();
      _accentPlayer ??= AudioPlayer();

      if (_player!.audioSource == null) {
        await _player!.setAsset('assets/audio/Synth_Block_B_lo.wav');
        await _player!.setVolume(0.9);
      }
      if (_accentPlayer!.audioSource == null) {
        await _accentPlayer!.setAsset('assets/audio/Synth_Block_B_hi.wav');
        await _accentPlayer!.setVolume(1.0);
      }
    } catch (e, stack) {
      debugPrint('Metronome audio failed to load: $e');
      debugPrint('Audio plugin may not be available on this platform');
      debugPrint(stack.toString());
      _audioAvailable = false; // Disable audio on failure
    } finally {
      _loadingCompleter?.complete();
      _loadingCompleter = null;
    }
  }

  void _startTimer() {
    final intervalMs = (60000 / _tempoBpm).round();
    _tickTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _handleTick();
    });
  }

  void _restartTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (_isRunning) {
      _startTimer();
    }
  }

  void _handleTick() {
    if (!_isRunning) return;

    _tickCounter++;
    _beatsSinceStart++; // Increment beats since start

    // Handle count-in phase
    if (_isCountingIn) {
      _handleCountInTick();
      return;
    }

    // Handle normal metronome operation based on tick action setting
    _handleNormalTick();

    for (final action in _tickActions.values) {
      try {
        final result = action(_tickCounter);
        if (result is Future) {
          unawaited(result);
        }
      } catch (e, stack) {
        debugPrint('Metronome tick action error: $e');
        debugPrint(stack.toString());
      }
    }
  }

  Future<void> _playClick({required bool isAccent}) async {
    if (!_audioAvailable) {
      return; // Skip audio if plugin failed
    }

    try {
      if (_player?.audioSource == null || _accentPlayer?.audioSource == null) {
        await _ensurePlayerReady();
      }

      if (isAccent) {
        if (_accentPlayer != null) unawaited(_playSample(_accentPlayer!));
      }
      if (_player != null) await _playSample(_player!);
    } catch (e, stack) {
      debugPrint('Metronome playback failed: $e');
      debugPrint(stack.toString());
      _audioAvailable = false; // Disable audio on playback failure
    }
  }

  Future<void> _playSample(AudioPlayer player) async {
    await player.seek(Duration.zero);
    await player.play();
  }

  void _triggerFlash() {
    _flashTimer?.cancel();
    _flashActive = true;
    _safeNotifyListeners();

    _flashTimer = Timer(_flashDuration, () {
      _flashActive = false;
      _safeNotifyListeners();
    });
  }

  void _safeNotifyListeners() {
    if (_isDisposed) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      binding.addPostFrameCallback((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }

  /// Initialize count-in based on settings
  void _initializeCountIn() {
    if (_settingsProvider == null) {
      _isCountingIn = false;
      _countInBeatsRemaining = 0;
      return;
    }

    final countInMeasures = _settingsProvider!.countInMeasures;
    if (countInMeasures == 0) {
      // Off
      _isCountingIn = false;
      _countInBeatsRemaining = 0;
    } else {
      // Check if autoscroll is currently active - if so, bypass count-in
      final isAutoscrollActive = _isAutoscrollActiveCallback?.call() ?? false;
      if (isAutoscrollActive) {
        debugPrint(
            '🎵 METRONOME DEBUG: Autoscroll is active - bypassing count-in');
        _isCountingIn = false;
        _countInBeatsRemaining = 0;
      } else {
        // 1 or 2 measures
        debugPrint(
            '🎵 METRONOME DEBUG: Starting count-in - autoscroll not active');
        _isCountingIn = true;
        _countInBeatsRemaining = countInMeasures * _beatsPerMeasure;
        _currentCountInBeat = 0;
      }
    }
  }

  /// Handle tick during count-in phase
  void _handleCountInTick() {
    debugPrint(
        '🎵 METRONOME DEBUG: _handleCountInTick() called - _countInBeatsRemaining: $_countInBeatsRemaining');

    if (_countInBeatsRemaining <= 0) {
      // Count-in finished, transition to normal operation
      debugPrint(
          '🎵 METRONOME DEBUG: Count-in finished, transitioning to normal operation');
      debugPrint(
          '🎵 METRONOME DEBUG: tickAction: ${_settingsProvider?.tickAction}');

      _isCountingIn = false;
      _currentCountInBeat = 0;

      // If "Count In Only" mode, stop here
      if (_settingsProvider?.tickAction == 'Count In Only') {
        debugPrint('🎵 METRONOME DEBUG: Count In Only mode - calling stop()');
        stop();
        return;
      }

      debugPrint(
          '🎵 METRONOME DEBUG: Continuing with normal operation - calling _handleNormalTick()');
      // Continue with normal operation
      _handleNormalTick();
      return;
    }

    _countInBeatsRemaining--;

    // Calculate beat within the current measure (1-based)
    final totalBeatsSoFar =
        (_settingsProvider!.countInMeasures * _beatsPerMeasure) -
            _countInBeatsRemaining;
    _currentCountInBeat = ((totalBeatsSoFar - 1) % _beatsPerMeasure) + 1;

    // During count-in: always flash border and show beat number
    _triggerFlash();

    // Always play sound during count-in
    final isAccent = _currentCountInBeat == 1;
    unawaited(_playClick(isAccent: isAccent));

    _safeNotifyListeners();
  }

  /// Handle normal tick based on user's tick action preference
  void _handleNormalTick() {
    if (_settingsProvider == null) {
      // Default behavior (flash + tick)
      _triggerFlash();
      final isAccent = ((_tickCounter - 1) % _beatsPerMeasure) == 0;
      unawaited(_playClick(isAccent: isAccent));
      return;
    }

    final tickAction = _settingsProvider!.tickAction;
    final isAccent = ((_tickCounter - 1) % _beatsPerMeasure) == 0;

    switch (tickAction) {
      case 'Flash':
        _triggerFlash();
        // No sound
        break;
      case 'Tick':
        // Sound only, no flash
        unawaited(_playClick(isAccent: isAccent));
        break;
      case 'Flash + Tick':
      default:
        _triggerFlash();
        unawaited(_playClick(isAccent: isAccent));
        break;
    }
  }

  /// Handle MIDI send on tick based on metronome settings
  Future<void> _handleMidiSendOnTick(int tickCount) async {
    if (_settingsProvider == null || _midiService == null) {
      return;
    }

    try {
      final midiCommand = _settingsProvider!.midiSendOnTick;
      if (midiCommand.isEmpty) {
        return; // No MIDI command configured
      }

      // Only send if MIDI device is connected
      if (!_midiService!.isConnected) {
        return;
      }

      // Only send MIDI for the first 4 beats after starting metronome
      if (_beatsSinceStart > 4) {
        return;
      }

      // Send the MIDI command
      await _sendMidiCommand(midiCommand);
      debugPrint('🎹 MIDI sent on beat $_beatsSinceStart of 4');
    } catch (e, stack) {
      debugPrint('Error in MIDI send on tick: $e');
      debugPrint(stack.toString());
    }
  }

  /// Send MIDI command based on string format
  Future<void> _sendMidiCommand(String commandText) async {
    if (_midiService == null) return;

    final messages = commandText
        .split(',')
        .map((msg) => msg.trim())
        .where((msg) => msg.isNotEmpty);

    for (final message in messages) {
      final lowerMessage = message.toLowerCase();

      // Check timing command
      if (lowerMessage == 'timing') {
        await _midiService!.sendMidiClock();
      }
      // Parse Program Change: "PC10" or "PC:10"
      else if (lowerMessage.startsWith('pc')) {
        final pcMatch =
            RegExp(r'^pc(\d+)$', caseSensitive: false).firstMatch(message) ??
                RegExp(r'^pc:(\d+)$', caseSensitive: false).firstMatch(message);

        if (pcMatch != null) {
          final pcValue = int.tryParse(pcMatch.group(1)!);
          if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
            await _midiService!
                .sendProgramChange(pcValue, channel: _midiService!.midiChannel);
          }
        }
      }
      // Parse Control Change: "CC7:100"
      else if (lowerMessage.startsWith('cc')) {
        final ccMatch = RegExp(r'^cc(\d+):(\d+)$', caseSensitive: false)
            .firstMatch(message);
        if (ccMatch != null) {
          final controller = int.tryParse(ccMatch.group(1)!);
          final value = int.tryParse(ccMatch.group(2)!);

          if (controller != null &&
              controller >= 0 &&
              controller <= 119 &&
              value != null &&
              value >= 0 &&
              value <= 127) {
            await _midiService!.sendControlChange(controller, value,
                channel: _midiService!.midiChannel);
          }
        }
      }
    }
  }
}
