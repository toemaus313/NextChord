import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/database/app_database.dart';
import '../../data/database/tables/tables.dart';

/// JSON model for library export/import
class LibraryJson {
  final int schemaVersion;
  final int libraryVersion;
  final String exportedAt;
  final List<DeviceInfo> devices;
  final List<SongJson> songs;
  final List<SetlistJson> setlists;
  final List<MidiMappingJson> midiMappings;
  final List<MidiProfileJson> midiProfiles;

  LibraryJson({
    required this.schemaVersion,
    required this.libraryVersion,
    required this.exportedAt,
    required this.devices,
    required this.songs,
    required this.setlists,
    required this.midiMappings,
    required this.midiProfiles,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'libraryVersion': libraryVersion,
        'exportedAt': exportedAt,
        'devices': devices.map((d) => d.toJson()).toList(),
        'songs': songs.map((s) => s.toJson()).toList(),
        'setlists': setlists.map((s) => s.toJson()).toList(),
        'midiMappings': midiMappings.map((m) => m.toJson()).toList(),
        'midiProfiles': midiProfiles.map((m) => m.toJson()).toList(),
      };

  factory LibraryJson.fromJson(Map<String, dynamic> json) => LibraryJson(
        schemaVersion: json['schemaVersion'] as int,
        libraryVersion: json['libraryVersion'] as int,
        exportedAt: json['exportedAt'] as String,
        devices: (json['devices'] as List)
            .map((d) => DeviceInfo.fromJson(d as Map<String, dynamic>))
            .toList(),
        songs: (json['songs'] as List)
            .map((s) => SongJson.fromJson(s as Map<String, dynamic>))
            .toList(),
        setlists: (json['setlists'] as List)
            .map((s) => SetlistJson.fromJson(s as Map<String, dynamic>))
            .toList(),
        midiMappings: (json['midiMappings'] as List)
            .map((m) => MidiMappingJson.fromJson(m as Map<String, dynamic>))
            .toList(),
        midiProfiles: (json['midiProfiles'] as List)
            .map((m) => MidiProfileJson.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class DeviceInfo {
  final String deviceId;
  final String lastSyncAt;

  DeviceInfo({required this.deviceId, required this.lastSyncAt});

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'lastSyncAt': lastSyncAt,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        deviceId: json['deviceId'] as String,
        lastSyncAt: json['lastSyncAt'] as String,
      );
}

class SongJson {
  final String id;
  final String title;
  final String artist;
  final String body;
  final String key;
  final int capo;
  final int bpm;
  final String timeSignature;
  final String tags;
  final String? audioFilePath;
  final String? notes;
  final String? profileId;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  SongJson({
    required this.id,
    required this.title,
    required this.artist,
    required this.body,
    required this.key,
    required this.capo,
    required this.bpm,
    required this.timeSignature,
    required this.tags,
    this.audioFilePath,
    this.notes,
    this.profileId,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'body': body,
        'key': key,
        'capo': capo,
        'bpm': bpm,
        'timeSignature': timeSignature,
        'tags': tags,
        'audioFilePath': audioFilePath,
        'notes': notes,
        'profileId': profileId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
      };

  factory SongJson.fromJson(Map<String, dynamic> json) => SongJson(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        body: json['body'] as String,
        key: json['key'] as String,
        capo: json['capo'] as int,
        bpm: json['bpm'] as int,
        timeSignature: json['timeSignature'] as String,
        tags: json['tags'] as String,
        audioFilePath: json['audioFilePath'] as String?,
        notes: json['notes'] as String?,
        profileId: json['profileId'] as String?,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        deleted: json['deleted'] as bool,
      );
}

class SetlistJson {
  final String id;
  final String name;
  final String items;
  final String? notes;
  final String? imagePath;
  final bool setlistSpecificEditsEnabled;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  SetlistJson({
    required this.id,
    required this.name,
    required this.items,
    this.notes,
    this.imagePath,
    required this.setlistSpecificEditsEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items,
        'notes': notes,
        'imagePath': imagePath,
        'setlistSpecificEditsEnabled': setlistSpecificEditsEnabled,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
      };

  factory SetlistJson.fromJson(Map<String, dynamic> json) => SetlistJson(
        id: json['id'] as String,
        name: json['name'] as String,
        items: json['items'] as String,
        notes: json['notes'] as String?,
        imagePath: json['imagePath'] as String?,
        setlistSpecificEditsEnabled:
            json['setlistSpecificEditsEnabled'] as bool,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        deleted: json['deleted'] as bool,
      );
}

class MidiMappingJson {
  final String id;
  final String songId;
  final int? programChangeNumber;
  final String controlChanges;
  final bool timing;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  MidiMappingJson({
    required this.id,
    required this.songId,
    this.programChangeNumber,
    required this.controlChanges,
    required this.timing,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'songId': songId,
        'programChangeNumber': programChangeNumber,
        'controlChanges': controlChanges,
        'timing': timing,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
      };

  factory MidiMappingJson.fromJson(Map<String, dynamic> json) =>
      MidiMappingJson(
        id: json['id'] as String,
        songId: json['songId'] as String,
        programChangeNumber: json['programChangeNumber'] as int?,
        controlChanges: json['controlChanges'] as String,
        timing: json['timing'] as bool,
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        deleted: json['deleted'] as bool,
      );
}

class MidiProfileJson {
  final String id;
  final String name;
  final int? programChangeNumber;
  final String controlChanges;
  final bool timing;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  MidiProfileJson({
    required this.id,
    required this.name,
    this.programChangeNumber,
    required this.controlChanges,
    required this.timing,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'programChangeNumber': programChangeNumber,
        'controlChanges': controlChanges,
        'timing': timing,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
      };

  factory MidiProfileJson.fromJson(Map<String, dynamic> json) =>
      MidiProfileJson(
        id: json['id'] as String,
        name: json['name'] as String,
        programChangeNumber: json['programChangeNumber'] as int?,
        controlChanges: json['controlChanges'] as String,
        timing: json['timing'] as bool,
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        deleted: json['deleted'] as bool,
      );
}

/// Service for handling library synchronization via JSON
class LibrarySyncService {
  static const int currentSchemaVersion = 1;

  final AppDatabase _database;

  LibrarySyncService(this._database);

  /// Export current local library to JSON string
  Future<String> exportLibraryToJson() async {
    try {
      // Ensure sync state is initialized
      await _database.initializeSyncState();

      // Get all data from local database (including deleted for sync)
      final songs = await _database.getAllSongsIncludingDeleted();
      final setlists = await _database.getAllSetlistsIncludingDeleted();
      final midiMappings = await _database.select(_database.midiMappings).get();
      final midiProfiles = await _database.select(_database.midiProfiles).get();
      final syncState = await _database.getSyncState();

      // Convert to JSON models
      final songJsons = songs
          .map((s) => SongJson(
                id: s.id,
                title: s.title,
                artist: s.artist,
                body: s.body,
                key: s.key,
                capo: s.capo,
                bpm: s.bpm,
                timeSignature: s.timeSignature,
                tags: s.tags,
                audioFilePath: s.audioFilePath,
                notes: s.notes,
                profileId: s.profileId,
                createdAt: s.createdAt,
                updatedAt: s.updatedAt,
                deleted: s.isDeleted,
              ))
          .toList();

      final setlistJsons = setlists
          .map((s) => SetlistJson(
                id: s.id,
                name: s.name,
                items: s.items,
                notes: s.notes,
                imagePath: s.imagePath,
                setlistSpecificEditsEnabled: s.setlistSpecificEditsEnabled,
                createdAt: s.createdAt,
                updatedAt: s.updatedAt,
                deleted: s.isDeleted,
              ))
          .toList();

      final midiMappingJsons = midiMappings
          .map((m) => MidiMappingJson(
                id: m.id,
                songId: m.songId,
                programChangeNumber: m.programChangeNumber,
                controlChanges: m.controlChanges,
                timing: m.timing,
                notes: m.notes,
                createdAt: m.createdAt,
                updatedAt: m.updatedAt,
                deleted: m.isDeleted,
              ))
          .toList();

      final midiProfileJsons = midiProfiles
          .map((m) => MidiProfileJson(
                id: m.id,
                name: m.name,
                programChangeNumber: m.programChangeNumber,
                controlChanges: m.controlChanges,
                timing: m.timing,
                notes: m.notes,
                createdAt: m.createdAt,
                updatedAt: m.updatedAt,
                deleted: m.isDeleted,
              ))
          .toList();

      // Create device info
      final deviceInfo = DeviceInfo(
        deviceId: syncState?.deviceId ?? 'unknown',
        lastSyncAt: DateTime.now().toIso8601String(),
      );

      // Create library JSON
      final libraryJson = LibraryJson(
        schemaVersion: currentSchemaVersion,
        libraryVersion: (syncState?.lastRemoteVersion ?? 0) + 1,
        exportedAt: DateTime.now().toIso8601String(),
        devices: [deviceInfo],
        songs: songJsons,
        setlists: setlistJsons,
        midiMappings: midiMappingJsons,
        midiProfiles: midiProfileJsons,
      );

      return jsonEncode(libraryJson.toJson());
    } catch (e) {
      debugPrint('Error exporting library to JSON: $e');
      rethrow;
    }
  }

  /// Import and merge library from JSON string
  Future<void> importAndMergeLibraryFromJson(String jsonString) async {
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final remoteLibrary = LibraryJson.fromJson(jsonData);

      // Validate schema version
      if (remoteLibrary.schemaVersion != currentSchemaVersion) {
        throw Exception(
            'Incompatible schema version: ${remoteLibrary.schemaVersion}');
      }

      await _database.initializeSyncState();

      // Get current local data (including deleted for sync)
      final localSongs = await _database.getAllSongsIncludingDeleted();
      final localSetlists = await _database.getAllSetlistsIncludingDeleted();
      final localMidiMappings =
          await _database.select(_database.midiMappings).get();
      final localMidiProfiles =
          await _database.select(_database.midiProfiles).get();

      // Create maps for efficient lookup
      final localSongsMap = {for (var s in localSongs) s.id: s};
      final localSetlistsMap = {for (var s in localSetlists) s.id: s};
      final localMidiMappingsMap = {for (var m in localMidiMappings) m.id: m};
      final localMidiProfilesMap = {for (var m in localMidiProfiles) m.id: m};

      final remoteSongsMap = {for (var s in remoteLibrary.songs) s.id: s};
      final remoteSetlistsMap = {for (var s in remoteLibrary.setlists) s.id: s};
      final remoteMidiMappingsMap = {
        for (var m in remoteLibrary.midiMappings) m.id: m
      };
      final remoteMidiProfilesMap = {
        for (var m in remoteLibrary.midiProfiles) m.id: m
      };

      // Merge songs
      final mergedSongs = _mergeRecords<SongJson, SongModel>(
        localMap: localSongsMap,
        remoteMap: remoteSongsMap,
        toJsonModel: (json) => SongModel(
          id: json.id,
          title: json.title,
          artist: json.artist,
          body: json.body,
          key: json.key,
          capo: json.capo,
          bpm: json.bpm,
          timeSignature: json.timeSignature,
          tags: json.tags,
          audioFilePath: json.audioFilePath,
          notes: json.notes,
          profileId: json.profileId,
          createdAt: json.createdAt,
          updatedAt: json.updatedAt,
          isDeleted: json.deleted,
        ),
        getTimestamp: (model) => model.updatedAt,
        isDeleted: (model) => model.isDeleted,
      );

      // Merge setlists
      final mergedSetlists = _mergeRecords<SetlistJson, SetlistModel>(
        localMap: localSetlistsMap,
        remoteMap: remoteSetlistsMap,
        toJsonModel: (json) => SetlistModel(
          id: json.id,
          name: json.name,
          items: json.items,
          notes: json.notes,
          imagePath: json.imagePath,
          setlistSpecificEditsEnabled: json.setlistSpecificEditsEnabled,
          createdAt: json.createdAt,
          updatedAt: json.updatedAt,
          isDeleted: json.deleted,
        ),
        getTimestamp: (model) => model.updatedAt,
        isDeleted: (model) => model.isDeleted,
      );

      // Merge MIDI mappings
      final mergedMidiMappings =
          _mergeRecords<MidiMappingJson, MidiMappingModel>(
        localMap: localMidiMappingsMap,
        remoteMap: remoteMidiMappingsMap,
        toJsonModel: (json) => MidiMappingModel(
          id: json.id,
          songId: json.songId,
          programChangeNumber: json.programChangeNumber,
          controlChanges: json.controlChanges,
          timing: json.timing,
          notes: json.notes,
          createdAt: json.createdAt,
          updatedAt: json.updatedAt,
          isDeleted: json.deleted,
        ),
        getTimestamp: (model) => model.updatedAt,
        isDeleted: (model) => model.isDeleted,
      );

      // Merge MIDI profiles
      final mergedMidiProfiles =
          _mergeRecords<MidiProfileJson, MidiProfileModel>(
        localMap: localMidiProfilesMap,
        remoteMap: remoteMidiProfilesMap,
        toJsonModel: (json) => MidiProfileModel(
          id: json.id,
          name: json.name,
          programChangeNumber: json.programChangeNumber,
          controlChanges: json.controlChanges,
          timing: json.timing,
          notes: json.notes,
          createdAt: json.createdAt,
          updatedAt: json.updatedAt,
          isDeleted: json.deleted,
        ),
        getTimestamp: (model) => model.updatedAt,
        isDeleted: (model) => model.isDeleted,
      );

      // Apply merged data to database in a transaction
      await _database.transaction(() async {
        // Clear and insert songs
        await _database.delete(_database.songs).go();
        for (final song in mergedSongs) {
          await _database.into(_database.songs).insert(song);
        }

        // Clear and insert setlists
        await _database.delete(_database.setlists).go();
        for (final setlist in mergedSetlists) {
          await _database.into(_database.setlists).insert(setlist);
        }

        // Clear and insert MIDI mappings
        await _database.delete(_database.midiMappings).go();
        for (final mapping in mergedMidiMappings) {
          await _database.into(_database.midiMappings).insert(mapping);
        }

        // Clear and insert MIDI profiles
        await _database.delete(_database.midiProfiles).go();
        for (final profile in mergedMidiProfiles) {
          await _database.into(_database.midiProfiles).insert(profile);
        }

        // Update sync state
        await _database.updateSyncState(
          lastRemoteVersion: remoteLibrary.libraryVersion,
          lastSyncAt: DateTime.now(),
        );
      });

      debugPrint('Successfully imported and merged library from JSON');
    } catch (e) {
      debugPrint('Error importing library from JSON: $e');
      rethrow;
    }
  }

  /// Generic merge function for last-write-wins strategy
  List<T> _mergeRecords<J, T>({
    required Map<String, T> localMap,
    required Map<String, J> remoteMap,
    required T Function(J) toJsonModel,
    required int Function(T) getTimestamp,
    required bool Function(T) isDeleted,
  }) {
    final allIds = {...localMap.keys, ...remoteMap.keys};
    final merged = <T>[];

    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];

      if (local == null && remote != null) {
        // Only exists remotely
        merged.add(toJsonModel(remote));
      } else if (local != null && remote == null) {
        // Only exists locally
        merged.add(local);
      } else if (local != null && remote != null) {
        // Exists in both - use last-write-wins
        final localTimestamp = getTimestamp(local);
        final remoteModel = toJsonModel(remote);
        final remoteTimestamp = getTimestamp(remoteModel);

        final localDeleted = isDeleted(local);
        final remoteDeleted = isDeleted(remoteModel);

        T winner;
        if (localDeleted && remoteDeleted) {
          // Both deleted - keep most recently deleted
          winner = localTimestamp > remoteTimestamp ? local : remoteModel;
        } else if (localDeleted && !remoteDeleted) {
          // Local deleted, remote not - if local deletion is newer, keep deletion
          winner = localTimestamp > remoteTimestamp ? local : remoteModel;
        } else if (!localDeleted && remoteDeleted) {
          // Remote deleted, local not - if remote deletion is newer, keep deletion
          winner = remoteTimestamp > localTimestamp ? remoteModel : local;
        } else {
          // Neither deleted - keep newest version
          winner = localTimestamp > remoteTimestamp ? local : remoteModel;
        }

        merged.add(winner);
      }
    }

    return merged;
  }
}
