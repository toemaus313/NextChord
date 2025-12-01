import '../../providers/sync_provider.dart';
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
      // Try Google Drive first if available
      if (_syncProvider!.googleDriveService != null) {
        main.myDebug('SyncServiceLocator.uploadFile: using Google Drive');
        return await _syncProvider!.googleDriveService!
            .uploadFile(localPath, relativePath);
      }
      // Fall back to iCloud if available
      if (_syncProvider!.iCloudService != null) {
        main.myDebug('SyncServiceLocator.uploadFile: using iCloud');
        return await _syncProvider!.iCloudService!
            .uploadFile(localPath, relativePath);
      }
    }
    main.myDebug('SyncServiceLocator.uploadFile: no sync service available');
    return false;
  }

  /// Download a file using the active sync service
  static Future<String?> downloadFile(String relativePath) async {
    main.myDebug('SyncServiceLocator.downloadFile: relativePath=$relativePath');
    if (_syncProvider != null) {
      // Try Google Drive first if available
      if (_syncProvider!.googleDriveService != null) {
        main.myDebug('SyncServiceLocator.downloadFile: using Google Drive');
        return await _syncProvider!.googleDriveService!
            .downloadFile(relativePath);
      }
      // Fall back to iCloud if available
      if (_syncProvider!.iCloudService != null) {
        main.myDebug('SyncServiceLocator.downloadFile: using iCloud');
        return await _syncProvider!.iCloudService!.downloadFile(relativePath);
      }
    }
    main.myDebug('SyncServiceLocator.downloadFile: no sync service available');
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
