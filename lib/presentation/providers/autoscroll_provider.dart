import 'package:flutter/material.dart';
import 'dart:async';
import '../../main.dart' as main;
import '../../core/utils/chordpro_parser.dart';
import '../../core/constants/song_viewer_constants.dart';
import 'metronome_provider.dart';
import 'metronome_settings_provider.dart';

class AutoscrollProvider extends ChangeNotifier {
  static const int _defaultDurationSeconds = 180; // 3:00 default

  bool _isActive = false;
  Timer? _resumeTimer;
  ScrollController? _scrollController;
  double _totalScrollExtent = 0.0;
  int _durationSeconds = _defaultDurationSeconds;
  int _originalDurationSeconds = _defaultDurationSeconds;
  bool _isUserScrolling = false;
  DateTime? _autoscrollStartTime;
  DateTime? _autoscrollEndTime;
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
  }

  // Start autoscrolling
  void start() {
    main.myDebug('AutoscrollProvider.start called');
    if (_scrollController == null || !_scrollController!.hasClients) {
      main.myDebug('AutoscrollProvider.start aborted: no scroll clients');
      return;
    }

    // Reset timing for a fresh autoscroll run
    _autoscrollStartTime = null;
    _autoscrollEndTime = null;

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
    main.myDebug('AutoscrollProvider.stop called');

    // Cancel any in-flight scroll animation by snapping to the current offset.
    if (_scrollController != null && _scrollController!.hasClients) {
      final currentOffset = _scrollController!.offset;
      _scrollController!.jumpTo(currentOffset);
      main.myDebug(
          'AutoscrollProvider.stop: cancelled animation at offset=$currentOffset');
    }

    _isActive = false;
    _isCountingIn = false;
    _resumeTimer?.cancel();
    _autoscrollStartTime = null;
    _autoscrollEndTime = null;
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
        _restartFromCurrentPositionWithNewDuration();
      }

      notifyListeners();
    }
  }

  /// Handle user-driven scroll activity (wired from UserScrollNotification
  /// in the SongViewerScreen). This debounces autoscroll resume so that any
  /// user scroll pauses the animation and restarts it 2 seconds after the
  /// last scroll notification.
  void handleUserScrollActivity() {
    if (_scrollController == null || !_isActive) return;

    if (!_isUserScrolling) {
      _isUserScrolling = true;
      main.myDebug(
          'AutoscrollProvider.handleUserScrollActivity: user scroll started, offset=${_scrollController!.offset}');
    }

    _resumeTimer?.cancel();
    main.myDebug(
        'AutoscrollProvider.handleUserScrollActivity: scheduling resume timer');
    _resumeTimer = Timer(const Duration(seconds: 2), () {
      _isUserScrolling = false;
      if (_isActive) {
        main.myDebug(
            'AutoscrollProvider.handleUserScrollActivity resume timer fired; restarting autoscroll with preserved speed');
        _restartFromCurrentPositionPreservingSpeed();
      }
    });
  }

  // Reset duration to original value from song metadata
  void resetDuration() {
    _durationSeconds = _originalDurationSeconds;

    if (_isActive) {
      _restartFromCurrentPositionWithNewDuration();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
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

    // Initialize timing window if this is the first start for this run
    final now = DateTime.now();
    _autoscrollStartTime ??= now;
    _autoscrollEndTime ??=
        _autoscrollStartTime!.add(Duration(seconds: _durationSeconds));
    main.myDebug(
        'AutoscrollProvider._startScrolling: offset=${_scrollController!.offset}, total=$_totalScrollExtent, endTime=$_autoscrollEndTime');

    _performScrollStart();
    notifyListeners();
  }

  // Perform the actual scroll start logic
  void _performScrollStart() {
    if (_totalScrollExtent <= 0 || _autoscrollEndTime == null) return;

    // If we've already reached or passed the planned end time, jump to the end
    // and stop autoscroll.
    final now = DateTime.now();
    var remaining = _autoscrollEndTime!.difference(now);
    if (remaining <= Duration.zero) {
      if (_scrollController != null && _scrollController!.hasClients) {
        _scrollController!.jumpTo(_totalScrollExtent);
      }
      stop();
      return;
    }

    // Ensure a minimum duration to avoid extremely fast jumps if we're very
    // close to the planned end time.
    const minDuration = Duration(milliseconds: 300);
    if (remaining < minDuration) {
      remaining = minDuration;
    }

    if (_scrollController != null && _scrollController!.hasClients) {
      main.myDebug(
          'AutoscrollProvider._performScrollStart: animating to end=$_totalScrollExtent over ${remaining.inMilliseconds}ms from offset=${_scrollController!.offset}');
      _scrollController!.animateTo(
        _totalScrollExtent,
        duration: remaining,
        curve: Curves.linear,
      );
    }
  }

  // Restart autoscroll timing from the current position with the current
  // duration setting. Used when the user adjusts duration while autoscroll is
  // active or when we reset to the original duration.
  void _restartFromCurrentPositionWithNewDuration() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    if (_totalScrollExtent <= 0 || _durationSeconds <= 0) return;

    _calculateScrollExtent();

    final currentOffset = _scrollController!.offset;
    final remainingDistance = _totalScrollExtent - currentOffset;
    if (remainingDistance <= 0) {
      stop();
      return;
    }

    // New scroll speed in pixels per second based on the updated duration.
    final pixelsPerSecond = _totalScrollExtent / _durationSeconds;
    var remainingSeconds = remainingDistance / pixelsPerSecond;

    // Enforce a minimum remaining duration to avoid abrupt jumps.
    const minSeconds = 0.3; // 300ms
    if (remainingSeconds < minSeconds) {
      remainingSeconds = minSeconds;
    }

    final now = DateTime.now();
    _autoscrollStartTime = now;
    _autoscrollEndTime =
        now.add(Duration(milliseconds: (remainingSeconds * 1000).round()));

    main.myDebug(
        'AutoscrollProvider._restartFromCurrentPositionWithNewDuration: offset=$currentOffset, remainingDistance=$remainingDistance, pixelsPerSecond=$pixelsPerSecond, remainingSeconds=$remainingSeconds, newEndTime=$_autoscrollEndTime');

    _performScrollStart();
  }

  // Restart autoscroll from the current position but preserve the original
  // scroll speed (pixels per second). This is used when resuming after a
  // manual user scroll so that the scroll rate feels consistent regardless
  // of where the user repositioned the view.
  void _restartFromCurrentPositionPreservingSpeed() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    if (_totalScrollExtent <= 0 || _durationSeconds <= 0) return;

    _calculateScrollExtent();

    final currentOffset = _scrollController!.offset;
    final remainingDistance = _totalScrollExtent - currentOffset;
    if (remainingDistance <= 0) {
      stop();
      return;
    }

    // Original scroll speed in pixels per second based on the full run.
    final pixelsPerSecond = _totalScrollExtent / _durationSeconds;
    var remainingSeconds = remainingDistance / pixelsPerSecond;

    // Enforce a minimum remaining duration to avoid abrupt jumps.
    const minSeconds = 0.3; // 300ms
    if (remainingSeconds < minSeconds) {
      remainingSeconds = minSeconds;
    }

    final now = DateTime.now();
    _autoscrollStartTime = now;
    _autoscrollEndTime =
        now.add(Duration(milliseconds: (remainingSeconds * 1000).round()));

    main.myDebug(
        'AutoscrollProvider._restartFromCurrentPositionPreservingSpeed: offset=$currentOffset, remainingDistance=$remainingDistance, pixelsPerSecond=$pixelsPerSecond, remainingSeconds=$remainingSeconds, newEndTime=$_autoscrollEndTime');

    _performScrollStart();
  }
}
