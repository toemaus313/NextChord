import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_service_locator.dart';

/// Types of database change events
enum DbChangeType { insert, update, delete, restore }

/// Represents a database change event for a specific table
class DbChangeEvent {
  final String table;
  final DbChangeType type;
  final String? recordId;
  final DateTime timestamp;

  const DbChangeEvent({
    required this.table,
    required this.type,
    this.recordId,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'DbChangeEvent(table: $table, type: $type, recordId: $recordId, timestamp: $timestamp)';
  }
}

/// Centralized service to handle database change notifications
/// This service triggers auto-sync when any database write operation occurs
/// and provides reactive monitoring for UI updates
class DatabaseChangeService {
  static final DatabaseChangeService _instance =
      DatabaseChangeService._internal();
  factory DatabaseChangeService() => _instance;
  DatabaseChangeService._internal();

  Timer? _debounceTimer;
  bool _isSyncInProgress = false;

  // Reactive monitoring streams
  final StreamController<DbChangeEvent> _changeController =
      StreamController<DbChangeEvent>.broadcast();

  /// Get the stream of all database change events
  Stream<DbChangeEvent> get changeStream => _changeController.stream;

  /// Initialize the service (no database needed - just for compatibility)
  void initialize() {}

  /// Emit a change event to the stream
  void _emitChangeEvent(String table, DbChangeType type, {String? recordId}) {
    final event = DbChangeEvent(
      table: table,
      type: type,
      recordId: recordId,
      timestamp: DateTime.now(),
    );

    _changeController.add(event);
  }

  /// Called when any database write operation completes
  /// This will trigger an auto-sync and reset the periodic timer
  /// Uses debouncing to prevent rapid syncs during bulk operations
  void notifyDatabaseChanged(
      {String? operation, String? table, String? recordId}) {
    // Also emit a change event for immediate UI updates
    if (table != null) {
      _emitChangeEvent(table, DbChangeType.update, recordId: recordId);
    }

    // Skip change notifications during sync to prevent feedback loops
    if (_isSyncInProgress) {
      return;
    }

    // Cancel any pending sync
    _debounceTimer?.cancel();

    // Schedule a new sync after a short delay to batch rapid changes
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      // Trigger auto-sync after database change
      SyncServiceLocator.triggerAutoSync();
    });
  }

  /// Mark sync as in progress to prevent feedback loops
  void setSyncInProgress(bool inProgress) {
    _isSyncInProgress = inProgress;

    // If sync just finished, cancel any pending change notifications
    if (!inProgress) {
      _debounceTimer?.cancel();
    }
  }

  /// Dispose of the service and clean up resources
  Future<void> dispose() async {
    _debounceTimer?.cancel();

    if (!_changeController.isClosed) {
      _changeController.close();
    }
  }
}
