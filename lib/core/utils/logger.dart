import 'package:flutter/material.dart';

/// Utility class for structured logging throughout the app
class Logger {
  static const String _midiPrefix = '🎹 MIDI';
  static const String _navPrefix = '🎹 NAV';
  static const String _autoscrollPrefix = '🎵 AUTO';
  static const String _setlistPrefix = '📋 SETLIST';
  static const String _errorPrefix = '❌ ERROR';
  static const String _debugPrefix = '🐛 DEBUG';

  /// MIDI-related logging
  static void midi(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_midiPrefix, message, error, stackTrace);
  }

  /// Navigation-related logging
  static void navigation(String message,
      [Object? error, StackTrace? stackTrace]) {
    _log(_navPrefix, message, error, stackTrace);
  }

  /// Autoscroll-related logging
  static void autoscroll(String message,
      [Object? error, StackTrace? stackTrace]) {
    _log(_autoscrollPrefix, message, error, stackTrace);
  }

  /// Setlist-related logging
  static void setlist(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_setlistPrefix, message, error, stackTrace);
  }

  /// Error logging
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_errorPrefix, message, error, stackTrace);
  }

  /// General debug logging
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(_debugPrefix, message, error, stackTrace);
  }

  /// Internal logging method
  static void _log(String prefix, String message,
      [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer('$prefix: $message');

    if (error != null) {
      buffer.write(' - $error');
    }

    debugPrint(buffer.toString());

    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Log method entry for debugging
  static void methodEntry(String className, String methodName,
      [Map<String, dynamic>? params]) {
    final buffer = StringBuffer('🔍 ENTRY: $className.$methodName');
    if (params != null && params.isNotEmpty) {
      buffer.write(' with params: $params');
    }
    debugPrint(buffer.toString());
  }

  /// Log method exit for debugging
  static void methodExit(String className, String methodName,
      [dynamic result]) {
    final buffer = StringBuffer('🔍 EXIT: $className.$methodName');
    if (result != null) {
      buffer.write(' with result: $result');
    }
    debugPrint(buffer.toString());
  }
}
