import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  int get schemaVersion => 1;

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
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get a single song by ID
  Future<SongModel?> getSongById(String id) {
    return (select(songs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Search songs by title or artist
  Future<List<SongModel>> searchSongs(String query) {
    final lowerQuery = query.toLowerCase();
    return (select(songs)
          ..where((tbl) =>
              tbl.title.lower().like('%$lowerQuery%') |
              tbl.artist.lower().like('%$lowerQuery%'))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get songs by key
  Future<List<SongModel>> getSongsByKey(String key) {
    return (select(songs)
          ..where((tbl) => tbl.key.equals(key))
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

  /// Delete a song by ID
  Future<void> deleteSong(String id) async {
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
QueryExecutor _openConnection() {
  return driftDatabase(name: 'nextchord_db');
}
