import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing theme (light/dark mode) across the app
/// Persists theme preference using SharedPreferences
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  bool _isDarkMode = false;
  SharedPreferences? _prefs;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  /// Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs?.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs?.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  /// Set theme explicitly
  Future<void> setTheme(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      await _prefs?.setBool(_themeKey, _isDarkMode);
      notifyListeners();
    }
  }

  /// Get ThemeData based on current mode
  ThemeData get themeData {
    return _isDarkMode ? _darkTheme : _lightTheme;
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
