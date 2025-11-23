import 'package:equatable/equatable.dart';

/// Setlist domain entity
class Setlist extends Equatable {
  final String id;
  final String name;
  final List<SetlistItem> items;
  final String notes;
  final String? imagePath;
  final bool setlistSpecificEditsEnabled;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Setlist({
    required this.id,
    required this.name,
    required this.items,
    required this.notes,
    this.imagePath,
    required this.setlistSpecificEditsEnabled,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Setlist copyWith({
    String? id,
    String? name,
    List<SetlistItem>? items,
    String? notes,
    String? imagePath,
    bool? setlistSpecificEditsEnabled,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      setlistSpecificEditsEnabled:
          setlistSpecificEditsEnabled ?? this.setlistSpecificEditsEnabled,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        items,
        notes,
        imagePath,
        setlistSpecificEditsEnabled,
        isDeleted,
        createdAt,
        updatedAt,
      ];
}

/// Base class for setlist items
abstract class SetlistItem extends Equatable {
  final String id;
  final int order;

  const SetlistItem({
    required this.id,
    required this.order,
  });

  @override
  List<Object?> get props => [id, order];
}

/// Song item in a setlist
class SetlistSongItem extends SetlistItem {
  final String songId;
  final String? text; // Optional custom text/notes for this song
  final int transposeSteps; // Transpose steps for this song in setlist
  final int capo; // Capo position for this song in setlist

  const SetlistSongItem({
    required super.id,
    required super.order,
    required this.songId,
    this.text,
    this.transposeSteps = 0,
    this.capo = 0,
  });

  SetlistSongItem copyWith({
    String? id,
    int? order,
    String? songId,
    String? text,
    int? transposeSteps,
    int? capo,
  }) {
    return SetlistSongItem(
      id: id ?? this.id,
      order: order ?? this.order,
      songId: songId ?? this.songId,
      text: text ?? this.text,
      transposeSteps: transposeSteps ?? this.transposeSteps,
      capo: capo ?? this.capo,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, songId, text, transposeSteps, capo];
}

/// Divider item in a setlist
class SetlistDividerItem extends SetlistItem {
  final String label;
  final String color; // Color for the divider

  const SetlistDividerItem({
    required super.id,
    required super.order,
    required this.label,
    this.color = 'blue',
  });

  SetlistDividerItem copyWith({
    String? id,
    int? order,
    String? label,
    String? color,
  }) {
    return SetlistDividerItem(
      id: id ?? this.id,
      order: order ?? this.order,
      label: label ?? this.label,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [...super.props, label, color];
}
