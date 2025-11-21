import 'package:flutter/material.dart';

/// Constants for the Song Viewer screen
class SongViewerConstants {
  // Font size constraints
  static const double minFontSize = 12.0;
  static const double maxFontSize = 48.0;
  static const double defaultFontSize = 18.0;

  // Transpose constraints
  static const int minTranspose = -12;
  static const int maxTranspose = 12;

  // Capo constraints
  static const int minCapo = 0;
  static const int maxCapo = 12;

  // Colors
  static const Color sidebarTopColor = Color(0xFF0468cc);
  static const Color glowColor = Color(0xFF00D9FF);
  static const Color darkModeAccent = Color(0xFF00D9FF);
  static const Color lightModeAccent = Color(0xFF0468cc);

  // Gesture thresholds
  static const double swipeVelocityThreshold = 300.0;
  static const double pinchZoomSensitivity = 0.05;
  static const double scrollZoomSensitivity = 0.05;

  // Animation durations
  static const Duration flyoutAnimationDuration = Duration(milliseconds: 200);
  static const Duration scrollAnimationDuration = Duration(milliseconds: 300);
  static const Duration metronomeFlashDuration = Duration(milliseconds: 80);

  // Layout constants
  static const double flyoutWidth = 220.0;
  static const double flyoutHeight = 40.0;
  static const double flyoutExtendedWidth = 148.0;
  static const double buttonSize = 40.0;
  static const double buttonSpacing = 12.0;
  static const double headerPadding = 60.0;
  static const double contentPadding = 16.0;

  // Autoscroll constraints
  static const int minAutoscrollDuration = 30;
  static const int maxAutoscrollDuration = 600;
  static const int defaultAutoscrollDuration = 180;
  static const int autoscrollAdjustmentStep = 15;

  // MIDI timing
  static const int midiClockStreamDuration = 10;
  static const int midiControlChangeDelay = 100;

  // Instrument tags for special coloring
  static const Set<String> instrumentTags = {
    'Acoustic',
    'Electric',
    'Piano',
    'Guitar',
    'Bass',
    'Drums',
    'Vocals',
    'Instrumental',
  };
}
