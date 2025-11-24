import 'package:flutter/foundation.dart' show debugPrint;
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
    debugPrint('🔄 SyncServiceLocator.triggerAutoSync() called');
    debugPrint('🔄 _syncProvider is null: ${_syncProvider == null}');
    if (_syncProvider != null) {
      debugPrint('🔄 isSignedIn: ${_syncProvider!.isSignedIn}');
      debugPrint('🔄 isSyncEnabled: ${_syncProvider!.isSyncEnabled}');
    }

    if (_syncProvider != null && _syncProvider!.isSignedIn) {
      try {
        debugPrint('🔄 Calling _syncProvider!.autoSync()');
        await _syncProvider!.autoSync();
        debugPrint('🔄 autoSync() completed successfully');
      } catch (e) {
        debugPrint('🔄 autoSync() failed: $e');
      }
    } else {
      debugPrint('🔄 Skipping auto-sync - provider null or not signed in');
    }
  }

  /// Clear the sync service locator (for testing or app disposal)
  static void dispose() {
    _syncProvider = null;
  }
}
