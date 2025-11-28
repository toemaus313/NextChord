import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/services/database_change_service.dart';
import 'dart:convert';
import 'dart:math';
import 'package:nextchord/main.dart' as main;
import 'tables/tables.dart';
import 'migrations/migrations.dart';
import '../../services/sync/library_sync_service.dart';

part 'app_database.g.dart';

/// Main Drift database
@DriftDatabase(tables: [
  Songs,
  Setlists,
  MidiMappings,
  MidiProfiles,
  PedalMappings,
  SyncState,
  DeletionTracking
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => DatabaseMigrations.migrationStrategy;

  /// Initialize database with migrations if needed
  Future<void> mergeFromBackup(String backupPath) async {
    await DatabaseMigrations.mergeFromBackup(this, backupPath);
  }

  /// Get all songs ordered by created date (newest first)
  Future<List<SongModel>> getAllSongs() {
    return (select(songs)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get all songs including deleted ones (for sync)
  Future<List<SongModel>> getAllSongsIncludingDeleted() {
    return (select(songs)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get deleted songs
  Future<List<SongModel>> getDeletedSongs() {
    return (select(songs)
          ..where((tbl) => tbl.isDeleted.equals(true))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get song by ID
  Future<SongModel?> getSongById(String id) {
    return (select(songs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Get songs by key
  Future<List<SongModel>> getSongsByKey(String key) {
    return (select(songs)
          ..where((tbl) => tbl.key.equals(key) & tbl.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.title, mode: OrderingMode.asc)
          ]))
        .get();
  }

  /// Create or update a song
  Future<void> saveSong(SongModel song) async {
    final songWithTimestamp = song.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    into(songs).insertOnConflictUpdate(songWithTimestamp);
  }

  /// Insert a new song
  Future<void> insertSong(SongModel song) async {
    final songWithTimestamp = song.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await into(songs).insert(songWithTimestamp);
  }

  /// Update an existing song
  Future<void> updateSong(SongModel song) async {
    final songWithTimestamp = song.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await update(songs).replace(songWithTimestamp);
  }

  // Pedal Mappings CRUD operations

  /// Get all pedal mappings
  Future<List<PedalMappingModel>> getAllPedalMappings() {
    return (select(pedalMappings)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get pedal mapping by ID
  Future<PedalMappingModel?> getPedalMappingById(String id) {
    return (select(pedalMappings)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new pedal mapping
  Future<void> insertPedalMapping(PedalMappingModel mapping) async {
    final mappingWithTimestamp = mapping.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await into(pedalMappings).insert(mappingWithTimestamp);
  }

  /// Update an existing pedal mapping
  Future<void> updatePedalMapping(PedalMappingModel mapping) async {
    final mappingWithTimestamp = mapping.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await update(pedalMappings).replace(mappingWithTimestamp);
  }

  /// Delete a pedal mapping (soft delete)
  Future<void> deletePedalMapping(String id) async {
    await (update(pedalMappings)..where((tbl) => tbl.id.equals(id)))
        .write(PedalMappingsCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Soft delete a song (mark as deleted)
  Future<void> softDeleteSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
        SongsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
    DatabaseChangeService()
        .notifyDatabaseChanged(table: 'songs', operation: 'update');
  }

  /// Restore a soft-deleted song
  Future<void> restoreSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
        SongsCompanion(
            isDeleted: const Value(false),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
    DatabaseChangeService()
        .notifyDatabaseChanged(table: 'songs', operation: 'update');
  }

  /// Permanently delete a song
  Future<void> permanentlyDeleteSong(String id) async {
    await (delete(songs)..where((tbl) => tbl.id.equals(id))).go();
    DatabaseChangeService()
        .notifyDatabaseChanged(table: 'songs', operation: 'delete');
  }

  /// Get all unique keys from non-deleted songs
  Future<List<String>> getAllKeys() async {
    final query = selectOnly(songs)
      ..addColumns([songs.key])
      ..where(songs.isDeleted.equals(false))
      ..groupBy([songs.key])
      ..orderBy([OrderingTerm(expression: songs.key, mode: OrderingMode.asc)]);

    final results = await query.get();
    return results.map((row) => row.read(songs.key)!).toList();
  }

  /// Get all unique artists from non-deleted songs
  Future<List<String>> getAllArtists() async {
    final query = selectOnly(songs)
      ..addColumns([songs.artist])
      ..where(songs.isDeleted.equals(false) & songs.artist.isNotNull())
      ..groupBy([songs.artist])
      ..orderBy(
          [OrderingTerm(expression: songs.artist, mode: OrderingMode.asc)]);

    final results = await query.get();
    return results.map((row) => row.read(songs.artist)!).toList();
  }

  /// Get songs by artist
  Future<List<SongModel>> getSongsByArtist(String artist) {
    return (select(songs)
          ..where(
              (tbl) => tbl.artist.equals(artist) & tbl.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.title, mode: OrderingMode.asc)
          ]))
        .get();
  }

  /// Get songs by tag
  Future<List<SongModel>> getSongsByTag(String tag) {
    return (select(songs)
          ..where((tbl) => tbl.tags.contains(tag) & tbl.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.title, mode: OrderingMode.asc)
          ]))
        .get();
  }

  /// Get all unique tags from non-deleted songs
  Future<List<String>> getAllTags() async {
    final allSongs = await getAllSongs();
    final allTags = <String>{};

    for (final song in allSongs) {
      if (song.tags != null && song.tags!.isNotEmpty) {
        try {
          final tagsList = jsonDecode(song.tags) as List<dynamic>;
          allTags.addAll(tagsList.cast<String>());
        } catch (e) {
          // Handle malformed JSON tags
        }
      }
    }

    return allTags.toList()..sort();
  }

  /// Get all setlists ordered by created date (newest first)
  Future<List<SetlistModel>> getAllSetlists() {
    return (select(setlists)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get all setlists including deleted ones (for sync)
  Future<List<SetlistModel>> getAllSetlistsIncludingDeleted() {
    return (select(setlists)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get setlist by ID
  Future<SetlistModel?> getSetlistById(String id) {
    return (select(setlists)
          ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Create or update a setlist
  Future<void> saveSetlist(SetlistModel setlist) async {
    final setlistWithTimestamp = setlist.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    into(setlists).insertOnConflictUpdate(setlistWithTimestamp);
  }

  /// Insert a new setlist
  Future<void> insertSetlist(SetlistModel setlist) async {
    final setlistWithTimestamp = setlist.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await into(setlists).insert(setlistWithTimestamp);
  }

  /// Update an existing setlist
  Future<void> updateSetlist(SetlistModel setlist) async {
    final setlistWithTimestamp = setlist.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await update(setlists).replace(setlistWithTimestamp);
  }

  /// Soft delete a setlist and track for sync (for JSON sync compatibility)
  Future<void> deleteSetlist(String id) async {
    try {
      main.myDebug('[DATABASE] deleteSetlist() called with ID: \\${id}');
      // Get device ID for tracking
      final deviceId = await _getDeviceId();
      main.myDebug(
          '[DATABASE] Using deviceId: \\${deviceId} for deletion tracking');

      // Insert deletion tracking record first
      await _insertDeletionTracking('setlist', id, deviceId);

      // Soft delete the setlist (isDeleted = true) and bump updatedAt
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      main.myDebug(
          '[DATABASE] Performing soft delete for setlist ID: \\${id} at \\${nowMillis}');
      await (update(setlists)..where((tbl) => tbl.id.equals(id))).write(
        SetlistsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(nowMillis),
        ),
      );
      main.myDebug(
          '[DATABASE] Soft delete completed successfully for ID: \\${id}');
    } catch (e) {
      main.myDebug('[DATABASE] ERROR in deleteSetlist(): \\${e}');
      rethrow;
    }
  }

  /// Get device ID from sync state
  Future<String> _getDeviceId() async {
    try {
      final syncStateRecord =
          await (select(syncState)..limit(1)).getSingleOrNull();
      if (syncStateRecord != null) {
        return syncStateRecord.deviceId;
      }
      // Fallback: generate a new device ID
      return _generateDeviceId();
    } catch (e) {
      main.myDebug(
          '[DATABASE] ERROR getting deviceId, generating fallback: \\${e}');
      return _generateDeviceId();
    }
  }

  /// Insert deletion tracking record
  Future<void> _insertDeletionTracking(
      String entityType, String entityId, String deviceId) async {
    try {
      final trackingRecord = DeletionTrackingCompanion(
        id: Value(const Uuid().v4()),
        entityType: Value(entityType),
        entityId: Value(entityId),
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        deviceId: Value(deviceId),
      );
      await into(deletionTracking).insert(trackingRecord);
      main.myDebug(
          '[DATABASE] Deletion tracking inserted: \\${entityType}/\\${entityId}');
    } catch (e) {
      main.myDebug('[DATABASE] ERROR inserting deletion tracking: \\${e}');
      rethrow;
    }
  }

  /// Permanently purge setlists that have been soft-deleted longer than [threshold]
  Future<void> purgeDeletedSetlistsOlderThan(Duration threshold) async {
    try {
      final cutoffMillis =
          DateTime.now().subtract(threshold).millisecondsSinceEpoch;
      main.myDebug(
          '[DATABASE] purgeDeletedSetlistsOlderThan() called with thresholdMinutes: \\${threshold.inMinutes}, cutoffMillis: \\${cutoffMillis}');

      // Find soft-deleted setlists older than the cutoff
      final staleSetlists = await (select(setlists)
            ..where((tbl) =>
                tbl.isDeleted.equals(true) &
                tbl.updatedAt.isSmallerThanValue(cutoffMillis)))
          .get();

      if (staleSetlists.isEmpty) {
        main.myDebug(
            '[DATABASE] No soft-deleted setlists eligible for purge at this time');
        return;
      }

      final ids = staleSetlists.map((s) => s.id).toList();
      main.myDebug(
          '[DATABASE] Purging \\${ids.length} soft-deleted setlists: \\${ids.join(', ')}');

      // Hard delete the stale setlists
      await (delete(setlists)..where((tbl) => tbl.id.isIn(ids))).go();

      // Clean up associated deletion tracking records for these setlists
      await (delete(deletionTracking)
            ..where((tbl) =>
                tbl.entityType.equals('setlist') & tbl.entityId.isIn(ids)))
          .go();

      main.myDebug(
          '[DATABASE] Purge of soft-deleted setlists completed successfully');
    } catch (e) {
      main.myDebug(
          '[DATABASE] ERROR in purgeDeletedSetlistsOlderThan(): \\${e}');
      rethrow;
    }
  }

  /// Restore a soft-deleted setlist
  Future<void> restoreSetlist(String id) async {
    await (update(setlists)..where((tbl) => tbl.id.equals(id))).write(
        SetlistsCompanion(
            isDeleted: const Value(false),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// Permanently delete a setlist (hard delete)
  Future<void> permanentlyDeleteSetlist(String id) async {
    await (delete(setlists)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Search songs by title or artist
  Future<List<SongModel>> searchSongs(String query) {
    if (query.isEmpty) {
      return getAllSongs();
    }

    return (select(songs)
          ..where((tbl) =>
              (tbl.title.contains(query) | tbl.artist.contains(query)) &
              tbl.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.title, mode: OrderingMode.asc)
          ]))
        .get();
  }

  /// Delete a song by ID (soft delete)
  Future<void> deleteSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id)))
        .write(SongsCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Delete all songs (use with caution!)
  Future<void> deleteAllSongs() async {
    await delete(songs).go();
  }

  /// Get sync state (singleton row with id=1)
  Future<SyncStateModel?> getSyncState() async {
    return (select(syncState)..where((tbl) => tbl.id.equals(1)))
        .getSingleOrNull();
  }

  /// Update sync state
  Future<void> updateSyncState({
    required int lastRemoteVersion,
    DateTime? lastSyncAt,
    DriveLibraryMetadata? remoteMetadata,
    String? lastUploadedLibraryHash,
  }) async {
    await (update(syncState)..where((tbl) => tbl.id.equals(1))).write(
      SyncStateCompanion(
        lastRemoteVersion: Value(lastRemoteVersion),
        lastSyncAt: Value(lastSyncAt),
        lastRemoteFileId: Value(remoteMetadata?.fileId),
        lastRemoteModifiedTime: Value(remoteMetadata?.modifiedTime),
        lastRemoteMd5Checksum: Value(remoteMetadata?.md5Checksum),
        lastRemoteHeadRevisionId: Value(remoteMetadata?.headRevisionId),
        lastUploadedLibraryHash: Value(lastUploadedLibraryHash),
      ),
    );
  }

  /// Initialize sync state if it doesn't exist
  Future<void> initializeSyncState() async {
    final existing = await getSyncState();
    if (existing == null) {
      await into(syncState).insert(
        SyncStateCompanion(
          id: const Value(1),
          deviceId: Value(_generateDeviceId()),
          lastRemoteVersion: const Value(0),
          lastSyncAt: const Value(null),
        ),
      );
    }
  }

  /// Generate a unique device ID
  String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));
    return 'device_${timestamp}_${randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    // Legacy database filename kept for backward compatibility with existing user data
    final file = File(p.join(dbFolder.path, 'nextchord_db.sqlite'));

    return NativeDatabase(file);
  });
}
