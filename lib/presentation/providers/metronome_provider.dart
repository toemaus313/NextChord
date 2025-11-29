import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/audio/rock_solid_metronome.dart';
import '../../services/midi/midi_service.dart';
import '../../services/midi/midi_clock_service.dart';
import 'metronome_settings_provider.dart';

typedef MetronomeTickAction = FutureOr<void> Function(int tickCount);
typedef AutoscrollActiveCallback = bool Function();

/// Provides metronome state, timing, and extensibility hooks for UI and
/// automation features.
///
/// **NEW IMPLEMENTATION**: Now uses RockSolidMetronome with timestamp-based
/// scheduling for rock-solid timing accuracy, eliminating Timer.periodic drift.
/// Also includes dedicated MidiClockService for precise MIDI clock (0xF8) timing
/// with self-monitoring and drift compensation.
///
/// Key improvements:
/// - Timestamp-based scheduling prevents cumulative timing drift
/// - Audio preloading and warm-up eliminates first-beat stutter
/// - Microsecond precision timing for professional musicians
/// - MIDI clock sends 0xF8 at precise intervals with self-monitoring
/// - Maintains exact same public API for backward compatibility
///
/// Legacy Timer.periodic implementation preserved in legacy_metronome_provider.dart

class MetronomeProvider extends ChangeNotifier {
  static const int _minTempo = 30;
  static const int _maxTempo = 320;
  static const Duration _flashDuration = Duration(milliseconds: 140);

  // Legacy audio players (kept for compatibility but not used for timing)
  AudioPlayer? _player; // base beat (lo)
  AudioPlayer? _accentPlayer; // accent beat (hi)

  // New rock-solid timing engine
  RockSolidMetronome? _rockSolidMetronome;
  final Map<String, MetronomeTickAction> _tickActions = {};
  MetronomeSettingsProvider? _settingsProvider;
  MidiService? _midiService;
  MidiClockService? _midiClockService; // New dedicated MIDI clock service
  AutoscrollActiveCallback? _isAutoscrollActiveCallback;

  Timer? _flashTimer;
  Completer<void>? _loadingCompleter;

  int _tempoBpm = 120;
  int _beatsPerMeasure = 4;
  int _tickCounter = 0;
  bool _isRunning = false;
  bool _flashActive = false;
  bool _isDisposed = false;
  bool _audioAvailable = true; // Track if audio is working
  bool _isCountingIn = false; // Track if we're in count-in phase
  int _countInBeatsRemaining = 0; // Track remaining count-in beats
  int _currentCountInBeat = 0; // Track current count-in beat number for display

  // Warm-up phase for timing stabilization
  bool _isWarmingUp = false; // Track if we're in warm-up phase
  int _warmUpBeatsRemaining = 0; // Track remaining warm-up beats
  static const int _warmUpBeatsCount = 3; // Number of beats to warm up
  bool _shouldStartCountIn = false; // Whether to start count-in after warm-up

  MetronomeProvider() {
    _ensurePlayerReady();
    initialize();
    _initializeRockSolidMetronome();
    _initializeMidiClockService();
  }

  /// Initialize the new rock-solid metronome engine
  void _initializeRockSolidMetronome() {
    _rockSolidMetronome = RockSolidMetronome(
      tempoBpm: _tempoBpm,
      beatsPerMeasure: _beatsPerMeasure,
      onBeat: _handleRockSolidBeat,
    );
  }

  /// Initialize the dedicated MIDI clock service
  void _initializeMidiClockService() {
    _midiClockService = MidiClockService(midiService: _midiService!);
  }

  /// Handle beat callbacks from RockSolidMetronome
  void _handleRockSolidBeat(int beatNumber, bool isAccent) {
    if (!_isRunning) return;

    _tickCounter++;

    // Handle warm-up phase (silent timing stabilization)
    if (_isWarmingUp) {
      _handleWarmUpTick();
      return;
    }

    // Handle count-in phase
    if (_isCountingIn) {
      _handleCountInTick();
      return;
    }

    // Handle normal metronome operation
    _handleNormalTick();
  }

  /// Handle warm-up ticks (silent, for timing stabilization)
  void _handleWarmUpTick() {
    if (_warmUpBeatsRemaining > 0) {
      _warmUpBeatsRemaining--;
    }

    if (_warmUpBeatsRemaining <= 0) {
      // Warm-up complete, transition to actual operation
      _isWarmingUp = false;

      // Start MIDI clock service now that timing is stable
      _midiClockService?.setBpm(_tempoBpm);
      _midiClockService?.start();

      // Initialize count-in if requested
      if (_shouldStartCountIn) {
        _initializeCountIn();
        // Immediately trigger the first count-in beat (don't wait for next tick)
        _handleCountInTick();
      } else {
        // Skip count-in, go straight to normal operation
        _isCountingIn = false;
        _countInBeatsRemaining = 0;
        _currentCountInBeat = 0;
        // Immediately trigger the first normal beat
        _handleNormalTick();
      }
    }
  }

  /// Initialize service references for MIDI integration
  void initialize() {
    // Initialize MIDI service singleton
    _midiService = MidiService();

    // Register MIDI tick action (legacy, kept for compatibility)
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

    // Update rock-solid metronome
    _rockSolidMetronome?.setBeatsPerMeasure(_beatsPerMeasure);

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

  Future<void> start({bool skipCountIn = false}) async {
    if (_isRunning) return;

    // Store whether we should start count-in after warm-up
    _shouldStartCountIn = !skipCountIn;

    // Start warm-up phase (silent timing stabilization)
    _isWarmingUp = true;
    _warmUpBeatsRemaining = _warmUpBeatsCount;

    _isRunning = true;
    _tickCounter = 0;

    // Start the rock-solid metronome (but don't start MIDI clock yet)
    await _rockSolidMetronome?.start();

    // Note: MIDI clock and count-in will start after warm-up completes

    _safeNotifyListeners();
  }

  void stop({bool notifyListeners = true}) {
    if (!_isRunning) return;

    // Stop the rock-solid metronome
    _rockSolidMetronome?.stop();

    // Stop the dedicated MIDI clock service
    _midiClockService?.stop();

    _flashTimer?.cancel();
    _flashTimer = null;
    _flashActive = false;
    _isRunning = false;

    // Reset count-in state
    _isCountingIn = false;
    _countInBeatsRemaining = 0;
    _currentCountInBeat = 0;

    // Reset warm-up state
    _isWarmingUp = false;
    _warmUpBeatsRemaining = 0;
    _shouldStartCountIn = false;

    if (_player != null) unawaited(_player!.stop());
    if (_accentPlayer != null) unawaited(_accentPlayer!.stop());
    if (notifyListeners) {
      _safeNotifyListeners();
    }
  }

  // Old Timer-based methods removed - replaced by RockSolidMetronome and MidiClockService
  // Legacy implementation preserved in legacy_metronome_provider.dart

  /// Stub MIDI handler - now handled by MidiClockService
  Future<void> _handleMidiSendOnTick(int tickCount) async {
    // MIDI clock timing is now handled by the dedicated MidiClockService
    // This method is kept for compatibility with existing registration
  }

  /// Play count-in only without continuing the metronome
  Future<void> playCountInOnly() async {
    if (_isRunning) {
      stop();
    }

    // Store that we should start count-in after warm-up
    _shouldStartCountIn = true;

    // Start warm-up phase (silent timing stabilization)
    _isWarmingUp = true;
    _warmUpBeatsRemaining = _warmUpBeatsCount;

    _isRunning = true;
    _tickCounter = 0;

    // Start the rock-solid metronome (MIDI clock will start after warm-up)
    await _rockSolidMetronome?.start();

    _safeNotifyListeners();
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

    // Update rock-solid metronome tempo
    _rockSolidMetronome?.setTempo(_tempoBpm);

    // Update MIDI clock service tempo
    _midiClockService?.setBpm(_tempoBpm);

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

    // Dispose rock-solid metronome
    _rockSolidMetronome?.dispose();

    // Dispose MIDI clock service
    _midiClockService?.dispose();

    // Only dispose audio players if they were successfully initialized
    if (_audioAvailable) {
      try {
        _player?.dispose();
        _accentPlayer?.dispose();
      } catch (_) {
        // Ignored: disposing during provider teardown.
      }
    }
    super.dispose();
  }

  // Legacy audio setup method - kept for compatibility but not used for timing
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
    } catch (_) {
      _audioAvailable = false; // Disable audio on failure
    } finally {
      _loadingCompleter?.complete();
      _loadingCompleter = null;
    }
  }

  // Old Timer-based methods removed - replaced by RockSolidMetronome and MidiClockService
  // Legacy implementation preserved in legacy_metronome_provider.dart

  // Legacy _playClick method kept for compatibility but not used for timing
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
    } catch (_) {
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
        _isCountingIn = false;
        _countInBeatsRemaining = 0;
      } else {
        _isCountingIn = true;
        _countInBeatsRemaining = countInMeasures * _beatsPerMeasure;
        _currentCountInBeat = 0;
      }
    }
  }

  /// Handle tick during count-in phase
  void _handleCountInTick() {
    if (_countInBeatsRemaining > 0) {
      // Calculate beat within the current measure (1-based) BEFORE decrementing
      final totalBeatsSoFar =
          (_settingsProvider!.countInMeasures * _beatsPerMeasure) -
              _countInBeatsRemaining +
              1; // Add +1 to fix beat ordering
      _currentCountInBeat = ((totalBeatsSoFar - 1) % _beatsPerMeasure) + 1;

      // During count-in: always flash border and show beat number
      _triggerFlash();

      // Always play sound during count-in
      final isAccent = _currentCountInBeat == 1;
      unawaited(_playClick(isAccent: isAccent));

      _safeNotifyListeners();

      // Decrement AFTER playing the current beat
      _countInBeatsRemaining--;
    }

    if (_countInBeatsRemaining <= 0) {
      // Count-in finished, transition to normal operation
      _isCountingIn = false;
      _tickCounter = 0; // Reset tick counter to ensure proper accent placement

      // If "Count In Only" mode, stop here
      if (_settingsProvider?.tickAction == 'Count In Only') {
        stop();
      }
    }
  }

  /// Handle normal tick based on user's tick action preference
  void _handleNormalTick() {
    // Clear any leftover count-in beat display when normal ticking begins
    if (_currentCountInBeat != 0) {
      _currentCountInBeat = 0;
    }

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
}
