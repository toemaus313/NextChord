import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'midi_profile.dart';

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
  final String? profileId; // MIDI profile ID
  final String? duration; // Duration in MM:SS format
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
    this.profileId,
    this.duration,
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
    String? profileId,
    String? duration,
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
      profileId: profileId ?? this.profileId,
      duration: duration ?? this.duration,
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
        profileId,
        duration,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}
