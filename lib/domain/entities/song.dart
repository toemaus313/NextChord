import 'package:equatable/equatable.dart';

/// Domain entity for a musical Song
class Song extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String body; // ChordPro formatted text
  final String key;
  final int capo;
  final int bpm;
  final String timeSignature; // e.g., "4/4", "3/4"
  final List<String> tags;
  final String? audioFilePath; // Optional path to backing track
  final String? notes; // User notes about the song
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // Soft delete flag

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.body,
    this.key = 'C',
    this.capo = 0,
    this.bpm = 120,
    this.timeSignature = '4/4',
    this.tags = const [],
    this.audioFilePath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Create a copy of this song with optional field replacements
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? body,
    String? key,
    int? capo,
    int? bpm,
    String? timeSignature,
    List<String>? tags,
    String? audioFilePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      body: body ?? this.body,
      key: key ?? this.key,
      capo: capo ?? this.capo,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      tags: tags ?? this.tags,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        body,
        key,
        capo,
        bpm,
        timeSignature,
        tags,
        audioFilePath,
        notes,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}

/// Domain entity for a Setlist (collection of songs)
class Setlist extends Equatable {
  final String id;
  final String name;
  final List<SetlistItem> items; // Ordered list of songs/dividers
  final String? notes;
  final String? imagePath; // Path to 200x200px setlist image
  final DateTime createdAt;
  final DateTime updatedAt;

  const Setlist({
    required this.id,
    required this.name,
    required this.items,
    this.notes,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Setlist copyWith({
    String? id,
    String? name,
    List<SetlistItem>? items,
    String? notes,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, items, notes, imagePath, createdAt, updatedAt];
}

/// An item in a setlist - can be a song or a divider
abstract class SetlistItem extends Equatable {
  const SetlistItem();
}

/// A song reference in a setlist
class SetlistSongItem extends SetlistItem {
  final String songId;
  final int order;
  final int? transposeSteps; // Setlist-specific transpose (null = use song default)
  final int? capo; // Setlist-specific capo (null = use song default)

  const SetlistSongItem({
    required this.songId,
    required this.order,
    this.transposeSteps,
    this.capo,
  });

  SetlistSongItem copyWith({
    String? songId,
    int? order,
    int? transposeSteps,
    int? capo,
  }) {
    return SetlistSongItem(
      songId: songId ?? this.songId,
      order: order ?? this.order,
      transposeSteps: transposeSteps ?? this.transposeSteps,
      capo: capo ?? this.capo,
    );
  }

  @override
  List<Object?> get props => [songId, order, transposeSteps, capo];
}

/// A divider/section marker in a setlist
class SetlistDividerItem extends SetlistItem {
  final String label;
  final int order;

  const SetlistDividerItem({
    required this.label,
    required this.order,
  });

  @override
  List<Object?> get props => [label, order];
}

/// MIDI mapping for a song (what MIDI messages to send)
class MidiMapping extends Equatable {
  final String id;
  final String songId;
  final int? programChangeNumber; // 0-127
  final List<MidiCC> controlChanges; // List of CC messages
  final String? notes;

  const MidiMapping({
    required this.id,
    required this.songId,
    this.programChangeNumber,
    this.controlChanges = const [],
    this.notes,
  });

  MidiMapping copyWith({
    String? id,
    String? songId,
    int? programChangeNumber,
    List<MidiCC>? controlChanges,
    String? notes,
  }) {
    return MidiMapping(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      programChangeNumber: programChangeNumber ?? this.programChangeNumber,
      controlChanges: controlChanges ?? this.controlChanges,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props =>
      [id, songId, programChangeNumber, controlChanges, notes];
}

/// A MIDI Control Change message
class MidiCC extends Equatable {
  final int controller; // 0-119 (120-127 are reserved)
  final int value; // 0-127
  final String? label; // e.g., "Reverb", "Delay"

  const MidiCC({
    required this.controller,
    required this.value,
    this.label,
  });

  @override
  List<Object?> get props => [controller, value, label];
}
