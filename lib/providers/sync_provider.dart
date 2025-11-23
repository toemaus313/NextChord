import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync/google_drive_sync_service.dart';
import '../data/database/app_database.dart';

class SyncProvider with ChangeNotifier {
  static const String _syncEnabledKey = 'isSyncEnabled';
  final GoogleDriveSyncService _syncService;
  final VoidCallback? _onSyncCompleted;
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

  SyncProvider(AppDatabase database, {VoidCallback? onSyncCompleted})
      : _syncService = GoogleDriveSyncService(database),
        _onSyncCompleted = onSyncCompleted {
    print('=== SyncProvider CONSTRUCTOR CALLED ===');
    debugPrint('=== SyncProvider CONSTRUCTOR CALLED ===');
    _writeStartupLog('SyncProvider constructor called');
    _loadSyncPreference();
    _startPeriodicSync();
  }

  /// Write a timestamped log to a local file for debugging startup sync
  Future<void> _writeStartupLog(String message) async {
    try {
      final logFile = File('/tmp/nextchord_startup.log');
      final timestamp = DateTime.now().toIso8601String();
      await logFile.writeAsString('$timestamp: $message\n',
          mode: FileMode.append);
    } catch (e) {
      // Silently fail if we can't write log file
    }
  }

  /// Load sync preference from SharedPreferences
  Future<void> _loadSyncPreference() async {
    debugPrint('=== Loading sync preferences ===');
    await _writeStartupLog('Loading sync preferences');
    _prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = _prefs?.getBool(_syncEnabledKey) ?? false;
    debugPrint('=== Sync enabled from preferences: $_isSyncEnabled ===');
    await _writeStartupLog('Sync enabled from preferences: $_isSyncEnabled');

    // If sync was previously enabled, optimistically set sign-in status
    // The actual sign-in will be verified/restored when sync operations occur
    if (_isSyncEnabled) {
      _isSignedIn = true; // Set optimistically - will be verified during sync
      debugPrint('=== Set optimistic sign-in status: $_isSignedIn ===');
      await _writeStartupLog('Set optimistic sign-in status: $_isSignedIn');
    }
    notifyListeners();

    // Trigger initial sync after preferences are loaded
    if (_isSyncEnabled) {
      debugPrint('=== Triggering initial sync on app startup ===');
      await _writeStartupLog('Triggering initial sync on app startup');
      // Small delay to ensure app is fully initialized
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          debugPrint('=== Delayed sync trigger executing ===');
          await _writeStartupLog('Delayed sync trigger executing');
          await autoSync();
          await _writeStartupLog('Startup autoSync completed successfully');
        } catch (e) {
          debugPrint('=== Startup autoSync failed: $e ===');
          await _writeStartupLog('Startup autoSync failed: $e');
        }
      });
    } else {
      debugPrint('=== Sync not enabled, skipping initial sync trigger ===');
      await _writeStartupLog('Sync not enabled, skipping initial sync trigger');
    }
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
    debugPrint('=== Starting Periodic Sync Timer ===');
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) {
        debugPrint('=== Periodic Sync Triggered at ${DateTime.now()} ===');
        _performPeriodicSync();
      },
    );
    debugPrint('=== Periodic Sync Timer Started (5-minute intervals) ===');
  }

  Future<void> _performPeriodicSync() async {
    debugPrint('=== _performPeriodicSync called ===');
    debugPrint('Sync enabled: $_isSyncEnabled, Syncing: $_isSyncing');
    if (_isSyncEnabled && !_isSyncing) {
      debugPrint('=== Conditions met, calling autoSync ===');
      await autoSync();
    } else {
      debugPrint('=== Sync conditions not met, skipping ===');
    }
  }

  Future<void> autoSync() async {
    debugPrint('=== autoSync called ===');
    debugPrint('Sync enabled: $_isSyncEnabled, Syncing: $_isSyncing');
    if (!_isSyncEnabled || _isSyncing) {
      debugPrint(
          '=== autoSync returning early - Sync enabled: $_isSyncEnabled, Syncing: $_isSyncing ===');
      return;
    }

    try {
      debugPrint('=== Starting autoSync with Google Drive service ===');

      // Verify we're signed in before attempting sync
      debugPrint('=== Checking sign-in status ===');
      _isSignedIn = await _syncService.isSignedIn();
      debugPrint('=== Sign-in status: $_isSignedIn ===');
      if (!_isSignedIn) {
        debugPrint('=== Not signed in, skipping auto-sync ===');
        return;
      }

      debugPrint('=== Calling sync service ===');
      await _syncService.sync();
      _lastSyncTime = DateTime.now();
      debugPrint('=== autoSync completed successfully at $_lastSyncTime ===');
      debugPrint('=== Resetting periodic sync timer ===');

      // Reset the periodic timer after successful sync
      _startPeriodicSync();

      debugPrint('=== Notifying listeners ===');
      notifyListeners();

      // Trigger data refresh in providers after successful sync
      if (_onSyncCompleted != null) {
        debugPrint('=== Triggering provider data refresh after sync ===');
        _onSyncCompleted!();
      }

      // Add visible confirmation for startup sync
      debugPrint('=== AUTO-SYNC COMPLETED ON STARTUP ===');
    } catch (e) {
      debugPrint('=== Auto-sync failed: $e ===');
      debugPrint('=== Error type: ${e.runtimeType} ===');
      // If sync fails due to authentication, update sign-in status
      if (e.toString().toLowerCase().contains('sign') ||
          e.toString().toLowerCase().contains('auth')) {
        debugPrint(
            '=== Authentication failure detected, updating sign-in status ===');
        _isSignedIn = false;
        notifyListeners();
      }
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
