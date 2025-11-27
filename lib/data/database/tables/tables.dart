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
  TextColumn get duration => text().nullable()(); // Duration in MM:SS format
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
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))(); // Soft delete flag

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
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))(); // Soft delete flag

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
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))(); // Soft delete flag

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for sync state tracking
@DataClassName('SyncStateModel')
class SyncState extends Table {
  IntColumn get id => integer()(); // Always 1 for singleton row
  TextColumn get deviceId => text()(); // Unique device identifier
  IntColumn get lastRemoteVersion => integer()
      .withDefault(const Constant(0))(); // Last library version from remote
  DateTimeColumn get lastSyncAt =>
      dateTime().nullable()(); // Last successful sync timestamp

  // Google Drive metadata fields for efficient change detection
  TextColumn get lastRemoteFileId => text().nullable()(); // Last seen file ID
  TextColumn get lastRemoteModifiedTime =>
      text().nullable()(); // Last seen modified time
  TextColumn get lastRemoteMd5Checksum =>
      text().nullable()(); // Last seen MD5 checksum
  TextColumn get lastRemoteHeadRevisionId =>
      text().nullable()(); // Last seen head revision ID
  TextColumn get lastUploadedLibraryHash =>
      text().nullable()(); // Hash of last uploaded library content

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for Pedal Mappings (keyboard/MIDI pedal key bindings)
@DataClassName('PedalMappingModel')
class PedalMappings extends Table {
  TextColumn get id => text()();
  TextColumn get key =>
      text()(); // Key identifier (e.g., 'upArrow', 'downArrow', MIDI note)
  TextColumn get action =>
      text()(); // JSON object describing the action (e.g., '{"nextSongSection": {}}')
  TextColumn get description =>
      text().nullable()(); // User-friendly description
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  // MIDI-specific fields for enhanced control
  TextColumn get deviceId =>
      text().nullable()(); // Specific MIDI device ID, null = any device
  TextColumn get messageType =>
      text().nullable()(); // 'cc' or 'pc', null = legacy keyboard mapping
  IntColumn get channel =>
      integer().nullable()(); // MIDI channel 0-15, null = any
  IntColumn get number => integer().nullable()(); // CC/PC number 0-127
  IntColumn get valueMin =>
      integer().nullable()(); // Minimum CC value for range matching
  IntColumn get valueMax =>
      integer().nullable()(); // Maximum CC value for range matching

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table for tracking deletions to sync across devices
@DataClassName('DeletionTrackingModel')
class DeletionTracking extends Table {
  TextColumn get id => text()(); // Unique tracking ID
  TextColumn get entityType => text()(); // 'setlist', 'song', etc.
  TextColumn get entityId => text()(); // The ID of the deleted entity
  IntColumn get deletedAt => integer()(); // When deletion occurred (epoch ms)
  TextColumn get deviceId => text()(); // Which device performed the deletion

  @override
  Set<Column> get primaryKey => {id};
}
