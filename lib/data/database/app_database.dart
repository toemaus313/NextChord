import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'dart:convert';
import 'dart:io';
import 'tables/tables.dart';
import 'migrations/migrations.dart';

part 'app_database.g.dart';

/// Main Drift database
@DriftDatabase(tables: [Songs, Setlists, MidiMappings, MidiProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

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
    into(songs).insertOnConflictUpdate(song);
  }

  /// Insert a new song
  Future<void> insertSong(SongModel song) async {
    await into(songs).insert(song);
  }

  /// Update an existing song
  Future<void> updateSong(SongModel song) async {
    await update(songs).replace(song);
  }

  /// Soft delete a song (mark as deleted)
  Future<void> softDeleteSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
        SongsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// Restore a soft-deleted song
  Future<void> restoreSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
        SongsCompanion(
            isDeleted: const Value(false),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch)));
  }

  /// Permanently delete a song
  Future<void> permanentlyDeleteSong(String id) async {
    await (delete(songs)..where((tbl) => tbl.id.equals(id))).go();
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
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get setlist by ID
  Future<SetlistModel?> getSetlistById(String id) {
    return (select(setlists)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create or update a setlist
  Future<void> saveSetlist(SetlistModel setlist) async {
    into(setlists).insertOnConflictUpdate(setlist);
  }

  /// Insert a new setlist
  Future<void> insertSetlist(SetlistModel setlist) async {
    await into(setlists).insert(setlist);
  }

  /// Update an existing setlist
  Future<void> updateSetlist(SetlistModel setlist) async {
    await update(setlists).replace(setlist);
  }

  /// Delete a setlist
  Future<void> deleteSetlist(String id) async {
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

  /// Delete a song by ID
  Future<void> deleteSong(String id) async {
    await (delete(songs)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Delete all songs (use with caution!)
  Future<void> deleteAllSongs() async {
    await delete(songs).go();
  }
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'nextchord_db.sqlite'));

    return NativeDatabase(file);
  });
}
