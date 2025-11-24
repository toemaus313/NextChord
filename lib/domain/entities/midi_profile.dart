import 'package:equatable/equatable.dart';

/// MIDI control change message (shared between MidiProfile and MidiMapping)
class MidiCC extends Equatable {
  final int controller; // 0-119, -1 indicates PC command
  final int value; // 0-127
  final String? label;

  const MidiCC({
    required this.controller,
    required this.value,
    this.label,
  });

  @override
  List<Object?> get props => [controller, value, label];
}

/// MIDI profile (reusable MIDI configuration)
class MidiProfile extends Equatable {
  final String id;
  final String name; // User-friendly profile name
  final int? programChangeNumber; // 0-127
  final List<MidiCC> controlChanges; // List of CC messages
  final bool timing; // MIDI clock timing enable/disable
  final String? notes;
  final DateTime createdAt; // Creation timestamp
  final DateTime updatedAt; // Last update timestamp

  MidiProfile({
    required this.id,
    required this.name,
    this.programChangeNumber,
    this.controlChanges = const [],
    this.timing = false,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Factory constructor for creating from database model
  factory MidiProfile.fromModel({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    int? programChangeNumber,
    List<MidiCC> controlChanges = const [],
    bool timing = false,
    String? notes,
  }) {
    return MidiProfile(
      id: id,
      name: name,
      programChangeNumber: programChangeNumber,
      controlChanges: controlChanges,
      timing: timing,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  MidiProfile copyWith({
    String? id,
    String? name,
    int? programChangeNumber,
    List<MidiCC>? controlChanges,
    bool? timing,
    String? notes,
  }) {
    return MidiProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      programChangeNumber: programChangeNumber ?? this.programChangeNumber,
      controlChanges: controlChanges ?? this.controlChanges,
      timing: timing ?? this.timing,
      notes: notes ?? this.notes,
    );
  }

  /// Check if this profile has any MIDI commands configured
  bool get hasMidiCommands =>
      programChangeNumber != null || controlChanges.isNotEmpty || timing;

  /// Get a human-readable description of the MIDI commands
  String get commandDescription {
    final parts = <String>[];

    if (programChangeNumber != null) {
      parts.add('PC$programChangeNumber');
    }

    for (final cc in controlChanges) {
      if (cc.controller == -1) {
        parts.add('PC${cc.value}');
      } else {}
    }

    if (timing) {
      parts.add('Timing');
    }

    return parts.join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        name,
        programChangeNumber,
        controlChanges,
        timing,
        notes,
      ];
}
