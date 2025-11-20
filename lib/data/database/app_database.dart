import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Drift table for Songs
@DataClassName('SongModel')
class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get body => text()(); // ChordPro formatted text
  TextColumn get key => text().withDefault(const Constant('C'))();
  IntColumn get capo => integer().withDefault(const Constant(0))();
  IntColumn get bpm => integer().withDefault(const Constant(120))();
  TextColumn get timeSignature => text().withDefault(const Constant('4/4'))();
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array stored as TEXT
  TextColumn get audioFilePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()(); // Stored as epoch milliseconds
  IntColumn get updatedAt => integer()(); // Stored as epoch milliseconds
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))(); // Soft delete flag

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for Setlists (collection of songs for a performance)
@DataClassName('SetlistModel')
class Setlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get items => text()(); // JSON array of SetlistItems
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()(); // Path to 200x200px image
  BoolColumn get setlistSpecificEditsEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Main Drift database
@DriftDatabase(tables: [Songs, Setlists])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  /// Get the DAO for Songs
  late final songsDao = SongsDao(this);

  /// Get the DAO for Setlists
  late final setlistsDao = SetlistsDao(this);

  /// Initialize database with migrations if needed
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle schema migrations here when you update the database
        if (from <= 1 && to >= 2) {
          // Add isDeleted column to songs table
          await m.addColumn(songs, songs.isDeleted);
        }
        if (from <= 2 && to >= 3) {
          // Add imagePath column to setlists table
          await m.addColumn(setlists, setlists.imagePath);
        }
        if (from <= 3 && to >= 4) {
          // Add setlistSpecificEditsEnabled column with default true
          await m.addColumn(setlists, setlists.setlistSpecificEditsEnabled);
        }
      },
    );
  }
}

/// Data Access Object for Songs
@DriftAccessor(tables: [Songs])
class SongsDao extends DatabaseAccessor<AppDatabase> with _$SongsDaoMixin {
  SongsDao(AppDatabase db) : super(db);

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

  /// Get a single song by ID
  Future<SongModel?> getSongById(String id) {
    return (select(songs)
          ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Search songs by title or artist
  Future<List<SongModel>> searchSongs(String query) {
    final lowerQuery = query.toLowerCase();
    return (select(songs)
          ..where((tbl) =>
              (tbl.title.lower().like('%$lowerQuery%') |
                  tbl.artist.lower().like('%$lowerQuery%')) &
              tbl.isDeleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get songs by key
  Future<List<SongModel>> getSongsByKey(String key) {
    return (select(songs)
          ..where((tbl) => tbl.key.equals(key) & tbl.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.title)]))
        .get();
  }

  /// Get songs by tag
  Future<List<SongModel>> getSongsByTag(String tag) async {
    final allSongs = await getAllSongs();
    return allSongs.where((song) {
      try {
        final tagsList = List<String>.from(jsonDecode(song.tags) as List);
        return tagsList.contains(tag);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  /// Insert a new song
  Future<void> insertSong(SongModel song) async {
    await into(songs).insert(song);
  }

  /// Update an existing song
  Future<int> updateSong(SongModel song) async {
    return await (update(songs)..where((tbl) => tbl.id.equals(song.id))).write(
      SongsCompanion(
        title: Value(song.title),
        artist: Value(song.artist),
        body: Value(song.body),
        key: Value(song.key),
        capo: Value(song.capo),
        bpm: Value(song.bpm),
        timeSignature: Value(song.timeSignature),
        tags: Value(song.tags),
        audioFilePath: Value(song.audioFilePath),
        notes: Value(song.notes),
        updatedAt: Value(song.updatedAt),
      ),
    );
  }

  /// Soft delete a song by ID (marks as deleted instead of removing)
  Future<void> deleteSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
      SongsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Get all deleted songs
  Future<List<SongModel>> getDeletedSongs() {
    return (select(songs)
          ..where((tbl) => tbl.isDeleted.equals(true))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Restore a deleted song by ID
  Future<void> restoreSong(String id) async {
    await (update(songs)..where((tbl) => tbl.id.equals(id))).write(
      SongsCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Permanently delete a song by ID (hard delete)
  Future<void> permanentlyDeleteSong(String id) async {
    await (delete(songs)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Delete all songs (use with caution!)
  Future<void> deleteAllSongs() async {
    await delete(songs).go();
  }
}

/// Data Access Object for Setlists
@DriftAccessor(tables: [Setlists])
class SetlistsDao extends DatabaseAccessor<AppDatabase>
    with _$SetlistsDaoMixin {
  SetlistsDao(AppDatabase db) : super(db);

  /// Get all setlists ordered by created date (newest first)
  Future<List<SetlistModel>> getAllSetlists() {
    return (select(setlists)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get a single setlist by ID
  Future<SetlistModel?> getSetlistById(String id) {
    return (select(setlists)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new setlist
  Future<void> insertSetlist(SetlistModel setlist) async {
    await into(setlists).insert(setlist);
  }

  /// Update an existing setlist
  Future<void> updateSetlist(SetlistModel setlist) async {
    await update(setlists).replace(setlist);
  }

  /// Delete a setlist by ID
  Future<void> deleteSetlist(String id) async {
    await (delete(setlists)..where((tbl) => tbl.id.equals(id))).go();
  }
}

/// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'nextchord_db.sqlite'));

    // Debug: Print database location
    debugPrint('📁 Database location: ${file.path}');

    return NativeDatabase(file);
  });
}
