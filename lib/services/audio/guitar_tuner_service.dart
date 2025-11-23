import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, ChangeNotifier;
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitchupdart/instrument_type.dart';
import 'package:pitchupdart/pitch_handler.dart';

/// Guitar tuning data for standard tuning (E-A-D-G-B-E)
class GuitarString {
  final String name;
  final double frequency;
  final int stringNumber; // 1-6, where 1 is high E

  const GuitarString({
    required this.name,
    required this.frequency,
    required this.stringNumber,
  });
}

/// Tuning result containing frequency analysis
class TuningResult {
  final double detectedFrequency;
  final GuitarString? closestString;
  final double centsOff; // Positive = sharp, negative = flat
  final double confidence; // 0.0 to 1.0
  final bool isInTune; // Within acceptable range

  const TuningResult({
    required this.detectedFrequency,
    this.closestString,
    required this.centsOff,
    required this.confidence,
    required this.isInTune,
  });
}

/// Service for guitar tuning functionality with real-time audio analysis
class GuitarTunerService extends ChangeNotifier {
  static final GuitarTunerService _instance = GuitarTunerService._internal();
  factory GuitarTunerService() => _instance;
  GuitarTunerService._internal();

  // Standard guitar tuning frequencies (Hz)
  static const List<GuitarString> standardTuning = [
    GuitarString(name: 'E', frequency: 82.41, stringNumber: 6), // Low E
    GuitarString(name: 'A', frequency: 110.00, stringNumber: 5),
    GuitarString(name: 'D', frequency: 146.83, stringNumber: 4),
    GuitarString(name: 'G', frequency: 196.00, stringNumber: 3),
    GuitarString(name: 'B', frequency: 246.94, stringNumber: 2),
    GuitarString(name: 'E', frequency: 329.63, stringNumber: 1), // High E
  ];

  // Audio analysis parameters
  static const int sampleRate = 44100;
  static const int bufferSize =
      2048; // Smaller buffer for better responsiveness
  static const double tuningTolerance = 10.0; // cents

  // State variables
  bool _isListening = false;
  bool _hasPermission = false;
  TuningResult? _currentResult;
  String? _errorMessage;

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Pitch detection
  PitchDetector? _pitchDetector;
  PitchHandler? _pitchHandler;
  final List<int> _audioBuffer = [];

  // Smoothing for stable readings
  final List<double> _frequencyHistory = [];
  final List<double> _centsHistory = [];
  static const int _smoothingWindowSize = 5;

  // Getters
  bool get isListening => _isListening;
  bool get hasPermission => _hasPermission;
  TuningResult? get currentResult => _currentResult;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    stopListening();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// Initialize the tuner service
  Future<bool> initialize() async {
    try {
      // Initialize pitch detector
      _pitchDetector = PitchDetector(
        audioSampleRate: 44100.0,
        bufferSize: 2048,
      );

      // Initialize pitch handler for guitar
      _pitchHandler = PitchHandler(InstrumentType.guitar);

      // Request permissions
      await _requestPermissions();

      notifyListeners();
      return _hasPermission;
    } catch (e) {
      _errorMessage = 'Failed to initialize tuner: $e';
      debugPrint('Tuner initialization error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Request microphone permissions
  Future<void> _requestPermissions() async {
    try {
      // Check if we have permission
      final hasPermission = await _audioRecorder.hasPermission();
      _hasPermission = hasPermission;

      if (_hasPermission) {
        _errorMessage = null;
      } else {
        _errorMessage =
            'Microphone permission denied. Please grant permission in System Preferences.';
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Permission check failed: $e');
      _hasPermission = false;
      _errorMessage = 'Failed to check microphone permission: $e';
      notifyListeners();
    }
  }

  /// Start listening for audio input
  Future<bool> startListening() async {
    if (_isListening) return true;

    // Check permissions
    if (!_hasPermission) {
      await _requestPermissions();
      if (!_hasPermission) {
        _errorMessage = 'Microphone permission denied. Cannot start tuner.';
        notifyListeners();
        return false;
      }
    }

    try {
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      // Start streaming audio
      final stream = await _audioRecorder.startStream(config);
      _audioStreamSubscription = stream.listen(
        _processAudioData,
        onError: (error) {
          _errorMessage = 'Audio recording error: $error';
          notifyListeners();
        },
      );

      _isListening = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start audio recording: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stop listening for audio input
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      // Cancel stream subscription
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // Stop recorder
      await _audioRecorder.stop();

      _isListening = false;
      _currentResult = null;
      _audioBuffer.clear();
      _frequencyHistory.clear();
      _centsHistory.clear();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error stopping audio recording: $e';
      notifyListeners();
    }
  }

  /// Process incoming audio data from the stream
  void _processAudioData(Uint8List audioData) {
    try {
      // Add raw audio data to buffer
      _audioBuffer.addAll(audioData);

      // Process when we have enough samples for pitch detection
      // For 16-bit audio at 44100 Hz, we need bufferSize * 2 bytes
      final requiredBytes = 2048 * 2;

      if (_audioBuffer.length >= requiredBytes) {
        // Take the most recent samples for analysis
        final analysisBuffer = Uint8List.fromList(
          _audioBuffer.sublist(
            _audioBuffer.length - requiredBytes,
            _audioBuffer.length,
          ),
        );

        // Analyze pitch
        _analyzePitch(analysisBuffer);

        // Keep buffer size manageable
        if (_audioBuffer.length > bufferSize * 4) {
          _audioBuffer.removeRange(0, _audioBuffer.length - requiredBytes);
        }
      }
    } catch (e) {
      debugPrint('Audio processing error: $e');
    }
  }

  /// Analyze pitch using pitch detection libraries
  Future<void> _analyzePitch(Uint8List audioData) async {
    try {
      if (_pitchDetector == null || _pitchHandler == null) {
        return;
      }

      // Detect pitch from audio data
      final pitchResult =
          await _pitchDetector!.getPitchFromIntBuffer(audioData);

      if (pitchResult.pitched && pitchResult.pitch > 0) {
        final detectedFrequency = pitchResult.pitch;

        // Find closest guitar string
        final closestString = _findClosestString(detectedFrequency);

        // Calculate cents difference
        final centsOff =
            _calculateCents(detectedFrequency, closestString.frequency);

        // Apply smoothing
        final smoothedResult = _applySmoothingToResult(detectedFrequency,
            centsOff, closestString, pitchResult.probability);

        if (smoothedResult != null) {
          _currentResult = smoothedResult;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Pitch analysis error: $e');
    }
  }

  /// Find the closest guitar string to a given frequency
  GuitarString _findClosestString(double frequency) {
    GuitarString closest = standardTuning.first;
    double minDifference = double.infinity;

    for (final string in standardTuning) {
      final difference = (frequency - string.frequency).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closest = string;
      }
    }

    return closest;
  }

  /// Calculate cents difference between two frequencies
  double _calculateCents(double frequency1, double frequency2) {
    return 1200 * log(frequency1 / frequency2) / log(2);
  }

  /// Apply smoothing to reduce jumpiness in tuner readings
  TuningResult? _applySmoothingToResult(double frequency, double centsOff,
      GuitarString closestString, double confidence) {
    // Add new readings to history
    _frequencyHistory.add(frequency);
    _centsHistory.add(centsOff);

    // Keep history within window size
    if (_frequencyHistory.length > _smoothingWindowSize) {
      _frequencyHistory.removeAt(0);
    }
    if (_centsHistory.length > _smoothingWindowSize) {
      _centsHistory.removeAt(0);
    }

    // Need at least 3 readings for smoothing
    if (_frequencyHistory.length < 3) {
      return null;
    }

    // Calculate smoothed values using weighted average (recent readings have more weight)
    double smoothedFrequency = 0;
    double smoothedCents = 0;
    double totalWeight = 0;

    for (int i = 0; i < _frequencyHistory.length; i++) {
      final weight = (i + 1).toDouble(); // More recent = higher weight
      smoothedFrequency += _frequencyHistory[i] * weight;
      smoothedCents += _centsHistory[i] * weight;
      totalWeight += weight;
    }

    smoothedFrequency /= totalWeight;
    smoothedCents /= totalWeight;

    // Check if in tune with smoothed values
    final isInTune = smoothedCents.abs() <= tuningTolerance;

    return TuningResult(
      detectedFrequency: smoothedFrequency,
      closestString: closestString,
      centsOff: smoothedCents,
      confidence: confidence,
      isInTune: isInTune,
    );
  }
}
