import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enumeration
enum ThemeModeType {
  light,
  dark,
  system,
}

/// Provider for managing theme (light/dark/system mode) across the app
/// Persists theme preference using SharedPreferences
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'themeMode';
  ThemeModeType _themeMode = ThemeModeType.system;
  bool _systemIsDark = false;
  SharedPreferences? _prefs;

  ThemeModeType get themeMode => _themeMode;
  bool get isDarkMode =>
      _themeMode == ThemeModeType.dark ||
      (_themeMode == ThemeModeType.system && _systemIsDark);

  ThemeProvider() {
    _loadThemePreference();
  }

  /// Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    _prefs = await SharedPreferences.getInstance();
    final themeModeIndex =
        _prefs?.getInt(_themeModeKey) ?? ThemeModeType.system.index;
    _themeMode = ThemeModeType.values[themeModeIndex];
    _updateSystemBrightness();
    notifyListeners();
  }

  /// Update system brightness detection
  void _updateSystemBrightness() {
    // Get system brightness without context using platform dispatcher
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _systemIsDark = brightness == Brightness.dark;
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeModeType mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _prefs?.setInt(_themeModeKey, mode.index);
      notifyListeners();
    }
  }

  /// Legacy method for backward compatibility
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeModeType.light
        ? ThemeModeType.dark
        : ThemeModeType.light;
    await setThemeMode(newMode);
  }

  /// Legacy method for backward compatibility
  Future<void> setTheme(bool isDark) async {
    final newMode = isDark ? ThemeModeType.dark : ThemeModeType.light;
    await setThemeMode(newMode);
  }

  /// Get ThemeData based on current mode
  ThemeData get themeData {
    return isDarkMode ? _darkTheme : _lightTheme;
  }

  /// Get light theme
  ThemeData get lightTheme => _lightTheme;

  /// Get dark theme
  ThemeData get darkTheme => _darkTheme;

  /// Custom primary color #0468cc
  static const MaterialColor _primaryColor = MaterialColor(
    0xFF0468cc,
    <int, Color>{
      50: Color(0xFFE1F0FC),
      100: Color(0xFFB3D9F8),
      200: Color(0xFF81C0F4),
      300: Color(0xFF4FA7F0),
      400: Color(0xFF2994ED),
      500: Color(0xFF0468cc),
      600: Color(0xFF0460C7),
      700: Color(0xFF0355C0),
      800: Color(0xFF034BB9),
      900: Color(0xFF023AAD),
    },
  );

  /// Light theme configuration
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: _primaryColor,
    primaryColor: const Color(0xFF0468cc),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0468cc),
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0468cc),
      foregroundColor: Colors.white,
    ),
  );

  /// Dark theme configuration
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: _primaryColor,
    primaryColor: const Color(0xFF0468cc),
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0468cc),
      foregroundColor: Colors.white,
    ),
  );
}
