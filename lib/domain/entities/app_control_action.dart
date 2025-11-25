import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Complete list of available app control actions in the correct order
/// This variable is stored for future use when implementing action functionality
const List<AppControlActionType> availableAppControlActions = [
  AppControlActionType.previousSong,
  AppControlActionType.nextSong,
  AppControlActionType.previousSection,
  AppControlActionType.nextSection,
  AppControlActionType.scrollUp,
  AppControlActionType.scrollDown,
  AppControlActionType.scrollToTop,
  AppControlActionType.scrollToBottom,
  AppControlActionType.startMetronome,
  AppControlActionType.stopMetronome,
  AppControlActionType.toggleMetronome,
  AppControlActionType.repeatCountIn,
  AppControlActionType.startAutoscroll,
  AppControlActionType.stopAutoscroll,
  AppControlActionType.toggleAutoscroll,
  AppControlActionType.autoscrollSpeedFaster,
  AppControlActionType.autoscrollSpeedSlower,
  AppControlActionType.toggleSidebar,
  AppControlActionType.transposeUp,
  AppControlActionType.transposeDown,
  AppControlActionType.capoUp,
  AppControlActionType.capoDown,
  AppControlActionType.zoomIn,
  AppControlActionType.zoomOut,
];

/// Types of actions that can be triggered by MIDI events or pedal inputs
enum AppControlActionType {
  // Song navigation
  previousSong,
  nextSong,

  // Song section navigation
  previousSection,
  nextSection,

  // Viewer scrolling
  scrollUp,
  scrollDown,
  scrollToTop,
  scrollToBottom,

  // Metronome control
  startMetronome,
  stopMetronome,
  toggleMetronome,
  repeatCountIn,

  // Autoscroll control
  startAutoscroll,
  stopAutoscroll,
  toggleAutoscroll,
  autoscrollSpeedFaster,
  autoscrollSpeedSlower,

  // App control
  toggleSidebar,

  // Music control
  transposeUp,
  transposeDown,
  capoUp,
  capoDown,

  // Display control
  zoomIn,
  zoomOut,
}

/// Parameters for an app control action
class AppControlActionParams extends Equatable {
  final Map<String, dynamic> values;

  const AppControlActionParams({this.values = const {}});

  /// Create params for setTempo action
  factory AppControlActionParams.tempo(int bpm) {
    return AppControlActionParams(values: {'bpm': bpm});
  }

  /// Create params for scroll actions
  factory AppControlActionParams.scroll({
    int amount = 1,
    bool smooth = true,
  }) {
    return AppControlActionParams(values: {
      'amount': amount,
      'smooth': smooth,
    });
  }

  /// Create params for MIDI send actions
  factory AppControlActionParams.midiSend({
    required int channel,
    required int number,
    int? value,
    String? deviceId,
  }) {
    return AppControlActionParams(values: {
      'channel': channel,
      'number': number,
      'value': value,
      'deviceId': deviceId,
    });
  }

  /// Get a parameter value
  T? get<T>(String key) {
    return values[key] as T?;
  }

  /// Check if a parameter exists
  bool has(String key) {
    return values.containsKey(key);
  }

  @override
  List<Object?> get props => [values];
}

/// Complete app control action with type and parameters
class AppControlAction extends Equatable {
  final AppControlActionType type;
  final AppControlActionParams params;

  const AppControlAction({
    required this.type,
    this.params = const AppControlActionParams(),
  });

  /// Create action from JSON (for database storage)
  factory AppControlAction.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String;
    final type = AppControlActionType.values.firstWhere(
      (e) => e.toString() == 'AppControlActionType.$typeString',
      orElse: () => AppControlActionType.nextSong, // Default fallback
    );

    final paramsJson = json['params'] as Map<String, dynamic>? ?? {};
    final params = AppControlActionParams(values: paramsJson);

    return AppControlAction(type: type, params: params);
  }

  /// Convert to JSON (for database storage)
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'params': params.values,
    };
  }

  /// Create action from legacy pedal mapping format
  factory AppControlAction.fromLegacyJson(String actionJson) {
    try {
      final Map<String, dynamic> json =
          jsonDecode(actionJson) as Map<String, dynamic>;

      // Map legacy action names to new enum values
      final typeString = json['type'] as String?;
      switch (typeString) {
        case 'previousSong':
          return const AppControlAction(
              type: AppControlActionType.previousSong);
        case 'nextSong':
          return const AppControlAction(type: AppControlActionType.nextSong);
        case 'previousSection':
          return const AppControlAction(
              type: AppControlActionType.previousSection);
        case 'nextSection':
          return const AppControlAction(type: AppControlActionType.nextSection);
        case 'scrollUp':
          return const AppControlAction(type: AppControlActionType.scrollUp);
        case 'scrollDown':
          return const AppControlAction(type: AppControlActionType.scrollDown);
        case 'scrollToTop':
          return const AppControlAction(type: AppControlActionType.scrollToTop);
        case 'scrollToBottom':
          return const AppControlAction(
              type: AppControlActionType.scrollToBottom);
        case 'startMetronome':
          return const AppControlAction(
              type: AppControlActionType.startMetronome);
        case 'stopMetronome':
          return const AppControlAction(
              type: AppControlActionType.stopMetronome);
        case 'toggleMetronome':
          return const AppControlAction(
              type: AppControlActionType.toggleMetronome);
        case 'repeatCountIn':
          return const AppControlAction(
              type: AppControlActionType.repeatCountIn);
        case 'startAutoscroll':
          return const AppControlAction(
              type: AppControlActionType.startAutoscroll);
        case 'stopAutoscroll':
          return const AppControlAction(
              type: AppControlActionType.stopAutoscroll);
        case 'toggleAutoscroll':
          return const AppControlAction(
              type: AppControlActionType.toggleAutoscroll);
        case 'autoscrollSpeedFaster':
          return const AppControlAction(
              type: AppControlActionType.autoscrollSpeedFaster);
        case 'autoscrollSpeedSlower':
          return const AppControlAction(
              type: AppControlActionType.autoscrollSpeedSlower);
        case 'toggleSidebar':
          return const AppControlAction(
              type: AppControlActionType.toggleSidebar);
        case 'transposeUp':
          return const AppControlAction(type: AppControlActionType.transposeUp);
        case 'transposeDown':
          return const AppControlAction(
              type: AppControlActionType.transposeDown);
        case 'capoUp':
          return const AppControlAction(type: AppControlActionType.capoUp);
        case 'capoDown':
          return const AppControlAction(type: AppControlActionType.capoDown);
        case 'zoomIn':
          return const AppControlAction(type: AppControlActionType.zoomIn);
        case 'zoomOut':
          return const AppControlAction(type: AppControlActionType.zoomOut);
        default:
          return const AppControlAction(type: AppControlActionType.nextSong);
      }
    } catch (e) {
      // Fallback to a safe default action
      return const AppControlAction(type: AppControlActionType.nextSong);
    }
  }

  /// Get a human-readable description of the action
  String get description {
    switch (type) {
      case AppControlActionType.previousSong:
        return 'Previous Song';
      case AppControlActionType.nextSong:
        return 'Next Song';
      case AppControlActionType.previousSection:
        return 'Previous Section';
      case AppControlActionType.nextSection:
        return 'Next Section';
      case AppControlActionType.scrollUp:
        final amount = params.get<int>('amount') ?? 1;
        return 'Scroll Up${amount > 1 ? ' ($amount lines)' : ''}';
      case AppControlActionType.scrollDown:
        final amount = params.get<int>('amount') ?? 1;
        return 'Scroll Down${amount > 1 ? ' ($amount lines)' : ''}';
      case AppControlActionType.scrollToTop:
        return 'Scroll to Top';
      case AppControlActionType.scrollToBottom:
        return 'Scroll to Bottom';
      case AppControlActionType.startMetronome:
        return 'Start Metronome';
      case AppControlActionType.stopMetronome:
        return 'Stop Metronome';
      case AppControlActionType.toggleMetronome:
        return 'Toggle Metronome';
      case AppControlActionType.repeatCountIn:
        return 'Repeat Count-In';
      case AppControlActionType.startAutoscroll:
        return 'Start Auto-scroll';
      case AppControlActionType.stopAutoscroll:
        return 'Stop Auto-scroll';
      case AppControlActionType.toggleAutoscroll:
        return 'Toggle Auto-scroll';
      case AppControlActionType.autoscrollSpeedFaster:
        return 'Autoscroll Speed Faster';
      case AppControlActionType.autoscrollSpeedSlower:
        return 'Autoscroll Speed Slower';
      case AppControlActionType.toggleSidebar:
        return 'Toggle Sidebar';
      case AppControlActionType.transposeUp:
        return 'Transpose Up';
      case AppControlActionType.transposeDown:
        return 'Transpose Down';
      case AppControlActionType.capoUp:
        return 'Capo Up';
      case AppControlActionType.capoDown:
        return 'Capo Down';
      case AppControlActionType.zoomIn:
        return 'Zoom In';
      case AppControlActionType.zoomOut:
        return 'Zoom Out';
    }
  }

  @override
  List<Object?> get props => [type, params];

  @override
  String toString() {
    return 'AppControlAction($type, params: ${params.values})';
  }
}
