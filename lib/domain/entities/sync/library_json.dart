import 'song_json.dart';
import 'setlist_json.dart';
import 'midi_mapping_json.dart';
import 'midi_profile_json.dart';

/// JSON model for library export/import operations
class LibraryJson {
  final List<SongJson> songs;
  final List<SetlistJson> setlists;
  final List<MidiMappingJson> midiMappings;
  final List<MidiProfileJson> midiProfiles;
  final int schemaVersion;
  final String exportedAt;
  final DeviceInfo deviceInfo;

  LibraryJson({
    required this.songs,
    required this.setlists,
    required this.midiMappings,
    required this.midiProfiles,
    required this.schemaVersion,
    required this.exportedAt,
    required this.deviceInfo,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt,
        'deviceInfo': deviceInfo.toJson(),
        'songs': songs.map((s) => s.toJson()).toList(),
        'setlists': setlists.map((s) => s.toJson()).toList(),
        'midiMappings': midiMappings.map((m) => m.toJson()).toList(),
        'midiProfiles': midiProfiles.map((p) => p.toJson()).toList(),
      };

  factory LibraryJson.fromJson(Map<String, dynamic> json) {
    return LibraryJson(
      schemaVersion: json['schemaVersion'] ?? 1,
      exportedAt: json['exportedAt'] ?? '',
      deviceInfo: DeviceInfo.fromJson(json['deviceInfo'] ?? {}),
      songs: (json['songs'] as List?)
              ?.map((s) => SongJson.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      setlists: (json['setlists'] as List?)
              ?.map((s) => SetlistJson.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      midiMappings: (json['midiMappings'] as List?)
              ?.map((m) => MidiMappingJson.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      midiProfiles: (json['midiProfiles'] as List?)
              ?.map((p) => MidiProfileJson.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Device information for library exports
class DeviceInfo {
  final String platform;
  final String version;
  final String deviceId;

  DeviceInfo({
    required this.platform,
    required this.version,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'version': version,
        'deviceId': deviceId,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        platform: json['platform'] ?? '',
        version: json['version'] ?? '',
        deviceId: json['deviceId'] ?? '',
      );
}
