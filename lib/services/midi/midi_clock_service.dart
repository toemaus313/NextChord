import 'dart:async';
import 'package:flutter/foundation.dart';
import 'midi_service.dart';

/// Dedicated service for sending MIDI Clock (0xF8) messages at precise intervals
///
/// MIDI CLOCK TIMING: Sends 0xF8 messages 24 times per quarter note at the correct
/// interval derived from BPM. Uses Stopwatch-based drift compensation and self-monitoring
/// to verify actual vs target BPM. Includes automatic correction if timing drifts beyond
/// threshold (±2 BPM by default).
///
/// Formula: intervalMs = 60000 / (bpm * 24)
/// - 120 BPM = 20.83ms between F8 messages
/// - 100 BPM = 25.00ms between F8 messages
/// - 140 BPM = 17.86ms between F8 messages
class MidiClockService with ChangeNotifier {
  static const double _pulsesPerQuarter = 24.0;
  static const double _maxBpmDeviation =
      2.0; // Max allowed deviation before warning
  static const Duration _monitoringWindow =
      Duration(seconds: 1); // Self-monitoring window

  final MidiService _midiService;

  // Timing state
  int _bpm = 120;
  bool _isRunning = false;
  bool _isDisposed = false;

  // Drift compensation timing
  Timer? _clockTimer;
  Stopwatch _stopwatch = Stopwatch();
  double _nextTickTime = 0.0; // Accumulated expected tick times in microseconds
  double _tickIntervalMicros = 0.0; // Interval between ticks in microseconds

  // Self-monitoring
  final List<DateTime> _sentTimestamps = [];
  Timer? _monitoringTimer;
  double _actualBpm = 0.0;
  double _maxDeviationSeen = 0.0;

  // Getters
  int get bpm => _bpm;
  bool get isRunning => _isRunning;
  double get actualBpm => _actualBpm;
  double get maxDeviationSeen => _maxDeviationSeen;

  MidiClockService({required MidiService midiService})
      : _midiService = midiService {
    _updateTickInterval();
  }

  /// Set the BPM and recalculate tick interval
  Future<void> setBpm(int bpm) async {
    if (bpm < 30 || bpm > 320) {
      throw ArgumentError('BPM must be between 30 and 320');
    }

    final wasRunning = _isRunning;
    if (wasRunning) {
      await stop();
    }

    _bpm = bpm;
    _updateTickInterval();

    if (wasRunning) {
      await start();
    }

    notifyListeners();
  }

  /// Start sending MIDI clock messages
  Future<void> start() async {
    if (_isRunning || _isDisposed) return;

    if (!_midiService.isConnected) {
      debugPrint('MidiClockService: Cannot start - no MIDI device connected');
      return;
    }

    _isRunning = true;
    _nextTickTime = 0.0;
    _sentTimestamps.clear();
    _stopwatch.reset();
    _stopwatch.start();

    // Start high-frequency timer for precise timing
    _clockTimer = Timer.periodic(const Duration(milliseconds: 1), _tick);

    // Start self-monitoring timer
    _monitoringTimer =
        Timer.periodic(_monitoringWindow, _performSelfMonitoring);

    debugPrint(
        'MidiClockService: Started at $_bpm BPM (interval: ${_tickIntervalMicros / 1000}ms)');
    notifyListeners();
  }

  /// Stop sending MIDI clock messages
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _clockTimer?.cancel();
    _clockTimer = null;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _stopwatch.stop();
    _sentTimestamps.clear();

    debugPrint('MidiClockService: Stopped');
    notifyListeners();
  }

  /// Update the tick interval based on current BPM
  void _updateTickInterval() {
    // intervalMs = 60000 / (bpm * 24)
    // Convert to microseconds for higher precision
    _tickIntervalMicros = (60000.0 * 1000.0) / (_bpm * _pulsesPerQuarter);
  }

  /// High-frequency tick method that sends F8 when it's time
  void _tick(Timer timer) {
    if (!_isRunning || _isDisposed) return;

    final nowMicros = _stopwatch.elapsedMicroseconds.toDouble();

    // Send multiple ticks if we've fallen behind
    while (nowMicros >= _nextTickTime) {
      _sendMidiClock();
      _sentTimestamps.add(DateTime.now());
      _nextTickTime += _tickIntervalMicros;
    }
  }

  /// Send a single MIDI Clock message (0xF8)
  void _sendMidiClock() async {
    try {
      await _midiService.sendMidiClock();
    } catch (e) {
      debugPrint('MidiClockService: Failed to send MIDI clock: $e');
    }
  }

  /// Perform self-monitoring to check actual BPM vs target
  void _performSelfMonitoring(Timer timer) {
    if (!_isRunning || _isDisposed) return;

    final now = DateTime.now();
    final cutoffTime = now.subtract(_monitoringWindow);

    // Remove timestamps outside the monitoring window
    _sentTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoffTime));

    if (_sentTimestamps.length < 2) {
      _actualBpm = 0.0;
      return;
    }

    // Calculate actual BPM based on messages sent in the last second
    final messagesPerSecond = _sentTimestamps.length.toDouble();
    _actualBpm = (messagesPerSecond * 60.0) / _pulsesPerQuarter;

    // Check for deviation and log warning if needed
    final deviation = (_actualBpm - _bpm).abs();
    if (deviation > _maxDeviationSeen) {
      _maxDeviationSeen = deviation;
    }

    if (deviation > _maxBpmDeviation) {
      debugPrint('MidiClockService: WARNING - Timing deviation detected! '
          'Target: $_bpm BPM, Actual: ${_actualBpm.toStringAsFixed(1)} BPM '
          '(deviation: ${deviation.toStringAsFixed(1)} BPM)');

      // Optional: Apply small correction to bring timing back on target
      _applyTimingCorrection(deviation);
    }

    notifyListeners();
  }

  /// Apply small timing correction to reduce drift
  void _applyTimingCorrection(double deviation) {
    // Apply a tiny correction factor (1-2%) to gradually bring timing back on target
    final correctionFactor = deviation > _maxBpmDeviation * 2 ? 0.98 : 0.99;
    _tickIntervalMicros *= correctionFactor;

    debugPrint(
        'MidiClockService: Applied timing correction factor: $correctionFactor');
  }

  /// Get the current interval between F8 messages in milliseconds
  double get currentIntervalMs => _tickIntervalMicros / 1000.0;

  /// Get the expected interval for a given BPM in milliseconds
  static double getIntervalMsForBpm(int bpm) {
    return 60000.0 / (bpm * _pulsesPerQuarter);
  }

  /// Dispose of the service and clean up resources
  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    stop();
    super.dispose();
  }
}
