import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/sync/google_drive_sync_service.dart';
import '../data/database/app_database.dart';

class SyncProvider with ChangeNotifier {
  static const String _syncEnabledKey = 'isSyncEnabled';
  final GoogleDriveSyncService _syncService;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  bool _isSignedIn = false;
  bool _isSyncEnabled = false;
  Timer? _periodicSyncTimer;
  SharedPreferences? _prefs;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get isSignedIn => _isSignedIn;
  bool get isSyncEnabled => _isSyncEnabled;

  SyncProvider(AppDatabase database)
      : _syncService = GoogleDriveSyncService(database) {
    _loadSyncPreference();
    _startPeriodicSync();
  }

  /// Load sync preference from SharedPreferences
  Future<void> _loadSyncPreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = _prefs?.getBool(_syncEnabledKey) ?? false;

    // If sync was previously enabled, try to restore sign-in state
    if (_isSyncEnabled) {
      try {
        _isSignedIn = await _syncService.isSignedIn();
        if (!_isSignedIn) {
          // If we're no longer signed in, disable sync
          _isSyncEnabled = false;
          await _prefs?.setBool(_syncEnabledKey, false);
        }
      } catch (e) {
        debugPrint('Failed to check sign-in status: $e');
        _isSyncEnabled = false;
        await _prefs?.setBool(_syncEnabledKey, false);
      }
    }
    notifyListeners();
  }

  /// Enable or disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    if (_isSyncEnabled == enabled) return;

    _isSyncEnabled = enabled;
    await _prefs?.setBool(_syncEnabledKey, enabled);

    if (!enabled) {
      // If disabling sync, sign out
      await signOut();
    }

    notifyListeners();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performPeriodicSync(),
    );
  }

  Future<void> _performPeriodicSync() async {
    if (_isSignedIn && _isSyncEnabled && !_isSyncing) {
      await autoSync();
    }
  }

  Future<void> autoSync() async {
    if (!_isSignedIn || !_isSyncEnabled || _isSyncing) return;

    try {
      await _syncService.sync();
      _lastSyncTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Auto-sync failed: $e');
      // Don't update _lastError for auto-sync failures to avoid annoying users
    }
  }

  Future<bool> signIn() async {
    try {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      _isSignedIn = await _syncService.signIn();
      if (_isSignedIn) {
        // Enable sync when successfully signed in
        await setSyncEnabled(true);
        await handleInitialSync();
      }
      return _isSignedIn;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Sign in error: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isSyncing = true;
      notifyListeners();

      await _syncService.signOut();
      _isSignedIn = false;
      _isSyncEnabled = false;
      await _prefs?.setBool(_syncEnabledKey, false);
      _lastSyncTime = null;
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Sign out error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _syncService.sync();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> handleInitialSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _syncService.handleInitialSync();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Initial sync error: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    super.dispose();
  }

  // Helper method to show migration dialog
  static Future<bool> showMigrationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }
}
