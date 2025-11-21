import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/utils/chordpro_parser.dart';
import 'metronome_provider.dart';
import 'metronome_settings_provider.dart';

class AutoscrollProvider extends ChangeNotifier {
  static const int _defaultDurationSeconds = 180; // 3:00 default

  bool _isActive = false;
  Timer? _scrollTimer;
  Timer? _resumeTimer;
  ScrollController? _scrollController;
  double _totalScrollExtent = 0.0;
  double _currentScrollOffset = 0.0;
  int _durationSeconds = _defaultDurationSeconds;
  int _originalDurationSeconds = _defaultDurationSeconds;
  bool _isUserScrolling = false;
  MetronomeProvider? _metronomeProvider;
  MetronomeSettingsProvider? _settingsProvider;
  bool _isCountingIn = false;

  // Getters
  bool get isActive => _isActive;
  int get durationSeconds => _durationSeconds;
  String get durationDisplay {
    final minutes = _durationSeconds ~/ 60;
    final seconds = _durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Initialize with a song's duration from metadata
  void initialize(String chordProBody) {
    final metadata = ChordProParser.extractMetadata(chordProBody);
    _durationSeconds = metadata.durationInSeconds ?? _defaultDurationSeconds;
    _originalDurationSeconds = _durationSeconds;
  }

  // Set the scroll controller for the viewer
  void setScrollController(ScrollController controller) {
    _scrollController = controller;

    // Listen for user scroll events
    controller.addListener(_onUserScroll);

    // Calculate total scroll extent when layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateScrollExtent();
    });
  }

  // Set metronome providers for count-in integration
  void setMetronomeProviders(MetronomeProvider metronomeProvider,
      MetronomeSettingsProvider settingsProvider) {
    _metronomeProvider = metronomeProvider;
    _settingsProvider = settingsProvider;
  }

  // Calculate the total scrollable extent
  void _calculateScrollExtent() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    _totalScrollExtent = _scrollController!.position.maxScrollExtent;
    _currentScrollOffset = _scrollController!.offset;
  }

  // Start autoscrolling
  void start() {
    debugPrint('🔧 AUTOSCROLL DEBUG: start() called');
    if (_scrollController == null || !_scrollController!.hasClients) {
      debugPrint('🔧 AUTOSCROLL DEBUG: No scroll controller or clients');
      return;
    }

    // Check if we should do count-in
    final shouldCountIn = _shouldDoCountIn();
    debugPrint('🔧 AUTOSCROLL DEBUG: shouldDoCountIn: $shouldCountIn');

    if (shouldCountIn) {
      debugPrint('🔧 AUTOSCROLL DEBUG: Starting count-in');
      _startCountIn();
    } else {
      debugPrint('🔧 AUTOSCROLL DEBUG: Skipping count-in, starting scrolling');
      _startScrolling();
    }
  }

  // Stop autoscrolling
  void stop() {
    debugPrint(
        '🔧 AUTOSCROLL DEBUG: stop() called - _isActive: $_isActive, _isCountingIn: $_isCountingIn');
    _isActive = false;
    _isCountingIn = false;
    _scrollTimer?.cancel();
    _resumeTimer?.cancel();
    _metronomeProvider?.stop();
    notifyListeners();
  }

  // Toggle autoscroll on/off
  void toggle() {
    if (_isActive) {
      stop();
    } else {
      start();
    }
  }

  // Adjust duration by delta seconds
  void adjustDuration(int deltaSeconds) {
    final newDuration = (_durationSeconds + deltaSeconds)
        .clamp(30, 600); // 30 seconds to 10 minutes
    if (newDuration != _durationSeconds) {
      _durationSeconds = newDuration;

      // If currently scrolling, restart with new duration
      if (_isActive) {
        _scrollTimer?.cancel();
        _startScrolling();
      }

      notifyListeners();
    }
  }

  // Handle user scroll events
  void _onUserScroll() {
    if (_scrollController == null || !_isActive) return;

    final isScrolling = _scrollController!.position.isScrollingNotifier.value;

    if (isScrolling && !_isUserScrolling) {
      // User started scrolling - pause autoscroll
      _isUserScrolling = true;
      _scrollTimer?.cancel();
    } else if (!isScrolling && _isUserScrolling) {
      // User stopped scrolling - start resume timer
      _isUserScrolling = false;
      _currentScrollOffset = _scrollController!.offset;

      // Resume autoscroll after 2 seconds
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 2), () {
        if (_isActive && !_isUserScrolling) {
          _startScrolling();
        }
      });
    }
  }

  // Reset duration to original value from song metadata
  void resetDuration() {
    _durationSeconds = _originalDurationSeconds;

    if (_isActive) {
      _scrollTimer?.cancel();
      _startScrolling();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _resumeTimer?.cancel();
    _scrollController?.removeListener(_onUserScroll);
    super.dispose();
  }

  // Check if count-in should be performed
  bool _shouldDoCountIn() {
    debugPrint('🔧 AUTOSCROLL DEBUG: _shouldDoCountIn() called');

    if (_metronomeProvider == null || _settingsProvider == null) {
      debugPrint(
          '🔧 AUTOSCROLL DEBUG: Missing providers - metronome: ${_metronomeProvider != null}, settings: ${_settingsProvider != null}');
      return false;
    }

    // If autoscroll is already running, bypass count-in and just start metronome
    if (_isActive) {
      debugPrint(
          '🔧 AUTOSCROLL DEBUG: Autoscroll already active - bypassing count-in');
      return false;
    }

    // Check if count-in is enabled (not set to Off)
    final countInMeasures = _settingsProvider!.countInMeasures;
    debugPrint('🔧 AUTOSCROLL DEBUG: countInMeasures: $countInMeasures');
    if (countInMeasures == 0) {
      debugPrint('🔧 AUTOSCROLL DEBUG: Count-in disabled (0 measures)');
      return false;
    }

    // Check if scroll position is at the beginning (within 50 pixels)
    if (_scrollController != null && _scrollController!.hasClients) {
      final currentOffset = _scrollController!.offset;
      debugPrint('🔧 AUTOSCROLL DEBUG: currentOffset: $currentOffset');
      return currentOffset <= 50.0;
    }

    debugPrint('🔧 AUTOSCROLL DEBUG: No scroll controller - returning false');
    return false;
  }

  // Start count-in phase
  void _startCountIn() {
    if (_metronomeProvider == null) return;

    _isCountingIn = true;
    // DON'T set _isActive = true yet! This would cause the metronome callback
    // to think autoscroll is already running and bypass the count-in.
    // _isActive will be set to true when count-in completes and scrolling starts.
    notifyListeners();

    // Start metronome count-in
    _metronomeProvider!.start();

    // Listen for metronome count-in completion
    _listenForCountInCompletion();
  }

  // Listen for count-in completion
  void _listenForCountInCompletion() {
    if (_metronomeProvider == null) return;

    debugPrint('🔧 AUTOSCROLL DEBUG: Starting count-in completion listener');
    debugPrint('🔧 AUTOSCROLL DEBUG: _isCountingIn: $_isCountingIn');

    // Check periodically if count-in has finished
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_metronomeProvider == null || !_isCountingIn) {
        debugPrint(
            '🔧 AUTOSCROLL DEBUG: Timer cancelled - metronome null or not counting in');
        timer.cancel();
        return;
      }

      debugPrint(
          '🔧 AUTOSCROLL DEBUG: Checking count-in status - isCountingIn: ${_metronomeProvider!.isCountingIn}, isRunning: ${_metronomeProvider!.isRunning}');

      // Count-in is finished when metronome is no longer counting in
      if (!_metronomeProvider!.isCountingIn) {
        debugPrint('🔧 AUTOSCROLL DEBUG: Count-in finished!');
        timer.cancel();
        _isCountingIn = false;

        // Start scrolling after count-in completes (metronome should be stopped)
        debugPrint('🔧 AUTOSCROLL DEBUG: Starting scrolling after count-in');
        _startScrolling();
      }
    });
  }

  // Start the actual scrolling (called after count-in or directly)
  void _startScrolling() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    _isActive = true;
    _calculateScrollExtent();
    _performScrollStart();
    notifyListeners();
  }

  // Perform the actual scroll start logic
  void _performScrollStart() {
    if (_totalScrollExtent <= 0) return;

    final remainingDistance = _totalScrollExtent - _currentScrollOffset;
    if (remainingDistance <= 0) {
      // Already at the end
      stop();
      return;
    }

    // Calculate scroll rate based on remaining distance and duration
    // We scroll at a constant rate to reach the end in the remaining time
    final scrollRate = remainingDistance / _durationSeconds;

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_scrollController == null || !_scrollController!.hasClients) {
        timer.cancel();
        return;
      }

      final currentOffset = _scrollController!.offset;
      final newOffset =
          currentOffset + (scrollRate * 0.1); // 0.1 seconds per tick

      if (newOffset >= _totalScrollExtent) {
        // Reached the end
        _scrollController!.jumpTo(_totalScrollExtent);
        stop();
      } else {
        _scrollController!.jumpTo(newOffset);
        _currentScrollOffset = newOffset;
      }
    });
  }
}
