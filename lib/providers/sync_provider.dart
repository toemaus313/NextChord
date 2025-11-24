import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync/google_drive_sync_service.dart';
import '../services/sync/cloud_db_backup_service.dart';
import '../data/database/app_database.dart';
import '../core/services/database_change_service.dart';
import '../main.dart' as main;

class SyncProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _syncEnabledKey = 'isSyncEnabled';
  late GoogleDriveSyncService _syncService;
  late CloudDbBackupService _backupService;
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

      // Initialize cloud backup service
      _backupService = CloudDbBackupService(
        syncService: _syncService,
        database: database,
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

        // Maintain cloud backup after initial sync
        try {
          await _maintainCloudBackup();
        } catch (e) {}

        // Start metadata polling after initial sync
        try {
          _syncService.startMetadataPolling();
        } catch (e) {}
      });
    }
  }

  /// Maintain cloud backup (called on app startup)
  Future<void> _maintainCloudBackup() async {
    try {
      if (!_isSyncEnabled) return;

      await _backupService.maintainCloudBackup();
    } catch (e) {}
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
        if (_isSyncEnabled) {
          _syncService.startMetadataPolling();
        }
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        // Only stop polling on mobile platforms (iOS/Android)
        // Windows and Mac continue polling even when unfocused
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) {
          _syncService.stopMetadataPolling();
        } else {}
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        // Only stop polling on mobile platforms
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) {
          _syncService.stopMetadataPolling();
        }
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

      // Log successful local change upload
      main.myDebug("Local db change successfully sent to cloud");

      // Trigger UI refresh after successful auto-sync
      if (_onSyncCompleted != null) {
        _onSyncCompleted!();
      }
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

  /// Check if cloud backup exists
  Future<bool> hasCloudBackup() async {
    try {
      return await _backupService.hasCloudBackup();
    } catch (e) {
      return false;
    }
  }

  /// Restore database from cloud backup
  /// Returns true if restore was successful, false otherwise
  Future<bool> restoreFromCloudBackup() async {
    try {
      if (!_isSyncEnabled) {
        throw Exception('Cloud sync is not enabled');
      }

      if (!await _syncService.isSignedIn()) {
        throw Exception('Not signed in to Google Drive');
      }

      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      final success = await _backupService.restoreFromCloudBackup();

      if (success) {
        _lastSyncTime = DateTime.now();
        _lastError = null;
      } else {
        _lastError = 'Failed to restore from cloud backup';
      }

      return success;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
