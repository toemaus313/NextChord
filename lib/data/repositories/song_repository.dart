import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/song.dart';
import '../database/app_database.dart';

/// Repository for managing Songs
/// Provides clean CRUD interface and abstracts database layer from business logic
class SongRepository {
  final AppDatabase _db;

  SongRepository(this._db);

  /// Convert a domain Song entity to a database SongModel
  SongModel _songToModel(Song song) {
    return SongModel(
      id: song.id,
      title: song.title,
      artist: song.artist,
      body: song.body,
      key: song.key,
      capo: song.capo,
      bpm: song.bpm,
      timeSignature: song.timeSignature,
      tags: jsonEncode(song.tags),
      audioFilePath: song.audioFilePath,
      notes: song.notes,
      createdAt: song.createdAt.millisecondsSinceEpoch,
      updatedAt: song.updatedAt.millisecondsSinceEpoch,
    );
  }

  /// Convert a database SongModel to a domain Song entity
  Song _modelToSong(SongModel model) {
    final tagsList = <String>[];
    try {
      tagsList.addAll(List<String>.from(jsonDecode(model.tags) as List));
    } catch (_) {
      // If JSON parsing fails, treat as empty tags
    }

    return Song(
      id: model.id,
      title: model.title,
      artist: model.artist,
      body: model.body,
      key: model.key,
      capo: model.capo,
      bpm: model.bpm,
      timeSignature: model.timeSignature,
      tags: tagsList,
      audioFilePath: model.audioFilePath,
      notes: model.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
    );
  }

  /// Fetch all songs, ordered by creation date (newest first)
  Future<List<Song>> getAllSongs() async {
    try {
      final models = await _db.songsDao.getAllSongs();
      return models.map(_modelToSong).toList();
    } catch (e) {
      throw SongRepositoryException('Failed to fetch songs: $e');
    }
  }

  /// Fetch a single song by ID
  Future<Song?> getSongById(String id) async {
    try {
      final model = await _db.songsDao.getSongById(id);
      return model != null ? _modelToSong(model) : null;
    } catch (e) {
      throw SongRepositoryException('Failed to fetch song with ID $id: $e');
    }
  }

  /// Search songs by title or artist
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) {
      return getAllSongs();
    }

    try {
      final models = await _db.songsDao.searchSongs(query);
      return models.map(_modelToSong).toList();
    } catch (e) {
      throw SongRepositoryException('Failed to search songs: $e');
    }
  }

  /// Get songs filtered by key
  Future<List<Song>> getSongsByKey(String key) async {
    try {
      final models = await _db.songsDao.getSongsByKey(key);
      return models.map(_modelToSong).toList();
    } catch (e) {
      throw SongRepositoryException('Failed to fetch songs by key: $e');
    }
  }

  /// Get songs filtered by tag
  Future<List<Song>> getSongsByTag(String tag) async {
    try {
      final models = await _db.songsDao.getSongsByTag(tag);
      return models.map(_modelToSong).toList();
    } catch (e) {
      throw SongRepositoryException('Failed to fetch songs by tag: $e');
    }
  }

  /// Insert a new song
  /// If no ID is provided, generates a UUID
  Future<String> insertSong(Song song) async {
    try {
      final songToInsert = song.id.isEmpty
          ? song.copyWith(
              id: const Uuid().v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : song.copyWith(
              updatedAt: DateTime.now(),
            );

      final model = _songToModel(songToInsert);
      await _db.songsDao.insertSong(model);
      return songToInsert.id;
    } catch (e) {
      throw SongRepositoryException('Failed to insert song: $e');
    }
  }

  /// Update an existing song
  Future<void> updateSong(Song song) async {
    try {
      final updatedSong = song.copyWith(updatedAt: DateTime.now());
      final model = _songToModel(updatedSong);
      final rowsAffected = await _db.songsDao.updateSong(model);

      if (rowsAffected == 0) {
        throw SongRepositoryException('Song with ID ${song.id} not found');
      }
    } catch (e) {
      throw SongRepositoryException('Failed to update song: $e');
    }
  }

  /// Delete a song by ID
  Future<void> deleteSong(String id) async {
    try {
      await _db.songsDao.deleteSong(id);
    } catch (e) {
      throw SongRepositoryException('Failed to delete song: $e');
    }
  }

  /// Delete all songs (use with caution!)
  Future<void> deleteAllSongs() async {
    try {
      await _db.songsDao.deleteAllSongs();
    } catch (e) {
      throw SongRepositoryException('Failed to delete all songs: $e');
    }
  }

  /// Get count of total songs
  Future<int> getSongCount() async {
    try {
      final songs = await getAllSongs();
      return songs.length;
    } catch (e) {
      throw SongRepositoryException('Failed to get song count: $e');
    }
  }

  /// Get all unique tags across all songs
  Future<Set<String>> getAllTags() async {
    try {
      final songs = await getAllSongs();
      final allTags = <String>{};
      for (final song in songs) {
        allTags.addAll(song.tags);
      }
      return allTags;
    } catch (e) {
      throw SongRepositoryException('Failed to fetch tags: $e');
    }
  }

  /// Get all unique keys across all songs
  Future<Set<String>> getAllKeys() async {
    try {
      final songs = await getAllSongs();
      return songs.map((song) => song.key).toSet();
    } catch (e) {
      throw SongRepositoryException('Failed to fetch keys: $e');
    }
  }
}

/// Custom exception for repository errors
class SongRepositoryException implements Exception {
  final String message;

  SongRepositoryException(this.message);

  @override
  String toString() => 'SongRepositoryException: $message';
}
