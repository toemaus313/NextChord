/// JSON model for MIDI mapping data in library export/import operations
class MidiMappingJson {
  final String id;
  final String songId;
  final String commandType;
  final String midiChannel;
  final String controlNumber;
  final String controlValue;
  final String action;
  final Map<String, dynamic> parameters;
  final bool isEnabled;
  final String createdAt;
  final String updatedAt;

  MidiMappingJson({
    required this.id,
    required this.songId,
    required this.commandType,
    required this.midiChannel,
    required this.controlNumber,
    required this.controlValue,
    required this.action,
    required this.parameters,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'songId': songId,
        'commandType': commandType,
        'midiChannel': midiChannel,
        'controlNumber': controlNumber,
        'controlValue': controlValue,
        'action': action,
        'parameters': parameters,
        'isEnabled': isEnabled,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory MidiMappingJson.fromJson(Map<String, dynamic> json) =>
      MidiMappingJson(
        id: json['id'] ?? '',
        songId: json['songId'] ?? '',
        commandType: json['commandType'] ?? '',
        midiChannel: json['midiChannel'] ?? '',
        controlNumber: json['controlNumber'] ?? '',
        controlValue: json['controlValue'] ?? '',
        action: json['action'] ?? '',
        parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
        isEnabled: json['isEnabled'] ?? true,
        createdAt: json['createdAt'] ?? '',
        updatedAt: json['updatedAt'] ?? '',
      );
}
