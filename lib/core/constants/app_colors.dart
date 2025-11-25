import 'package:flutter/material.dart';

/// Centralized color constants for the NextChord app
///
/// Using this class prevents color duplication across 16+ files
/// and ensures consistent theming throughout the app.
class AppColors {
  // Primary brand colors
  static const Color primaryBlue = Color(0xFF0468cc);
  static const Color primaryBlueDark = Color.fromARGB(150, 3, 73, 153);

  // Gradient colors for modals and cards
  static const Color gradientStart = Color(0xFF0468cc);
  static const Color gradientEnd = Color.fromARGB(150, 3, 73, 153);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3); // white70
  static const Color textTertiary = Color(0x8AFFFFFF); // white54
  static const Color textHint = Color(0x5CFFFFFF); // white38

  // Background colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);

  // Border and divider colors
  static const Color borderLight = Color(0x3DFFFFFF); // white24
  static const Color borderMedium = Color(0x1FFFFFFF); // white12
  static const Color divider = Color(0x1FFFFFFF);

  // Status colors
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.blue;

  // Interactive colors
  static const Color interactiveDisabled = Color(0x33FFFFFF); // white20
  static const Color interactivePressed = Color(0x4DFFFFFF); // white30
  static const Color interactiveHover = Color(0x66FFFFFF); // white40

  // Selection colors
  static const Color selectionBackground = primaryBlue;
  static const Color selectionForeground = textPrimary;
  static const Color selectionCheck = primaryBlue;

  // Modal specific colors
  static const Color modalBackground = Colors.transparent;
  static const Color modalSurface = gradientStart;
  static const Color modalBorder = borderLight;

  // Private constructor to prevent instantiation
  AppColors._();
}
