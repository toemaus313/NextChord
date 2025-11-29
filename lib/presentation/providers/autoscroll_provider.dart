import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/utils/chordpro_parser.dart';
import '../../core/constants/song_viewer_constants.dart';
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

  // Per-song count-in tracking for MIDI toggle behavior
  bool _hasRunAutoscrollCountIn = false;

  // Getters
  bool get isActive => _isActive;
  int get durationSeconds => _durationSeconds;
  String get durationDisplay {
    final minutes = _durationSeconds ~/ 60;
    final seconds = _durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Initialize with a song's duration. Prefer an explicit override (from
  // Song.duration) and fall back to ChordPro metadata, then default.
  void initialize(String chordProBody, {int? durationSecondsOverride}) {
    if (durationSecondsOverride != null) {
      _durationSeconds = durationSecondsOverride;
      _originalDurationSeconds = _durationSeconds;
    } else {
      final metadata = ChordProParser.extractMetadata(chordProBody);
      _durationSeconds = metadata.durationInSeconds ??
          SongViewerConstants.defaultAutoscrollDuration;
      _originalDurationSeconds = _durationSeconds;
    }

    // Reset count-in state when loading a new song
    _hasRunAutoscrollCountIn = false;
  }

  /// Reset count-in state (call when exiting song or loading different song)
  void resetCountInState() {
    _hasRunAutoscrollCountIn = false;
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
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    // Check if we should do count-in
    final shouldCountIn = _shouldDoCountIn();
    if (shouldCountIn) {
      _startCountIn();
    } else {
      _startScrolling();
    }
  }

  // Stop autoscrolling
  void stop() {
    _isActive = false;
    _isCountingIn = false;
    _scrollTimer?.cancel();
    _resumeTimer?.cancel();
    if (_settingsProvider?.metronomeOnAutoscroll == true) {
      _metronomeProvider?.stop();
    }
    notifyListeners();
  }

  // Toggle autoscroll on/off with MIDI-compatible count-in behavior
  void toggle() {
    if (_isActive) {
      stop();
    } else {
      start();
    }
  }

  /// Toggle autoscroll with MIDI-specific count-in behavior
  void toggleWithMidiBehavior() {
    if (_isActive) {
      stop();
    } else {
      // Check if we should do count-in for MIDI toggle
      final shouldCountIn = _shouldDoCountInForMidi();
      if (shouldCountIn) {
        _startCountIn();
      } else {
        _startScrolling();
      }
    }
  }

  // Check if count-in should be performed for MIDI toggle (first time only)
  bool _shouldDoCountInForMidi() {
    if (_metronomeProvider == null || _settingsProvider == null) {
      return false;
    }

    // Only perform metronome-driven count-in when explicitly enabled
    if (!_settingsProvider!.metronomeOnAutoscroll) {
      return false;
    }

    // If autoscroll is already running, bypass count-in
    if (_isActive) {
      return false;
    }

    // If we've already run count-in for this song, don't run it again
    if (_hasRunAutoscrollCountIn) {
      return false;
    }

    // Check if count-in is enabled (not set to Off)
    final countInMeasures = _settingsProvider!.countInMeasures;
    if (countInMeasures == 0) {
      return false;
    }

    // Check if scroll position is at the beginning (within 50 pixels)
    if (_scrollController != null && _scrollController!.hasClients) {
      final currentOffset = _scrollController!.offset;
      return currentOffset <= 50.0;
    }

    return false;
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
    if (_metronomeProvider == null || _settingsProvider == null) {
      return false;
    }

    // Only perform metronome-driven count-in when explicitly enabled
    if (!_settingsProvider!.metronomeOnAutoscroll) {
      return false;
    }

    // If autoscroll is already running, bypass count-in and just start metronome
    if (_isActive) {
      return false;
    }

    // Check if count-in is enabled (not set to Off)
    final countInMeasures = _settingsProvider!.countInMeasures;
    if (countInMeasures == 0) {
      return false;
    }

    // Check if scroll position is at the beginning (within 50 pixels)
    if (_scrollController != null && _scrollController!.hasClients) {
      final currentOffset = _scrollController!.offset;
      return currentOffset <= 50.0;
    }

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

    // Listen for metronome count-in start to begin scrolling
    _listenForCountInStart();
  }

  // Listen for count-in start (first beat of count-in)
  void _listenForCountInStart() {
    if (_metronomeProvider == null) return;

    // Check periodically until metronome enters count-in phase
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_metronomeProvider == null || !_isCountingIn) {
        timer.cancel();
        return;
      }

      // Count-in has started when metronome reports it is counting in
      if (_metronomeProvider!.isCountingIn) {
        timer.cancel();
        _isCountingIn = false;

        // Start scrolling aligned with the beginning of the count-in
        _startScrolling();
      }
    });
  }

  // Start the actual scrolling (called after count-in or directly)
  void _startScrolling() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    _isActive = true;
    _calculateScrollExtent();

    // Mark that count-in has been run for this song
    _hasRunAutoscrollCountIn = true;

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
