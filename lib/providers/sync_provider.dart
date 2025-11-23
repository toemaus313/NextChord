import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync/google_drive_sync_service.dart';

class SyncProvider with ChangeNotifier {
  static const String _syncEnabledKey = 'isSyncEnabled';
  late GoogleDriveSyncService _syncService;
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

  SyncProvider({VoidCallback? onSyncCompleted})
      : _onSyncCompleted = onSyncCompleted {
    _writeStartupLog('SyncProvider constructor called');

    try {
      _syncService = GoogleDriveSyncService(
        onDatabaseReplaced: () {
          if (_onSyncCompleted != null) {
            _onSyncCompleted!();
          }
        },
      );
      _writeStartupLog('GoogleDriveSyncService created successfully');
    } catch (e) {
      _writeStartupLog('ERROR creating GoogleDriveSyncService: $e');
      rethrow;
    }

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
    _prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = _prefs?.getBool(_syncEnabledKey) ?? false;
    _writeStartupLog('Sync enabled from preferences: $_isSyncEnabled');

    // If sync was previously enabled, optimistically set sign-in status
    if (_isSyncEnabled) {
      _isSignedIn = true;
    }
    notifyListeners();

    // Trigger initial sync after preferences are loaded
    if (_isSyncEnabled) {
      // Small delay to ensure app is fully initialized
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          await autoSync();
          await _writeStartupLog('Startup autoSync completed successfully');
        } catch (e) {
          await _writeStartupLog('Startup autoSync failed: $e');
        }
      });
    }
  }

  Future<void> _saveSyncPreference() async {
    if (_prefs != null) {
      await _prefs!.setBool(_syncEnabledKey, _isSyncEnabled);
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
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) {
        _performPeriodicSync();
      },
    );
  }

  Future<void> _performPeriodicSync() async {
    if (_isSyncEnabled && !_isSyncing) {
      await autoSync();
    }
  }

  Future<void> autoSync() async {
    if (!_isSyncEnabled || _isSyncing) return;

    try {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      // Verify we're signed in before attempting sync
      _isSignedIn = await _syncService.isSignedIn();
      if (!_isSignedIn) return;

      await _syncService.sync();
      _lastSyncTime = DateTime.now();
      await _saveSyncPreference();
    } catch (e) {
      _lastError = e.toString();

      // If it's an authentication error, update sign-in status
      if (e.toString().toLowerCase().contains('sign') ||
          e.toString().toLowerCase().contains('auth')) {
        _isSignedIn = false;
        notifyListeners();
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
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
