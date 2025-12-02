import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';

/// Provider for managing appearance settings (custom color themes)
/// Uses SharedPreferences for primary color and Drift for syncable
/// appearance metadata like recent custom colors.
class AppearanceProvider extends ChangeNotifier {
  static const String _customColorKey = 'custom_theme_color';
  static const String _recentIndexKey = 'custom_theme_recent_index';
  static const String _disableDeviceSleepKey = 'disable_device_sleep';

  final AppDatabase _db;

  Color _customColor = const Color(0xFF0468cc); // Default primary blue
  SharedPreferences? _prefs;

  bool _disableDeviceSleep = false;

  // Three most recent custom colors selected from the advanced picker.
  // Null entries render as blank swatches.
  List<Color?> _recentCustomColors = [null, null, null];
  int _nextRecentIndex = 0;

  AppearanceProvider(this._db) {
    _loadSettings();
  }

  /// Reload recent custom colors from the database after a sync merge.
  Future<void> reloadFromDatabase() async {
    try {
      final existingSettings = await (_db.select(_db.appearanceSettings)
            ..where((tbl) => tbl.id.equals(1)))
          .getSingleOrNull();

      if (existingSettings != null) {
        _recentCustomColors = [
          _intToColor(existingSettings.recentColor1),
          _intToColor(existingSettings.recentColor2),
          _intToColor(existingSettings.recentColor3),
        ];
      }

      // Load disable-device-sleep flag (default false)
      _disableDeviceSleep = _prefs?.getBool(_disableDeviceSleepKey) ?? false;

      notifyListeners();
    } catch (_) {}
  }

  Color get customColor => _customColor;

  /// Recent custom colors exposed as an unmodifiable list
  List<Color?> get recentCustomColors => List.unmodifiable(_recentCustomColors);

  bool get disableDeviceSleep => _disableDeviceSleep;

  /// Get gradient colors based on the custom color
  Color get gradientStart => _customColor;
  Color get gradientEnd {
    // Darken the color by blending with black (70% original, 30% black)
    final r = (_customColor.r * 0.7).round().clamp(0, 255);
    final g = (_customColor.g * 0.7).round().clamp(0, 255);
    final b = (_customColor.b * 0.7).round().clamp(0, 255);
    return Color.fromRGBO(r, g, b, 1.0);
  }

  /// Load appearance settings from SharedPreferences and database
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

      // Load recent custom colors from AppearanceSettings table
      try {
        final existingSettings = await (_db.select(_db.appearanceSettings)
              ..where((tbl) => tbl.id.equals(1)))
            .getSingleOrNull();

        if (existingSettings != null) {
          _recentCustomColors = [
            _intToColor(existingSettings.recentColor1),
            _intToColor(existingSettings.recentColor2),
            _intToColor(existingSettings.recentColor3),
          ];
        } else {
          // Initialize singleton row with null recent colors
          final now = DateTime.now().millisecondsSinceEpoch;
          await _db.into(_db.appearanceSettings).insert(
                AppearanceSettingsCompanion(
                  id: const Value(1),
                  recentColor1: const Value(null),
                  recentColor2: const Value(null),
                  recentColor3: const Value(null),
                  updatedAt: Value(now),
                ),
              );
        }
      } catch (_) {}

      // Load next index from SharedPreferences (best-effort)
      final storedIndex = _prefs?.getInt(_recentIndexKey);
      if (storedIndex != null && storedIndex >= 0 && storedIndex < 3) {
        _nextRecentIndex = storedIndex;
      }

      notifyListeners();
    } catch (e) {
      // Use defaults if loading fails
      _customColor = const Color(0xFF0468cc);
    }
  }

  /// Set whether the app should attempt to keep the device screen awake
  /// while active. Persisted via SharedPreferences.
  Future<void> setDisableDeviceSleep(bool value) async {
    if (_disableDeviceSleep != value) {
      _disableDeviceSleep = value;
      await _prefs?.setBool(_disableDeviceSleepKey, value);
      notifyListeners();
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

  /// Register a newly chosen custom color into the three-slot recent
  /// history, cycling through slots 0 -> 1 -> 2 -> 0.
  Future<void> registerCustomColor(Color color) async {
    // Normalize to fully opaque for consistency
    final normalized = color.withAlpha(0xFF);

    _recentCustomColors[_nextRecentIndex] = normalized;
    _nextRecentIndex = (_nextRecentIndex + 1) % 3;

    // Persist next index locally so the cycle order is stable
    await _prefs?.setInt(_recentIndexKey, _nextRecentIndex);

    await _saveRecentCustomColorsToDatabase();
    notifyListeners();
  }

  Future<void> _saveRecentCustomColorsToDatabase() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final settingsCompanion = AppearanceSettingsCompanion(
        id: const Value(1),
        recentColor1: Value(_colorToInt(_recentCustomColors[0])),
        recentColor2: Value(_colorToInt(_recentCustomColors[1])),
        recentColor3: Value(_colorToInt(_recentCustomColors[2])),
        updatedAt: Value(now),
      );

      await _db.into(_db.appearanceSettings).insertOnConflictUpdate(
            settingsCompanion,
          );
    } catch (_) {}
  }

  Color? _intToColor(int? value) {
    if (value == null) return null;
    try {
      final color = Color(value);
      // Ensure fully opaque
      return color.withAlpha(0xFF);
    } catch (_) {
      return null;
    }
  }

  int? _colorToInt(Color? color) {
    if (color == null) return null;
    // Use ARGB 32-bit representation for storage
    return color.withAlpha(0xFF).toARGB32();
  }
}
