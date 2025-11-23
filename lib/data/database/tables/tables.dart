import 'package:drift/drift.dart';

/// Drift table for Songs
@DataClassName('SongModel')
class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get body => text()(); // ChordPro formatted text
  TextColumn get key => text().withDefault(const Constant('C'))();
  IntColumn get capo => integer().withDefault(const Constant(0))();
  IntColumn get bpm => integer().withDefault(const Constant(120))();
  TextColumn get timeSignature => text().withDefault(const Constant('4/4'))();
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array stored as TEXT
  TextColumn get audioFilePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get profileId => text().nullable()(); // Reference to MIDI profile
  IntColumn get createdAt => integer()(); // Stored as epoch milliseconds
  IntColumn get updatedAt => integer()(); // Stored as epoch milliseconds
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))(); // Soft delete flag

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for MIDI Mappings
@DataClassName('MidiMappingModel')
class MidiMappings extends Table {
  TextColumn get id => text()();
  TextColumn get songId => text()();
  IntColumn get programChangeNumber => integer().nullable()(); // 0-127
  TextColumn get controlChanges =>
      text().withDefault(const Constant('[]'))(); // JSON array of MidiCC
  BoolColumn get timing => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for MIDI Profiles (reusable MIDI configurations)
@DataClassName('MidiProfileModel')
class MidiProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // User-friendly profile name
  IntColumn get programChangeNumber => integer().nullable()(); // 0-127
  TextColumn get controlChanges =>
      text().withDefault(const Constant('[]'))(); // JSON array of MidiCC
  BoolColumn get timing => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for Setlists (collection of songs for a performance)
@DataClassName('SetlistModel')
class Setlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get items => text()(); // JSON array of SetlistItems
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()(); // Path to 200x200px image
  BoolColumn get setlistSpecificEditsEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
