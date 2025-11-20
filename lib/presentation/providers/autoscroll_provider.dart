import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/utils/chordpro_parser.dart';

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

  // Calculate the total scrollable extent
  void _calculateScrollExtent() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    _totalScrollExtent = _scrollController!.position.maxScrollExtent;
    _currentScrollOffset = _scrollController!.offset;
  }

  // Start autoscrolling
  void start() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    _isActive = true;
    _calculateScrollExtent();
    _startScrolling();
    notifyListeners();
  }

  // Stop autoscrolling
  void stop() {
    _isActive = false;
    _scrollTimer?.cancel();
    _resumeTimer?.cancel();
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

  // Start the actual scrolling animation
  void _startScrolling() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    _calculateScrollExtent();

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
}
