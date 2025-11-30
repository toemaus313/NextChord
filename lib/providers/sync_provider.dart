import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync/google_drive_sync_service.dart';
import '../services/sync/icloud_sync_service.dart';
import '../services/sync/cloud_db_backup_service.dart';
import '../services/sync/icloud_db_backup_service.dart';
import '../data/database/app_database.dart';
import '../core/services/database_change_service.dart';
import '../core/enums/sync_backend.dart';
import '../main.dart' as main;

class SyncProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _syncEnabledKey = 'isSyncEnabled';
  static const String _syncBackendKey = 'syncBackend';

  late GoogleDriveSyncService _googleDriveService;
  late ICloudSyncService _icloudService;
  dynamic _backupService;
  final VoidCallback? _onSyncCompleted;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  bool _isSignedIn = false;
  bool _isSyncEnabled = false;
  SyncBackend _syncBackend = SyncBackend.local;
  SharedPreferences? _prefs;
  final AppDatabase _database;
  bool _isAppInForeground = true;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get isSignedIn => _isSignedIn;
  bool get isSyncEnabled => _isSyncEnabled;
  SyncBackend get syncBackend => _syncBackend;

  SyncProvider({
    required AppDatabase database,
    VoidCallback? onSyncCompleted,
  })  : _database = database,
        _onSyncCompleted = onSyncCompleted {
    try {
      // Initialize Google Drive sync service (loads Windows tokens for persistence)
      GoogleDriveSyncService.initialize().then((_) {}).catchError((e) {});

      // Initialize both services
      _googleDriveService = GoogleDriveSyncService(
        database: database,
      );

      _icloudService = ICloudSyncService(
        database: database,
      );

      // Backup service will be created in _loadSyncPreference after backend is loaded
    } catch (e) {
      rethrow;
    }

    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    _loadSyncPreference();
  }

  /// Get the currently active sync service based on backend
  dynamic get _currentSyncService {
    switch (_syncBackend) {
      case SyncBackend.googleDrive:
        return _googleDriveService;
      case SyncBackend.iCloud:
        return _icloudService;
      case SyncBackend.local:
        return null;
    }
  }

  /// Get the currently active backup service based on backend
  dynamic get _currentBackupService {
    switch (_syncBackend) {
      case SyncBackend.googleDrive:
        return _backupService;
      case SyncBackend.iCloud:
        return _backupService;
      case SyncBackend.local:
        return null;
    }
  }

  /// Load sync preference from SharedPreferences
  Future<void> _loadSyncPreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = _prefs?.getBool(_syncEnabledKey) ?? false;

    // Load backend preference with migration logic
    final backendName = _prefs?.getString(_syncBackendKey);
    if (backendName != null) {
      _syncBackend = SyncBackend.values.firstWhere(
        (backend) => backend.shortName == backendName,
        orElse: () => SyncBackend.local,
      );
    } else {
      // Migration: if sync was enabled but no backend set, default to Google Drive
      _syncBackend =
          _isSyncEnabled ? SyncBackend.googleDrive : SyncBackend.local;
      await _prefs?.setString(_syncBackendKey, _syncBackend.shortName);
    }

    // Create backup service based on loaded backend
    _createBackupService();

    // If sync was previously enabled, verify actual sign-in status
    if (_isSyncEnabled && _syncBackend != SyncBackend.local) {
      _isSignedIn = await _currentSyncService.isSignedIn();
    } else {
      _isSignedIn = false;
    }
    notifyListeners();

    // After loading preferences, check how long it has been since the
    // last successful sync. If it has been more than 10 days, prompt the
    // user to perform a manual cloud sync.
    _checkSyncRecencyAndWarnIfStale();

    // Trigger initial sync after preferences are loaded
    if (_isSyncEnabled && _syncBackend != SyncBackend.local) {
      // Small delay to ensure app is fully initialized
      Future.delayed(const Duration(seconds: 5), () async {
        await autoSync();

        // Maintain cloud backup after initial sync
        await _maintainCloudBackup();

        // Start metadata polling after initial sync
        _currentSyncService.startMetadataPolling();
      });
    }
  }

  /// Check last sync time from SyncState and, if older than 10 days,
  /// show a one-time warning prompting the user to resync from the cloud.
  Future<void> _checkSyncRecencyAndWarnIfStale() async {
    try {
      if (!_isSyncEnabled || _syncBackend == SyncBackend.local) {
        return;
      }

      final syncState = await _database.getSyncState();
      final lastSyncAt = syncState?.lastSyncAt;
      if (lastSyncAt == null) {
        return;
      }

      final threshold = DateTime.now().subtract(const Duration(days: 10));
      if (!lastSyncAt.isBefore(threshold)) {
        return;
      }

      // Use the global navigatorKey to obtain a BuildContext for
      // showing a SnackBar. Defer to next frame to avoid lifecycle
      // issues during startup.
      final context = main.navigatorKey.currentContext;
      if (context == null) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Your library has not synced for over 10 days. Please run a cloud sync to keep your devices in sync.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      });
    } catch (e) {
      // Handle the error
    }
  }

  /// Create backup service based on current backend
  void _createBackupService() {
    switch (_syncBackend) {
      case SyncBackend.googleDrive:
        _backupService = CloudDbBackupService(
          syncService: _googleDriveService,
          database: _database,
        );
        break;
      case SyncBackend.iCloud:
        _backupService = ICloudDbBackupService(
          syncService: _icloudService,
          database: _database,
        );
        break;
      case SyncBackend.local:
        _backupService = null as dynamic; // No backup service for local
        break;
    }
  }

  /// Maintain cloud backup (called on app startup)
  Future<void> _maintainCloudBackup() async {
    if (!_isSyncEnabled) return;

    await _backupService.maintainCloudBackup();
  }

  Future<void> _saveSyncPreference() async {
    if (_prefs != null) {
      await _prefs!.setBool(_syncEnabledKey, _isSyncEnabled);
      await _prefs!.setString(_syncBackendKey, _syncBackend.shortName);
    }
  }

  /// Set sync backend
  Future<void> setSyncBackend(SyncBackend backend) async {
    if (_syncBackend == backend) {
      return;
    }

    // Stop current service polling
    if (_currentSyncService != null) {
      _currentSyncService.stopMetadataPolling();
    }

    // Sign out from current backend if switching backends
    if (_syncBackend != SyncBackend.local && backend != _syncBackend) {
      await _currentSyncService.signOut();
    }

    _syncBackend = backend;
    _isSignedIn = false;
    _lastSyncTime = null;
    _lastError = null;

    // Create new backup service for the backend
    _createBackupService();

    // If switching to local, disable sync
    if (backend == SyncBackend.local) {
      _isSyncEnabled = false;
    }

    await _saveSyncPreference();
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

  /// App lifecycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_isSyncEnabled && _syncBackend != SyncBackend.local) {
          _currentSyncService.startMetadataPolling();
        }
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        // Only stop polling on mobile platforms (iOS/Android)
        // Windows and Mac continue polling even when unfocused
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) {
          if (_syncBackend != SyncBackend.local) {
            _currentSyncService.stopMetadataPolling();
          }
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        // Only stop polling on mobile platforms
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) {
          if (_syncBackend != SyncBackend.local) {
            _currentSyncService.stopMetadataPolling();
          }
        }
        break;
    }
  }

  Future<void> autoSync() async {
    if (!_isSyncEnabled || _isSyncing || _syncBackend == SyncBackend.local) {
      return;
    }

    try {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      // Mark sync as in progress to prevent feedback loops
      DatabaseChangeService().setSyncInProgress(true);

      // Verify we're signed in before attempting sync
      _isSignedIn = await _currentSyncService.isSignedIn();
      if (!_isSignedIn) {
        return;
      }

      await _currentSyncService.sync();
      _lastSyncTime = DateTime.now();
      await _saveSyncPreference();

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
      if (_syncBackend == SyncBackend.local) {
        throw Exception('Cannot sign in to local storage');
      }

      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      main.myDebug('SyncProvider.signIn: starting sign-in for backend=' +
          _syncBackend.shortName);
      _isSignedIn = await _currentSyncService.signIn();

      if (_isSignedIn) {
        // Enable sync when successfully signed in
        await setSyncEnabled(true);
        await handleInitialSync();
      } else {
        main.myDebug('SyncProvider.signIn: sign-in returned false');
      }
      return _isSignedIn;
    } catch (e) {
      _lastError = e.toString();
      main.myDebug('SyncProvider.signIn error: ' + e.toString());
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      if (_syncBackend == SyncBackend.local) return;

      _isSyncing = true;
      notifyListeners();

      await _currentSyncService.signOut();
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
    if (_isSyncing || _syncBackend == SyncBackend.local) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // Check if user is signed in before attempting sync
      if (!await _currentSyncService.isSignedIn()) {
        _lastError =
            'Please sign in to ${_syncBackend.displayName} to sync your library';
        return;
      }

      await _currentSyncService.sync();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> handleInitialSync() async {
    if (_isSyncing || _syncBackend == SyncBackend.local) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _currentSyncService.handleInitialSync();
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
    if (_syncBackend != SyncBackend.local) {
      _currentSyncService.stopMetadataPolling();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Check if cloud backup exists
  Future<bool> hasCloudBackup() async {
    try {
      if (_syncBackend == SyncBackend.local || _currentBackupService == null) {
        return false;
      }
      return await _currentBackupService.hasCloudBackup();
    } catch (e) {
      return false;
    }
  }

  /// Restore database from cloud backup
  /// Returns true if restore was successful, false otherwise
  Future<bool> restoreFromCloudBackup() async {
    try {
      if (_syncBackend == SyncBackend.local) {
        throw Exception('Cloud sync is not enabled for local storage');
      }

      if (!await _currentSyncService.isSignedIn()) {
        throw Exception('Not signed in to ${_syncBackend.displayName}');
      }

      _isSyncing = true;
      _lastError = null;
      notifyListeners();

      final success = await _currentBackupService.restoreFromCloudBackup();

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
