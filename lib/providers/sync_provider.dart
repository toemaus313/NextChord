import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync/google_drive_sync_service.dart';
import '../data/database/app_database.dart';
import '../core/services/database_change_service.dart';

class SyncProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _syncEnabledKey = 'isSyncEnabled';
  late GoogleDriveSyncService _syncService;
  final VoidCallback? _onSyncCompleted;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  bool _isSignedIn = false;
  bool _isSyncEnabled = false;
  SharedPreferences? _prefs;
  final AppDatabase _database;
  bool _isAppInForeground = true;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get isSignedIn => _isSignedIn;
  bool get isSyncEnabled => _isSyncEnabled;

  SyncProvider({
    required AppDatabase database,
    VoidCallback? onSyncCompleted,
  })  : _database = database,
        _onSyncCompleted = onSyncCompleted {
    try {
      // Initialize Google Drive sync service (loads Windows tokens for persistence)
      GoogleDriveSyncService.initialize().then((_) {}).catchError((e) {});

      _syncService = GoogleDriveSyncService(
        database: database,
        onDatabaseReplaced: () {
          if (_onSyncCompleted != null) {
            _onSyncCompleted!();
          }
        },
      );
    } catch (e) {
      rethrow;
    }

    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    _loadSyncPreference();
    // Start metadata polling through the sync service
    if (_isSyncEnabled) {
      _syncService.startMetadataPolling();
    }
  }

  /// Load sync preference from SharedPreferences
  Future<void> _loadSyncPreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = _prefs?.getBool(_syncEnabledKey) ?? false;

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
        } catch (e) {}
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

  /// App lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        debugPrint('App resumed, starting metadata polling');
        if (_isSyncEnabled) {
          _syncService.startMetadataPolling();
        }
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        debugPrint('App paused, stopping metadata polling');
        _syncService.stopMetadataPolling();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        _syncService.stopMetadataPolling();
        break;
    }
  }

  Future<void> autoSync() async {
    if (!_isSyncEnabled || _isSyncing) return;

    try {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      // Mark sync as in progress to prevent feedback loops
      DatabaseChangeService().setSyncInProgress(true);

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
      // Mark sync as completed to allow change notifications again
      DatabaseChangeService().setSyncInProgress(false);
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
      // Check if user is signed in before attempting sync
      if (!await _syncService.isSignedIn()) {
        _lastError = 'Please sign in to Google Drive to sync your library';
        return;
      }

      await _syncService.sync();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
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
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncService.stopMetadataPolling();
    WidgetsBinding.instance.removeObserver(this);
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
