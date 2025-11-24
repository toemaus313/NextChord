import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/database/app_database.dart';
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
  AppDatabase? _database;

  // Reactive monitoring streams
  final StreamController<DbChangeEvent> _changeController =
      StreamController<DbChangeEvent>.broadcast();

  /// Get the stream of all database change events
  Stream<DbChangeEvent> get changeStream => _changeController.stream;

  /// Initialize the service with database instance
  /// Note: Reactive monitoring disabled - using manual refresh approach
  void initialize(AppDatabase database) {
    if (_database != null) {
      debugPrint('🔍 DatabaseChangeService already initialized');
      return;
    }

    _database = database;
    debugPrint(
        '🔍 DatabaseChangeService initialized with database (manual refresh mode)');

    // Note: Reactive monitoring disabled due to Drift watch() compatibility issues
    // Providers will use manual refresh via notifyDatabaseChanged() instead
  }

  /// Emit a change event to the stream
  void _emitChangeEvent(String table, DbChangeType type, {String? recordId}) {
    final event = DbChangeEvent(
      table: table,
      type: type,
      recordId: recordId,
      timestamp: DateTime.now(),
    );

    debugPrint('🔍 Emitting DB change event: $event');
    _changeController.add(event);
  }

  /// Called when any database write operation completes
  /// This will trigger an auto-sync and reset the periodic timer
  /// Uses debouncing to prevent rapid syncs during bulk operations
  void notifyDatabaseChanged({String? operation, String? table}) {
    debugPrint(
        '🔍 DB CHANGE DETECTED: operation=${operation ?? "unknown"}, table=${table ?? "unknown"}');

    // Also emit a change event for immediate UI updates
    if (table != null) {
      _emitChangeEvent(table, DbChangeType.update);
    }

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

  /// Dispose of the service and clean up resources
  Future<void> dispose() async {
    debugPrint('🔍 Disposing DatabaseChangeService');

    _debounceTimer?.cancel();

    if (!_changeController.isClosed) {
      _changeController.close();
    }

    _database = null;
  }
}
