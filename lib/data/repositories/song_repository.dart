import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/midi_mapping.dart';
import '../../domain/entities/midi_profile.dart';
import '../database/app_database.dart';
import '../../core/services/database_change_service.dart';

/// Repository for managing Songs
/// Provides clean CRUD interface and abstracts database layer from business logic
class SongRepository {
  final AppDatabase _db;

  SongRepository(this._db);

  /// Get the database instance for schema operations
  AppDatabase get database => _db;

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
      duration: song.duration,
      createdAt: song.createdAt.millisecondsSinceEpoch,
      updatedAt: song.updatedAt.millisecondsSinceEpoch,
      isDeleted: song.isDeleted,
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
      duration: model.duration,
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
      isDeleted: model.isDeleted,
    );
  }

  /// Fetch all songs, ordered by creation date (newest first)
  Future<List<Song>> getAllSongs() async {
    try {
      final models = await _db.getAllSongs();
      return models.map(_modelToSong).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch a single song by ID
  Future<Song?> getSongById(String id) async {
    try {
      final model = await _db.getSongById(id);
      return model != null ? _modelToSong(model) : null;
    } catch (e) {
      return null;
    }
  }

  /// Search songs by title or artist
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) {
      return getAllSongs();
    }

    try {
      final models = await _db.searchSongs(query);
      return models.map(_modelToSong).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get songs filtered by key
  Future<List<Song>> getSongsByKey(String key) async {
    try {
      final models = await _db.getSongsByKey(key);
      return models.map(_modelToSong).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get songs filtered by tag
  Future<List<Song>> getSongsByTag(String tag) async {
    try {
      final models = await _db.getSongsByTag(tag);
      return models.map(_modelToSong).toList();
    } catch (e) {
      return [];
    }
  }

  /// Insert a new song
  /// If no ID is provided, generates a UUID
  Future<String> insertSong(Song song) async {
    try {
      final songToInsert = song.id.isEmpty
          ? song.copyWith(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : song.copyWith(updatedAt: DateTime.now());

      final model = _songToModel(songToInsert);
      await _db.insertSong(model);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'songs', operation: 'update');

      return songToInsert.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing song
  Future<void> updateSong(Song song) async {
    try {
      final updatedSong = song.copyWith(updatedAt: DateTime.now());
      final model = _songToModel(updatedSong);
      await _db.updateSong(model);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'songs', operation: 'update');
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a song by ID
  Future<void> deleteSong(String id) async {
    try {
      await _db.deleteSong(id);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'songs', operation: 'delete');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Delete all songs (use with caution!)
  Future<void> deleteAllSongs() async {
    try {
      await _db.deleteAllSongs();

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'songs', operation: 'delete');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get count of total songs
  Future<int> getSongCount() async {
    try {
      final songs = await getAllSongs();
      return songs.length;
    } catch (e) {
      return 0;
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
      return <String>{};
    }
  }

  /// Get all unique keys across all songs
  Future<Set<String>> getAllKeys() async {
    try {
      final songs = await getAllSongs();
      return songs.map((song) => song.key).toSet();
    } catch (e) {
      return <String>{};
    }
  }

  /// Get all deleted songs
  Future<List<Song>> getDeletedSongs() async {
    try {
      final models = await _db.getDeletedSongs();
      return models.map(_modelToSong).toList();
    } catch (e) {
      return <Song>[];
    }
  }

  /// Restore a deleted song by ID
  Future<void> restoreSong(String id) async {
    try {
      await _db.restoreSong(id);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'songs', operation: 'update');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Permanently delete a song by ID (hard delete)
  Future<void> permanentlyDeleteSong(String id) async {
    try {
      await _db.permanentlyDeleteSong(id);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'songs', operation: 'delete');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Save or update a MIDI mapping for a song
  Future<void> saveMidiMapping(MidiMapping midiMapping) async {
    try {
      final existingMapping = await getMidiMapping(midiMapping.songId);

      if (existingMapping != null) {
        // Update existing mapping
        await _db.update(_db.midiMappings).replace(
              MidiMappingModel(
                id: existingMapping.id,
                songId: midiMapping.songId,
                programChangeNumber: midiMapping.programChangeNumber,
                controlChanges:
                    _encodeControlChanges(midiMapping.controlChanges),
                timing: midiMapping.timing,
                notes: midiMapping.notes,
                createdAt: DateTime.now()
                    .millisecondsSinceEpoch, // Use current time since domain entity doesn't have createdAt
                updatedAt: DateTime.now().millisecondsSinceEpoch,
                isDeleted: false, // Default to false for active mappings
              ),
            );
      } else {
        // Insert new mapping
        await _db.into(_db.midiMappings).insert(
              MidiMappingModel(
                id: midiMapping.id,
                songId: midiMapping.songId,
                programChangeNumber: midiMapping.programChangeNumber,
                controlChanges:
                    _encodeControlChanges(midiMapping.controlChanges),
                timing: midiMapping.timing,
                notes: midiMapping.notes,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
                isDeleted: false, // Default to false for active mappings
              ),
            );
      }
    } catch (e) {}
  }

  /// Get MIDI mapping for a song
  Future<MidiMapping?> getMidiMapping(String songId) async {
    try {
      final model = await (_db.select(_db.midiMappings)
            ..where((tbl) => tbl.songId.equals(songId)))
          .getSingleOrNull();

      if (model == null) return null;

      return MidiMapping(
        id: model.id,
        songId: model.songId,
        programChangeNumber: model.programChangeNumber,
        controlChanges: _decodeControlChanges(model.controlChanges),
        timing: model.timing,
        notes: model.notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete MIDI mapping for a song
  Future<void> deleteMidiMapping(String songId) async {
    try {
      await (_db.delete(_db.midiMappings)
            ..where((tbl) => tbl.songId.equals(songId)))
          .go();
    } catch (e) {}
  }

  /// Helper method to encode MidiCC list to JSON
  String _encodeControlChanges(List<MidiCC> controlChanges) {
    return jsonEncode(controlChanges
        .map((cc) => {
              'controller': cc.controller,
              'value': cc.value,
              'label': cc.label,
            })
        .toList());
  }

  /// Helper method to decode JSON to MidiCC list
  List<MidiCC> _decodeControlChanges(String json) {
    try {
      final List<dynamic> jsonList = jsonDecode(json);
      return jsonList
          .map((item) => MidiCC(
                controller: item['controller'] as int,
                value: item['value'] as int,
                label: item['label'] as String?,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ===== MIDI PROFILE CRUD METHODS =====

  /// Save or update a MIDI profile
  Future<void> saveMidiProfile(MidiProfile profile) async {
    try {
      final existingProfile = await getMidiProfile(profile.id);
      if (existingProfile != null) {
        await _db.update(_db.midiProfiles).replace(
              MidiProfileModel(
                id: profile.id,
                name: profile.name,
                programChangeNumber: profile.programChangeNumber,
                controlChanges: _encodeControlChanges(profile.controlChanges),
                timing: profile.timing,
                notes: profile.notes,
                createdAt: existingProfile.createdAt.millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
                isDeleted: false, // Default to false for active profiles
              ),
            );
      } else {
        await _db.into(_db.midiProfiles).insert(
              MidiProfileModel(
                id: profile.id,
                name: profile.name,
                programChangeNumber: profile.programChangeNumber,
                controlChanges: _encodeControlChanges(profile.controlChanges),
                timing: profile.timing,
                notes: profile.notes,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
                isDeleted: false, // Default to false for active profiles
              ),
            );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get all MIDI profiles
  Future<List<MidiProfile>> getAllMidiProfiles() async {
    try {
      final profileModels = await (_db.select(_db.midiProfiles)
            ..orderBy([(t) => OrderingTerm(expression: t.name)]))
          .get();

      return profileModels
          .map((model) => MidiProfile.fromModel(
                id: model.id,
                name: model.name,
                createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
                programChangeNumber: model.programChangeNumber,
                controlChanges: _decodeControlChanges(model.controlChanges),
                timing: model.timing,
                notes: model.notes,
              ))
          .toList();
    } catch (e) {
      return <MidiProfile>[];
    }
  }

  /// Get a specific MIDI profile by ID
  Future<MidiProfile?> getMidiProfile(String profileId) async {
    try {
      final model = await (_db.select(_db.midiProfiles)
            ..where((tbl) => tbl.id.equals(profileId)))
          .getSingleOrNull();

      if (model == null) return null;

      return MidiProfile.fromModel(
        id: model.id,
        name: model.name,
        createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
        programChangeNumber: model.programChangeNumber,
        controlChanges: _decodeControlChanges(model.controlChanges),
        timing: model.timing,
        notes: model.notes,
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete a MIDI profile
  Future<void> deleteMidiProfile(String profileId) async {
    try {
      // First, remove profile reference from any songs that use it
      await (_db.update(_db.songs)
            ..where((tbl) => tbl.profileId.equals(profileId)))
          .write(const SongsCompanion(profileId: Value(null)));

      // Then delete the profile
      await (_db.delete(_db.midiProfiles)
            ..where((tbl) => tbl.id.equals(profileId)))
          .go();
    } catch (e) {}
  }

  /// Assign a MIDI profile to a song
  Future<void> assignMidiProfileToSong(String songId, String? profileId) async {
    try {
      await (_db.update(_db.songs)..where((tbl) => tbl.id.equals(songId)))
          .write(SongsCompanion(profileId: Value(profileId)));
    } catch (e) {
      throw SongRepositoryException(
          'Failed to assign MIDI profile to song: $e');
    }
  }

  /// Get the MIDI profile for a specific song
  Future<MidiProfile?> getSongMidiProfile(String songId) async {
    try {
      final song = await (_db.select(_db.songs)
            ..where((tbl) => tbl.id.equals(songId)))
          .getSingle();

      if (song.profileId == null) return null;

      return await getMidiProfile(song.profileId!);
    } catch (e) {
      return null;
    }
  }

  // Pedal Mapping CRUD methods

  /// Get all pedal mappings
  Future<List<PedalMappingModel>> getAllPedalMappings() async {
    try {
      final mappings = await (_db.select(_db.pedalMappings)
            ..where((tbl) => tbl.isDeleted.equals(false)))
          .get();
      return mappings;
    } catch (e) {
      return [];
    }
  }

  /// Get a pedal mapping by ID
  Future<PedalMappingModel?> getPedalMappingById(String id) async {
    try {
      final mapping = await (_db.select(_db.pedalMappings)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();
      return mapping;
    } catch (e) {
      return null;
    }
  }

  /// Insert a new pedal mapping
  Future<void> insertPedalMapping(PedalMappingModel mapping) async {
    try {
      await _db.into(_db.pedalMappings).insert(mapping);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'pedal_mappings', operation: 'update');
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing pedal mapping
  Future<void> updatePedalMapping(PedalMappingModel mapping) async {
    try {
      await (_db.update(_db.pedalMappings)
            ..where((tbl) => tbl.id.equals(mapping.id)))
          .write(mapping);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'pedal_mappings', operation: 'update');
    } catch (e) {
      throw SongRepositoryException('Failed to update pedal mapping: $e');
    }
  }

  /// Delete a pedal mapping (soft delete)
  Future<void> deletePedalMapping(String id) async {
    try {
      await (_db.update(_db.pedalMappings)..where((tbl) => tbl.id.equals(id)))
          .write(PedalMappingsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'pedal_mappings', operation: 'update');
    } catch (e) {
      throw SongRepositoryException('Failed to delete pedal mapping: $e');
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
