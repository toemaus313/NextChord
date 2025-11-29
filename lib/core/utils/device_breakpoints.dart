import 'package:flutter/material.dart';

/// Responsive breakpoint detection utilities for NextChord
class DeviceBreakpoints {
  // Breakpoint values (can be easily tweaked later)
  static const double phoneMaxWidth = 600.0;
  static const double tabletMinWidth = 600.0;
  static const double tabletMaxWidth = 1200.0;
  static const double desktopMinWidth = 1200.0;

  /// Check if current context is phone-sized
  static bool isPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    return shortestSide < phoneMaxWidth;
  }

  /// Check if current context is tablet-sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMinWidth && width < tabletMaxWidth;
  }

  /// Check if current context is desktop-sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMinWidth;
  }

  /// Get current form factor as enum
  static FormFactor getFormFactor(BuildContext context) {
    if (isPhone(context)) return FormFactor.phone;
    if (isTablet(context)) return FormFactor.tablet;
    return FormFactor.desktop;
  }

  /// Get responsive text size multiplier for phone mode
  static double getTextScaleMultiplier(BuildContext context) {
    if (isPhone(context)) {
      return 0.85; // Slightly smaller text on phones
    }
    return 1.0; // Normal size on tablet/desktop
  }

  /// Get responsive text size with base size
  static double getResponsiveTextSize(BuildContext context, double baseSize) {
    return baseSize * getTextScaleMultiplier(context);
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isPhone(context)) {
      return const EdgeInsets.all(12);
    }
    return const EdgeInsets.all(16);
  }

  /// Get responsive spacing
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    if (isPhone(context)) {
      return baseSpacing * 0.75;
    }
    return baseSpacing;
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    if (isPhone(context)) {
      return baseSize * 0.85;
    }
    return baseSize;
  }

  /// Get device type as string for debugging
  static String getDeviceType(BuildContext context) {
    if (isPhone(context)) return 'Phone';
    if (isTablet(context)) return 'Tablet';
    if (isDesktop(context)) return 'Desktop';
    return 'Unknown';
  }
}

/// Enum representing different device form factors
enum FormFactor {
  phone,
  tablet,
  desktop,
}
