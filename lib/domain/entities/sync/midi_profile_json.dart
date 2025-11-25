import 'midi_mapping_json.dart';

/// JSON model for MIDI profile data in library export/import operations
class MidiProfileJson {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> settings;
  final List<MidiMappingJson> mappings;
  final bool isDefault;
  final String createdAt;
  final String updatedAt;

  MidiProfileJson({
    required this.id,
    required this.name,
    required this.description,
    required this.settings,
    required this.mappings,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'settings': settings,
        'mappings': mappings.map((m) => m.toJson()).toList(),
        'isDefault': isDefault,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory MidiProfileJson.fromJson(Map<String, dynamic> json) =>
      MidiProfileJson(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        settings: Map<String, dynamic>.from(json['settings'] ?? {}),
        mappings: (json['mappings'] as List?)
                ?.map(
                    (m) => MidiMappingJson.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        isDefault: json['isDefault'] ?? false,
        createdAt: json['createdAt'] ?? '',
        updatedAt: json['updatedAt'] ?? '',
      );
}
