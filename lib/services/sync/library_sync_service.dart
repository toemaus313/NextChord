import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:crypto/crypto.dart';
import '../../data/database/app_database.dart';
import '../../core/services/database_change_service.dart';

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

/// Helper for timestamped debug logging
String _timestampedLog(String message) {
  final timestamp = DateTime.now().toIso8601String();
  return '[$timestamp] $message';
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
        parts.add(
            '  Song changes: ${songFieldChanges.take(5).join(', ')}${songFieldChanges.length > 5 ? '...' : ''}');
      }
    }

    if (setlistsAdded > 0 || setlistsDeleted > 0 || setlistsUpdated > 0) {
      parts.add(
          'Setlists: $setlistsAdded added, $setlistsDeleted deleted, $setlistsUpdated updated');
      if (setlistFieldChanges.isNotEmpty) {
        parts.add(
            '  Setlist changes: ${setlistFieldChanges.take(5).join(', ')}${setlistFieldChanges.length > 5 ? '...' : ''}');
      }
    }

    if (midiMappingsAdded > 0 ||
        midiMappingsDeleted > 0 ||
        midiMappingsUpdated > 0) {
      parts.add(
          'MIDI Mappings: $midiMappingsAdded added, $midiMappingsDeleted deleted, $midiMappingsUpdated updated');
      if (midiMappingFieldChanges.isNotEmpty) {
        parts.add(
            '  MIDI Mapping changes: ${midiMappingFieldChanges.take(5).join(', ')}${midiMappingFieldChanges.length > 5 ? '...' : ''}');
      }
    }

    if (midiProfilesAdded > 0 ||
        midiProfilesDeleted > 0 ||
        midiProfilesUpdated > 0) {
      parts.add(
          'MIDI Profiles: $midiProfilesAdded added, $midiProfilesDeleted deleted, $midiProfilesUpdated updated');
      if (midiProfileFieldChanges.isNotEmpty) {
        parts.add(
            '  MIDI Profile changes: ${midiProfileFieldChanges.take(5).join(', ')}${midiProfileFieldChanges.length > 5 ? '...' : ''}');
      }
    }

    return parts.isEmpty ? 'No changes' : parts.join('\n');
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
      debugPrint('Error checking if library changed: $e');
      return true; // Assume changed on error to be safe
    }
  }

  /// Check if remote metadata represents changes since last sync
  Future<bool> hasRemoteChanges(DriveLibraryMetadata remoteMetadata) async {
    try {
      final syncState = await _database.getSyncState();

      // If we have no sync state, any remote file is considered a change
      if (syncState?.lastRemoteFileId == null) {
        debugPrint('No previous sync state - remote file considered as change');
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
        debugPrint('Remote file has changed - new MD5 or timestamp detected');
      } else {
        debugPrint('Remote file unchanged - same MD5 and timestamp');
      }

      return hasChanged;
    } catch (e) {
      debugPrint('Error checking remote changes: $e');
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
        debugPrint('⚠️ Library content has changed - upload needed');
      } else {
        debugPrint('✅ Library content identical - skipping upload');
      }

      return hasChanged;
    } catch (e) {
      debugPrint('Error checking if merged library changed: $e');
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
      debugPrint('Error extracting library content: $e');
      return fullJson; // Fallback to full JSON
    }
  }

  /// Compare song fields and return description of changes
  List<String> _compareSongFields(SongModel local, SongModel remote) {
    final changes = <String>[];

    if (local.title != remote.title) {
      changes.add('${remote.title}: title changed');
    }
    if (local.artist != remote.artist) {
      changes.add('${remote.title}: artist changed');
    }
    if (local.body != remote.body) {
      changes.add('${remote.title}: content changed');
    }
    if (local.key != remote.key) {
      changes.add(
          '${remote.title}: key changed from ${local.key} to ${remote.key}');
    }
    if (local.capo != remote.capo) {
      changes.add(
          '${remote.title}: capo changed from ${local.capo} to ${remote.capo}');
    }
    if (local.bpm != remote.bpm) {
      changes.add(
          '${remote.title}: BPM changed from ${local.bpm} to ${remote.bpm}');
    }
    if (local.timeSignature != remote.timeSignature) {
      changes.add('${remote.title}: time signature changed');
    }
    if (local.tags != remote.tags) {
      if (local.tags.isEmpty && remote.tags.isNotEmpty) {
        changes.add('${remote.title}: tags added');
      } else if (local.tags.isNotEmpty && remote.tags.isEmpty) {
        changes.add('${remote.title}: tags removed');
      } else {
        changes.add('${remote.title}: tags changed');
      }
    }
    if (local.audioFilePath != remote.audioFilePath) {
      changes.add('${remote.title}: audio file changed');
    }
    if (local.notes != remote.notes) {
      changes.add('${remote.title}: notes changed');
    }
    if (local.profileId != remote.profileId) {
      changes.add('${remote.title}: MIDI profile changed');
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
    } catch (e) {
      debugPrint('Error storing uploaded library hash: $e');
    }
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
      debugPrint('Error getting last seen metadata: $e');
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
      debugPrint(
          _timestampedLog('Merge analysis started - parsing remote JSON'));
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

      debugPrint(_timestampedLog(
          'Local vs Remote comparison - Songs: ${localSongs.length} local vs ${remoteLibrary.songs.length} remote'));
      debugPrint(_timestampedLog(
          'Local vs Remote comparison - Setlists: ${localSetlists.length} local vs ${remoteLibrary.setlists.length} remote'));
      debugPrint(_timestampedLog(
          'Local vs Remote comparison - MidiMappings: ${localMidiMappings.length} local vs ${remoteLibrary.midiMappings.length} remote'));
      debugPrint(_timestampedLog(
          'Local vs Remote comparison - MidiProfiles: ${localMidiProfiles.length} local vs ${remoteLibrary.midiProfiles.length} remote'));

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
      debugPrint(_timestampedLog('Starting songs merge - analyzing deltas'));
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
      debugPrint(_timestampedLog(
          'Songs merge completed - ${mergedSongs.length} total songs'));

      // Merge setlists
      debugPrint(_timestampedLog('Starting setlists merge - analyzing deltas'));
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
      debugPrint(_timestampedLog(
          'Setlists merge completed - ${mergedSetlists.length} total setlists'));

      // Merge MIDI mappings
      debugPrint(
          _timestampedLog('Starting MIDI mappings merge - analyzing deltas'));
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
      debugPrint(_timestampedLog(
          'MIDI mappings merge completed - ${mergedMidiMappings.length} total mappings'));

      // Merge MIDI profiles
      debugPrint(
          _timestampedLog('Starting MIDI profiles merge - analyzing deltas'));
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
      debugPrint(_timestampedLog(
          'MIDI profiles merge completed - ${mergedMidiProfiles.length} total profiles'));

      // Log detailed merge summary
      debugPrint(_timestampedLog('Merge completed with detailed deltas:'));
      debugPrint(_timestampedLog(deltaSummary.getSummary()));

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
        debugPrint(_timestampedLog(
            '📡 Emitting database change events for ${deltaSummary.updatedSongIds.length} updated songs'));
        debugPrint(_timestampedLog(
            '📡 Updated song IDs: ${deltaSummary.updatedSongIds.join(", ")}'));
        final dbChangeService = DatabaseChangeService();
        for (final songId in deltaSummary.updatedSongIds) {
          debugPrint(
              _timestampedLog('📡 Emitting change event for song ID: $songId'));
          dbChangeService.notifyDatabaseChanged(
              table: 'songs', operation: 'update', recordId: songId);
        }
        debugPrint(
            _timestampedLog('📡 All change events emitted successfully'));
      } else {
        debugPrint(
            _timestampedLog('ℹ️  No song IDs to emit change events for'));
      }

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

        deltaSummary.addSongChange('$recordName: added');
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

        // Track changes based on who won
        if (remoteWins) {
          // Track update
          if (recordType == 'song') {
            deltaSummary.songsUpdated++;
            // Track song ID for database change notification
            final id = (remoteModel as dynamic).id;
            if (id != null) {
              debugPrint(_timestampedLog(
                  '📝 Tracking updated song ID for change event: $id'));
              deltaSummary.addUpdatedSongId(id);
            } else {
              debugPrint(_timestampedLog(
                  '⚠️  WARNING: Song has null ID, cannot track for change event'));
            }
          } else if (recordType == 'setlist')
            deltaSummary.setlistsUpdated++;
          else if (recordType == 'midiMapping')
            deltaSummary.midiMappingsUpdated++;
          else if (recordType == 'midiProfile')
            deltaSummary.midiProfilesUpdated++;

          // Track specific field changes
          final fieldChanges = compareFields(local, remoteModel);
          for (final change in fieldChanges) {
            if (recordType == 'song')
              deltaSummary.addSongChange(change);
            else if (recordType == 'setlist')
              deltaSummary.addSetlistChange(change);
            else if (recordType == 'midiMapping')
              deltaSummary.addMidiMappingChange(change);
            else if (recordType == 'midiProfile')
              deltaSummary.addMidiProfileChange(change);
          }

          // Track deletion status changes
          if (!localDeleted && remoteDeleted) {
            String recordName = 'Unknown';
            if (remoteModel is SongModel)
              recordName = remoteModel.title;
            else if (remoteModel is SetlistModel) recordName = remoteModel.name;

            if (recordType == 'song') {
              deltaSummary.songsDeleted++;
              deltaSummary.addSongChange('$recordName: deleted');
            } else if (recordType == 'setlist') {
              deltaSummary.setlistsDeleted++;
              deltaSummary.addSetlistChange('$recordName: deleted');
            }
          }
        }

        merged.add(winner);
      }
    }

    return merged;
  }
}
