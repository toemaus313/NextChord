import '../../providers/sync_provider.dart';

/// Global service locator for accessing sync functionality throughout the app
class SyncServiceLocator {
  static SyncProvider? _syncProvider;

  /// Initialize the sync service locator with a SyncProvider instance
  static void initialize(SyncProvider syncProvider) {
    _syncProvider = syncProvider;
  }

  /// Get the current SyncProvider instance
  static SyncProvider? get syncProvider => _syncProvider;

  /// Trigger auto-sync if available and signed in
  static Future<void> triggerAutoSync() async {
    if (_syncProvider != null && _syncProvider!.isSignedIn) {
      try {
        await _syncProvider!.autoSync();
      } catch (e) {}
    }
  }

  /// Clear the sync service locator (for testing or app disposal)
  static void dispose() {
    _syncProvider = null;
  }
}
