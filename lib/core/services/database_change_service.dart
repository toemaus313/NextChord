import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_service_locator.dart';

/// Centralized service to handle database change notifications
/// This service triggers auto-sync when any database write operation occurs
class DatabaseChangeService {
  static final DatabaseChangeService _instance =
      DatabaseChangeService._internal();
  factory DatabaseChangeService() => _instance;
  DatabaseChangeService._internal();

  Timer? _debounceTimer;
  bool _isSyncInProgress = false;

  /// Called when any database write operation completes
  /// This will trigger an auto-sync and reset the periodic timer
  /// Uses debouncing to prevent rapid syncs during bulk operations
  void notifyDatabaseChanged({String? operation, String? table}) {
    debugPrint(
        '🔍 DB CHANGE DETECTED: operation=${operation ?? "unknown"}, table=${table ?? "unknown"}');

    // Skip change notifications during sync to prevent feedback loops
    if (_isSyncInProgress) {
      debugPrint('⏭️  Skipping DB change notification during sync operation');
      return;
    }

    // Cancel any pending sync
    _debounceTimer?.cancel();

    // Schedule a new sync after a short delay to batch rapid changes
    debugPrint('⏰ Scheduling auto-sync in 500ms...');
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      debugPrint('🚀 Triggering auto-sync after database change');
      // Trigger auto-sync after database change
      SyncServiceLocator.triggerAutoSync();
    });
  }

  /// Mark sync as in progress to prevent feedback loops
  void setSyncInProgress(bool inProgress) {
    debugPrint('🔄 Sync in progress: $inProgress');
    _isSyncInProgress = inProgress;

    // If sync just finished, cancel any pending change notifications
    if (!inProgress) {
      _debounceTimer?.cancel();
      debugPrint('✅ Sync completed - cancelled pending change notifications');
    }
  }
}
