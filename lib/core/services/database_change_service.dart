import 'dart:async';
import 'sync_service_locator.dart';

/// Centralized service to handle database change notifications
/// This service triggers auto-sync when any database write operation occurs
class DatabaseChangeService {
  static final DatabaseChangeService _instance =
      DatabaseChangeService._internal();
  factory DatabaseChangeService() => _instance;
  DatabaseChangeService._internal();

  Timer? _debounceTimer;

  /// Called when any database write operation completes
  /// This will trigger an auto-sync and reset the periodic timer
  /// Uses debouncing to prevent rapid syncs during bulk operations
  void notifyDatabaseChanged() {
    // Cancel any pending sync
    _debounceTimer?.cancel();

    // Schedule a new sync after a short delay to batch rapid changes
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Trigger auto-sync after database change
      SyncServiceLocator.triggerAutoSync();
    });
  }
}
