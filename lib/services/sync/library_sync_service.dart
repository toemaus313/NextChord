import 'dart:convert';
import 'dart:async';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:crypto/crypto.dart';
import '../../data/database/app_database.dart';
import '../../core/services/database_change_service.dart';
import '../../main.dart' as main;

/// Model for Google Drive file metadata
class DriveLibraryMetadata {
  final String fileId;
  final String modifiedTime;
  final String md5Checksum;
  final String headRevisionId;

  DriveLibraryMetadata({
    required this.fileId,
    required this.modifiedTime,
    required this.md5Checksum,
    required this.headRevisionId,
  });

  /// Create from Google Drive File metadata
  factory DriveLibraryMetadata.fromDriveFile(drive.File file) {
    return DriveLibraryMetadata(
      fileId: file.id ?? '',
      modifiedTime: file.modifiedTime?.toString() ?? '',
      md5Checksum: file.md5Checksum ?? '',
      headRevisionId: file.headRevisionId ?? '',
    );
  }

  /// Check if this metadata represents a different version than another
  bool hasChanged(DriveLibraryMetadata? other) {
    if (other == null) return true;
    return md5Checksum != other.md5Checksum ||
        modifiedTime != other.modifiedTime ||
        headRevisionId != other.headRevisionId;
  }

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'modifiedTime': modifiedTime,
        'md5Checksum': md5Checksum,
        'headRevisionId': headRevisionId,
      };

  factory DriveLibraryMetadata.fromJson(Map<String, dynamic> json) =>
      DriveLibraryMetadata(
        fileId: json['fileId'] as String,
        modifiedTime: json['modifiedTime'] as String,
        md5Checksum: json['md5Checksum'] as String,
        headRevisionId: json['headRevisionId'] as String,
      );
}

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
  final int createdAt;
  final int updatedAt;
  final bool deleted;

  SetlistJson({
    required this.id,
    required this.name,
    required this.items,
    this.notes,
    this.imagePath,
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

/// Class to track detailed changes during merge operations
class MergeDeltaSummary {
  int songsAdded = 0;
  int songsDeleted = 0;
  int songsUpdated = 0;
  List<String> songFieldChanges = [];
  List<String> updatedSongIds =
      []; // Track specific song IDs for database change events

  int setlistsAdded = 0;
  int setlistsDeleted = 0;
  int setlistsUpdated = 0;
  List<String> setlistFieldChanges = [];

  int midiMappingsAdded = 0;
  int midiMappingsDeleted = 0;
  int midiMappingsUpdated = 0;
  List<String> midiMappingFieldChanges = [];

  int midiProfilesAdded = 0;
  int midiProfilesDeleted = 0;
  int midiProfilesUpdated = 0;
  List<String> midiProfileFieldChanges = [];

  void addSongChange(String change) {
    songFieldChanges.add(change);
  }

  void addUpdatedSongId(String songId) {
    updatedSongIds.add(songId);
  }

  void addSetlistChange(String change) {
    setlistFieldChanges.add(change);
  }

  void addMidiMappingChange(String change) {
    midiMappingFieldChanges.add(change);
  }

  void addMidiProfileChange(String change) {
    midiProfileFieldChanges.add(change);
  }

  String getSummary() {
    final parts = <String>[];

    if (songsAdded > 0 || songsDeleted > 0 || songsUpdated > 0) {
      parts.add(
          'Songs: $songsAdded added, $songsDeleted deleted, $songsUpdated updated');
      if (songFieldChanges.isNotEmpty) {
        parts.add('Song changes: ${songFieldChanges.join('; ')}');
      }
    }

    if (setlistsAdded > 0 || setlistsDeleted > 0 || setlistsUpdated > 0) {
      parts.add(
          'Setlists: $setlistsAdded added, $setlistsDeleted deleted, $setlistsUpdated updated');
      if (setlistFieldChanges.isNotEmpty) {
        parts.add('Setlist changes: ${setlistFieldChanges.join('; ')}');
      }
    }

    if (midiMappingsAdded > 0 ||
        midiMappingsDeleted > 0 ||
        midiMappingsUpdated > 0) {
      parts.add(
          'MIDI Mappings: $midiMappingsAdded added, $midiMappingsDeleted deleted, $midiMappingsUpdated updated');
      if (midiMappingFieldChanges.isNotEmpty) {
        parts
            .add('MIDI mapping changes: ${midiMappingFieldChanges.join('; ')}');
      }
    }

    if (midiProfilesAdded > 0 ||
        midiProfilesDeleted > 0 ||
        midiProfilesUpdated > 0) {
      parts.add(
          'MIDI Profiles: $midiProfilesAdded added, $midiProfilesDeleted deleted, $midiProfilesUpdated updated');
      if (midiProfileFieldChanges.isNotEmpty) {
        parts
            .add('MIDI profile changes: ${midiProfileFieldChanges.join('; ')}');
      }
    }

    return parts.join('\n');
  }
}

/// Service for handling library synchronization via JSON
class LibrarySyncService {
  static const int currentSchemaVersion = 1;

  final AppDatabase _database;

  LibrarySyncService(this._database);

  /// Public getter for database access (needed for sync operations)
  AppDatabase get database => _database;

  /// Generate SHA256 hash of JSON content for change detection
  String _generateJsonHash(String jsonContent) {
    final bytes = utf8.encode(jsonContent);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if the given JSON content differs from the last uploaded version
  Future<bool> hasLibraryChanged(String jsonContent) async {
    try {
      final syncState = await _database.getSyncState();
      if (syncState?.lastUploadedLibraryHash == null) {
        return true; // No previous upload, so this is a change
      }

      final currentHash = _generateJsonHash(jsonContent);
      return currentHash != syncState!.lastUploadedLibraryHash;
    } catch (e) {
      return true; // Assume changed on error to be safe
    }
  }

  /// Check if remote metadata represents changes since last sync
  Future<bool> hasRemoteChanges(DriveLibraryMetadata remoteMetadata) async {
    try {
      final syncState = await _database.getSyncState();

      // If we have no sync state, any remote file is considered a change
      if (syncState?.lastRemoteFileId == null) {
        return true;
      }

      // Check if the remote file is different from what we synced last
      final hasChanged = remoteMetadata.hasChanged(
        DriveLibraryMetadata(
          fileId: syncState!.lastRemoteFileId!,
          modifiedTime: syncState.lastRemoteModifiedTime ?? '',
          md5Checksum: syncState.lastRemoteMd5Checksum ?? '',
          headRevisionId: syncState.lastRemoteHeadRevisionId ?? '',
        ),
      );

      if (hasChanged) {
      } else {}

      return hasChanged;
    } catch (e) {
      return true; // Assume changed on error to be safe
    }
  }

  /// Check if merged JSON differs from remote JSON (for conditional upload)
  bool hasMergedLibraryChanged(String mergedJson, String? remoteJson) {
    try {
      if (remoteJson == null || remoteJson.isEmpty) {
        return true; // No remote file, always upload
      }

      // Extract library content for comparison (excluding volatile metadata)
      final mergedContent = _extractLibraryContent(mergedJson);
      final remoteContent = _extractLibraryContent(remoteJson);

      final mergedHash = _generateJsonHash(mergedContent);
      final remoteHash = _generateJsonHash(remoteContent);

      final hasChanged = mergedHash != remoteHash;
      if (hasChanged) {
      } else {}

      return hasChanged;
    } catch (e) {
      return true; // Assume changed on error to be safe
    }
  }

  /// Extract stable library content for comparison (excludes volatile metadata)
  String _extractLibraryContent(String fullJson) {
    try {
      final Map<String, dynamic> json = jsonDecode(fullJson);

      // Create a normalized version excluding volatile fields
      final normalized = {
        'schemaVersion': json['schemaVersion'],
        // Exclude libraryVersion since it increments on every export
        'songs': json['songs'],
        'setlists': json['setlists'],
        'midiMappings': json['midiMappings'],
        'midiProfiles': json['midiProfiles'],
        // Exclude: exportedAt, devices, libraryVersion (these change on every export)
      };

      return jsonEncode(normalized);
    } catch (e) {
      return fullJson; // Fallback to full JSON
    }
  }

  /// Compare song fields and return description of changes
  List<String> _compareSongFields(SongModel local, SongModel remote) {
    final changes = <String>[];

    if (local.title != remote.title) {
      changes.add('title changed from ${local.title} to ${remote.title}');
    }
    if (local.artist != remote.artist) {
      changes.add('artist changed from ${local.artist} to ${remote.artist}');
    }
    if (local.body != remote.body) {
      changes.add('content changed');
    }
    if (local.key != remote.key) {
      changes.add('key changed from ${local.key} to ${remote.key}');
    }
    if (local.capo != remote.capo) {
      changes.add('capo changed from ${local.capo} to ${remote.capo}');
    }
    if (local.bpm != remote.bpm) {
      changes.add('bpm changed from ${local.bpm} to ${remote.bpm}');
    }
    if (local.timeSignature != remote.timeSignature) {
      changes.add(
          'time signature changed from ${local.timeSignature} to ${remote.timeSignature}');
    }
    if (local.tags != remote.tags) {
      if (local.tags.isEmpty && remote.tags.isNotEmpty) {
        try {
          final remoteTagsList = List<String>.from(jsonDecode(remote.tags));
          changes.add('tags added: ${remoteTagsList.join(', ')}');
        } catch (e) {
          changes.add('tags added');
        }
      } else if (local.tags.isNotEmpty && remote.tags.isEmpty) {
        try {
          final localTagsList = List<String>.from(jsonDecode(local.tags));
          changes.add('tags removed: ${localTagsList.join(', ')}');
        } catch (e) {
          changes.add('tags removed');
        }
      } else {
        changes.add('tags changed');
      }
    }
    if (local.audioFilePath != remote.audioFilePath) {
      changes.add('audio file path changed');
    }
    if (local.notes != remote.notes) {
      changes.add('notes changed');
    }
    if (local.profileId != remote.profileId) {
      changes.add('MIDI profile changed');
    }

    return changes;
  }

  /// Store the hash of uploaded library content
  Future<void> storeUploadedLibraryHash(String jsonContent) async {
    try {
      final hash = _generateJsonHash(jsonContent);
      final syncState = await _database.getSyncState();
      if (syncState != null) {
        await _database.updateSyncState(
          lastRemoteVersion: syncState.lastRemoteVersion,
          lastSyncAt: syncState.lastSyncAt,
          lastUploadedLibraryHash: hash,
        );
      }
    } catch (e) {}
  }

  /// Get last seen remote metadata from sync state
  Future<DriveLibraryMetadata?> getLastSeenMetadata() async {
    try {
      final syncState = await _database.getSyncState();
      if (syncState == null || syncState.lastRemoteFileId == null) {
        return null;
      }

      return DriveLibraryMetadata(
        fileId: syncState.lastRemoteFileId!,
        modifiedTime: syncState.lastRemoteModifiedTime ?? '',
        md5Checksum: syncState.lastRemoteMd5Checksum ?? '',
        headRevisionId: syncState.lastRemoteHeadRevisionId ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// Get current sync state (exposed for GoogleDriveSyncService)
  Future<SyncStateModel?> getSyncState() async {
    return await _database.getSyncState();
  }

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
      rethrow;
    }
  }

  /// Import and merge library from JSON string
  Future<void> importAndMergeLibraryFromJson(String jsonString) async {
    try {
      main.myDebug('[LIBRARY_SYNC] importAndMergeLibraryFromJson() started');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final remoteLibrary = LibraryJson.fromJson(jsonData);

      // Validate schema version
      if (remoteLibrary.schemaVersion != currentSchemaVersion) {
        throw Exception('Schema version mismatch');
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
      final deltaSummary = MergeDeltaSummary();
      final mergedSongs = _mergeRecordsWithDeltas<SongJson, SongModel>(
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
        compareFields: _compareSongFields,
        deltaSummary: deltaSummary,
        recordType: 'song',
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
          setlistSpecificEditsEnabled: true,
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

      // Log detailed merge summary
      main.myDebug(
          '[LIBRARY_SYNC] Merge completed in-memory: songs=\\${mergedSongs.length}, setlists=\\${mergedSetlists.length}, midiMappings=\\${mergedMidiMappings.length}, midiProfiles=\\${mergedMidiProfiles.length}');
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

      // Emit database change events for all updated songs to trigger UI refresh
      if (deltaSummary.updatedSongIds.isNotEmpty) {
        final dbChangeService = DatabaseChangeService();
        for (final songId in deltaSummary.updatedSongIds) {
          dbChangeService.notifyDatabaseChanged(
              table: 'songs', operation: 'update', recordId: songId);
        }
      } else {}

      main.myDebug(
          '[LIBRARY_SYNC] importAndMergeLibraryFromJson() completed successfully');
    } catch (e) {
      main.myDebug(
          '[LIBRARY_SYNC] importAndMergeLibraryFromJson() ERROR: \\${e}');
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

  /// Enhanced merge function with detailed delta tracking
  List<T> _mergeRecordsWithDeltas<J, T>({
    required Map<String, T> localMap,
    required Map<String, J> remoteMap,
    required T Function(J) toJsonModel,
    required int Function(T) getTimestamp,
    required bool Function(T) isDeleted,
    required List<String> Function(T, T) compareFields,
    required MergeDeltaSummary deltaSummary,
    required String recordType,
  }) {
    final allIds = {...localMap.keys, ...remoteMap.keys};
    final merged = <T>[];

    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];

      if (local == null && remote != null) {
        // Only exists remotely - new record
        final remoteModel = toJsonModel(remote);
        merged.add(remoteModel);

        // Track addition
        if (recordType == 'song')
          deltaSummary.songsAdded++;
        else if (recordType == 'setlist')
          deltaSummary.setlistsAdded++;
        else if (recordType == 'midiMapping')
          deltaSummary.midiMappingsAdded++;
        else if (recordType == 'midiProfile') deltaSummary.midiProfilesAdded++;

        // Get record name for logging
        String recordName = 'Unknown';
        if (remoteModel is SongModel)
          recordName = remoteModel.title;
        else if (remoteModel is SetlistModel) recordName = remoteModel.name;
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

        // Debug logging for timestamp comparison (only log first few records to avoid spam)
        if (deltaSummary.songsAdded +
                deltaSummary.songsUpdated +
                deltaSummary.songsDeleted <
            5) {
          final recordId =
              (local as dynamic).id ?? (remoteModel as dynamic).id ?? 'unknown';
        }

        T winner;
        bool remoteWins = false;

        if (localDeleted && remoteDeleted) {
          // Both deleted - keep most recently deleted
          winner = localTimestamp > remoteTimestamp ? local : remoteModel;
          remoteWins = remoteTimestamp > localTimestamp;
        } else if (localDeleted && !remoteDeleted) {
          // Local deleted, remote not - if local deletion is newer, keep deletion
          winner = localTimestamp > remoteTimestamp ? local : remoteModel;
          remoteWins = remoteTimestamp > localTimestamp;
        } else if (!localDeleted && remoteDeleted) {
          // Remote deleted, local not - if remote deletion is newer, keep deletion
          winner = remoteTimestamp > localTimestamp ? remoteModel : local;
          remoteWins = remoteTimestamp > localTimestamp;
        } else {
          // Neither deleted - keep newest version
          winner = localTimestamp > remoteTimestamp ? local : remoteModel;
          remoteWins = remoteTimestamp > localTimestamp;
        }

        // Track changes based on whether timestamps differ (regardless of winner)
        if (localTimestamp != remoteTimestamp) {
          // Track update
          if (recordType == 'song') {
            deltaSummary.songsUpdated++;
            // Track song ID for database change notification
            final id = (winner as dynamic).id;
            if (id != null) {
              deltaSummary.addUpdatedSongId(id);
            }
          } else if (recordType == 'setlist') {
            deltaSummary.setlistsUpdated++;
          } else if (recordType == 'midiMapping') {
            deltaSummary.midiMappingsUpdated++;
          } else if (recordType == 'midiProfile') {
            deltaSummary.midiProfilesUpdated++;
          }

          // Track specific field changes
          final fieldChanges = compareFields(local, remoteModel);
          for (final change in fieldChanges) {
            if (recordType == 'song') {
              deltaSummary.addSongChange(change);
            } else if (recordType == 'setlist') {
              deltaSummary.addSetlistChange(change);
            } else if (recordType == 'midiMapping') {
              deltaSummary.addMidiMappingChange(change);
            } else if (recordType == 'midiProfile') {
              deltaSummary.addMidiProfileChange(change);
            }
          }

          // Track deletion status changes
          final winnerDeleted = isDeleted(winner);
          if (localDeleted != remoteDeleted) {
            // Deletion status changed between local and remote
            String recordName = 'Unknown';
            if (winner is SongModel)
              recordName = winner.title;
            else if (winner is SetlistModel) recordName = winner.name;

            if (winnerDeleted) {
              // Winner is deleted - count as deletion
              if (recordType == 'song') {
                deltaSummary.songsDeleted++;
              } else if (recordType == 'setlist') {
                deltaSummary.setlistsDeleted++;
              }
            }
            // If winner is not deleted, it's already counted in songsUpdated above
          }
        }

        merged.add(winner);
      }
    }

    return merged;
  }
}
