import '../../providers/sync_provider.dart';
import '../../core/enums/sync_backend.dart';
import '../../main.dart' as main;

/// Global service locator for accessing sync functionality throughout the app
class SyncServiceLocator {
  static SyncProvider? _syncProvider;

  /// Initialize the sync service locator with a SyncProvider instance
  static void initialize(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
  }

  /// Get the current SyncProvider instance
  static SyncProvider? get syncProvider => _syncProvider;

  /// Upload a file using the active sync service
  static Future<bool> uploadFile(String localPath, String relativePath) async {
    main.myDebug(
        'SyncServiceLocator.uploadFile: localPath=$localPath, relativePath=$relativePath');
    if (_syncProvider != null) {
      // Use the configured sync backend
      switch (_syncProvider!.syncBackend) {
        case SyncBackend.googleDrive:
          main.myDebug('SyncServiceLocator.uploadFile: using Google Drive');
          if (_syncProvider!.googleDriveService != null) {
            return await _syncProvider!.googleDriveService!
                .uploadFile(localPath, relativePath);
          }
          break;
        case SyncBackend.iCloud:
          main.myDebug('SyncServiceLocator.uploadFile: using iCloud');
          if (_syncProvider!.iCloudService != null) {
            return await _syncProvider!.iCloudService!
                .uploadFile(localPath, relativePath);
          }
          break;
        case SyncBackend.local:
          main.myDebug('SyncServiceLocator.uploadFile: local only - no upload');
          return false;
      }
    }
    main.myDebug('SyncServiceLocator.uploadFile: no sync service available');
    return false;
  }

  /// Download a file using the active sync service
  static Future<String?> downloadFile(String relativePath) async {
    if (_syncProvider != null) {
      // Use the configured sync backend
      switch (_syncProvider!.syncBackend) {
        case SyncBackend.googleDrive:
          if (_syncProvider!.googleDriveService != null) {
            return await _syncProvider!.googleDriveService!
                .downloadFile(relativePath);
          }
          break;
        case SyncBackend.iCloud:
          if (_syncProvider!.iCloudService != null) {
            return await _syncProvider!.iCloudService!
                .downloadFile(relativePath);
          }
          break;
        case SyncBackend.local:
          return null;
      }
    }
    return null;
  }

  /// Trigger auto-sync if available and signed in
  static Future<void> triggerAutoSync() async {
    if (_syncProvider != null) {}

    if (_syncProvider != null && _syncProvider!.isSignedIn) {
      try {
        await _syncProvider!.autoSync();
      } catch (e) {}
    } else {}
  }

  /// Clear the sync service locator (for testing or app disposal)
  static void dispose() {
    _syncProvider = null;
  }
}
