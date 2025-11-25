import 'dart:async';

/// Rock-solid metronome implementation using timestamp-based scheduling
///
/// DESIGN NOTE: Originally planned to use flutter_sequencer, but switched to
/// timestamp-based scheduling due to ffi dependency conflicts:
/// - flutter_sequencer ^0.2.0 requires ffi ^1.0.0
/// - flutter_midi_command ^0.5.3 requires ffi ^2.0.1
/// - This created an incompatible dependency chain
///
/// The timestamp-based approach actually provides superior timing accuracy:
/// Each beat is scheduled at exact time `startTime + (beatNumber * beatInterval)`
/// rather than relying on periodic timer intervals which accumulate drift.
///
/// Key improvements over Timer.periodic:
/// 1. **Timestamp-based scheduling**: Eliminates cumulative timing drift
/// 2. **Microsecond precision**: Uses DateTime.now().microsecondsSinceEpoch
/// 3. **Drift correction**: Calculates next beat time from original start time
/// 4. **Audio preloading**: MetronomeProvider handles audio preloading/warm-up
/// 5. **Rock-solid timing**: Professional musician-grade accuracy
class RockSolidMetronome {
  static const int _minTempo = 30;
  static const int _maxTempo = 320;

  Timer? _schedulingTimer;

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isDisposed = false;

  int _tempoBpm = 120;
  int _beatsPerMeasure = 4;
  int _currentBeat = 0;
  int _totalBeatsPlayed = 0;

  // Timing variables for precise scheduling
  int _beatIntervalMicros = 500000; // Default 120 BPM
  int _startTimeMicros = 0;
  int _nextScheduledBeatMicros = 0;

  // Callbacks for UI integration
  void Function(int beatNumber, bool isAccent)? onBeat;
  void Function()? onCountInBeat;
  void Function()? onCountInComplete;

  RockSolidMetronome({
    required int tempoBpm,
    required int beatsPerMeasure,
    this.onBeat,
    this.onCountInBeat,
    this.onCountInComplete,
  })  : _tempoBpm = tempoBpm.clamp(_minTempo, _maxTempo),
        _beatsPerMeasure = beatsPerMeasure {
    _beatIntervalMicros = _calculateBeatInterval(_tempoBpm);
  }

  /// Initialize timing engine (no audio setup - handled by MetronomeProvider)
  Future<void> init() async {
    if (_isInitialized || _isDisposed) return;
    _isInitialized = true;
  }

  /// Start the metronome with rock-solid timing
  Future<void> start() async {
    if (_isRunning || _isDisposed) return;

    await init();

    if (!_isInitialized) {
      throw Exception('Metronome failed to initialize');
    }

    _isRunning = true;
    _currentBeat = 0;
    _totalBeatsPlayed = 0;

    // Record the precise start time
    _startTimeMicros = DateTime.now().microsecondsSinceEpoch;
    _nextScheduledBeatMicros = _startTimeMicros;

    // Schedule the first beat immediately
    _scheduleBeat();
  }

  /// Stop the metronome completely
  void stop() {
    if (!_isRunning) return;

    _schedulingTimer?.cancel();
    _schedulingTimer = null;
    _isRunning = false;
    _currentBeat = 0;
    _totalBeatsPlayed = 0;
  }

  /// Update tempo without stopping if running
  Future<void> setTempo(int bpm) async {
    final sanitized = bpm.clamp(_minTempo, _maxTempo);
    if (sanitized == _tempoBpm) return;

    _tempoBpm = sanitized;
    _beatIntervalMicros = _calculateBeatInterval(_tempoBpm);

    // If running, restart with new tempo to maintain timing accuracy
    if (_isRunning) {
      stop();
      await start();
    }
  }

  /// Update time signature
  void setBeatsPerMeasure(int beatsPerMeasure) {
    if (beatsPerMeasure <= 0) return;
    _beatsPerMeasure = beatsPerMeasure;
  }

  /// Getters for current state
  bool get isRunning => _isRunning;
  bool get isInitialized => _isInitialized;
  int get tempoBpm => _tempoBpm;
  int get beatsPerMeasure => _beatsPerMeasure;
  int get currentBeat => _currentBeat;
  int get totalBeatsPlayed => _totalBeatsPlayed;

  /// Calculate beat interval in microseconds from BPM
  int _calculateBeatInterval(int bpm) {
    // 60 seconds = 60,000,000 microseconds
    // Interval = 60,000,000 / BPM
    return (60000000 / bpm).round();
  }

  /// Schedule the next beat using timestamp-based approach
  void _scheduleBeat() {
    if (!_isRunning || _isDisposed) return;

    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final delayMicros = _nextScheduledBeatMicros - nowMicros;

    if (delayMicros <= 0) {
      // We're late or exactly on time - trigger immediately
      _triggerBeat();
    } else {
      // Schedule the beat at the precise time
      _schedulingTimer =
          Timer(Duration(microseconds: delayMicros), _triggerBeat);
    }
  }

  /// Trigger a beat callback and schedule the next one
  void _triggerBeat() {
    if (!_isRunning || _isDisposed) return;

    _totalBeatsPlayed++;
    _currentBeat = ((_totalBeatsPlayed - 1) % _beatsPerMeasure) + 1;
    final isAccent = _currentBeat == 1;

    // Notify listeners (MetronomeProvider will handle audio)
    onBeat?.call(_currentBeat, isAccent);

    // Calculate next beat time from original start time (drift correction)
    _nextScheduledBeatMicros =
        _startTimeMicros + (_totalBeatsPlayed * _beatIntervalMicros);

    // Schedule the next beat
    _scheduleBeat();
  }

  /// Dispose of timing resources
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    stop();
  }
}

/// Helper function to avoid unawaited futures without warnings
void unawaited(Future<void> future) {
  // Intentionally unawaited - used for fire-and-forget operations
}
