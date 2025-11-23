import 'package:equatable/equatable.dart';
import 'midi_profile.dart';

/// MIDI mapping entity for song-specific MIDI configurations
class MidiMapping extends Equatable {
  final String id;
  final String songId;
  final int? programChangeNumber; // 0-127
  final List<MidiCC> controlChanges; // List of CC messages
  final bool timing; // MIDI clock timing enable/disable
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MidiMapping({
    required this.id,
    required this.songId,
    this.programChangeNumber,
    required this.controlChanges,
    required this.timing,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  MidiMapping copyWith({
    String? id,
    String? songId,
    int? programChangeNumber,
    List<MidiCC>? controlChanges,
    bool? timing,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MidiMapping(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      programChangeNumber: programChangeNumber ?? this.programChangeNumber,
      controlChanges: controlChanges ?? this.controlChanges,
      timing: timing ?? this.timing,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        songId,
        programChangeNumber,
        controlChanges,
        timing,
        notes,
        createdAt,
        updatedAt,
      ];
}
