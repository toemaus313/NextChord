import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing appearance settings (custom color themes)
/// Uses SharedPreferences for storing appearance configuration
class AppearanceProvider extends ChangeNotifier {
  static const String _customColorKey = 'custom_theme_color';

  Color _customColor = const Color(0xFF0468cc); // Default primary blue
  SharedPreferences? _prefs;

  AppearanceProvider() {
    _loadSettings();
  }

  Color get customColor => _customColor;

  /// Get gradient colors based on the custom color
  Color get gradientStart => _customColor;
  Color get gradientEnd {
    // Darken the color by blending with black (70% original, 30% black)
    final r = (_customColor.r * 0.7).round().clamp(0, 255);
    final g = (_customColor.g * 0.7).round().clamp(0, 255);
    final b = (_customColor.b * 0.7).round().clamp(0, 255);
    return Color.fromRGBO(r, g, b, 1.0);
  }

  /// Load appearance settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final colorValue = _prefs?.getInt(_customColorKey);
      if (colorValue != null) {
        // Normalize stored color to ensure it is fully opaque
        final stored = Color(colorValue);
        if (stored.a == 0) {
          // Older versions may have saved colors without alpha; force full opacity
          _customColor = stored.withAlpha(0xFF);
        } else {
          _customColor = stored;
        }
      }
      notifyListeners();
    } catch (e) {
      // Use defaults if loading fails
      _customColor = const Color(0xFF0468cc);
    }
  }

  /// Set custom color and save to SharedPreferences
  Future<void> setCustomColor(Color color) async {
    if (_customColor != color) {
      // Always store color as fully opaque
      final normalized = color.withAlpha(0xFF);
      _customColor = normalized;
      await _prefs?.setInt(_customColorKey, normalized.toARGB32());
      notifyListeners();
    }
  }

  /// Reset to default color
  Future<void> resetToDefault() async {
    await setCustomColor(const Color(0xFF0468cc));
  }

  /// Get hex string representation of current color
  String get hexColorString {
    // Use the 0-255 integer channels from Color instead of normalized doubles
    final r = _customColor.red;
    final g = _customColor.green;
    final b = _customColor.blue;
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  /// Set color from hex string
  Future<void> setColorFromHex(String hexString) async {
    try {
      final cleaned = hexString.replaceFirst('#', '');
      final rgb = int.parse(cleaned, radix: 16) & 0xFFFFFF;
      final argb = 0xFF000000 | rgb; // Force full opacity
      final color = Color(argb);
      await setCustomColor(color);
    } catch (e) {
      // Invalid hex string, ignore
    }
  }
}
