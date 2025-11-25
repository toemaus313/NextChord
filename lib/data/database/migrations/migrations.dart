import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../app_database.dart';

/// Database migration strategies
class DatabaseMigrations {
  /// Migration strategy for AppDatabase
  static MigrationStrategy get migrationStrategy => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Handle schema migrations here when you update the database
          if (from <= 1 && to >= 2) {
            // Add isDeleted column to songs table
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.songs, db.songs.isDeleted);
            } catch (e) {}
          }
          if (from <= 2 && to >= 3) {
            // Add imagePath column to setlists table
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.setlists, db.setlists.imagePath);
            } catch (e) {}
          }
          if (from <= 3 && to >= 4) {
            // Add setlistSpecificEditsEnabled column with default true
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(
                  db.setlists, db.setlists.setlistSpecificEditsEnabled);
            } catch (e) {}
          }
          if (from <= 4 && to >= 5) {
            // Create midi_mappings table
            final db = m.database as AppDatabase;
            try {
              await m.createTable(db.midiMappings);
            } catch (e) {}
          }
          if (from <= 5 && to >= 6) {
            // Create midi_profiles table and add profile_id to songs
            final db = m.database as AppDatabase;
            try {
              await m.createTable(db.midiProfiles);
            } catch (e) {}
            try {
              await m.addColumn(db.songs, db.songs.profileId);
            } catch (e) {}
          }
          if (from <= 6 && to >= 7) {
            // Add isDeleted column to setlists table
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.setlists, db.setlists.isDeleted);
            } catch (e) {}
          }
          if (from <= 7 && to >= 8) {
            // Add isDeleted columns to midi_mappings and midi_profiles tables
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.midiMappings, db.midiMappings.isDeleted);
            } catch (e) {}
            try {
              await m.addColumn(db.midiProfiles, db.midiProfiles.isDeleted);
            } catch (e) {}
            try {
              await m.createTable(db.syncState);
            } catch (e) {}

            // Initialize sync state with generated device ID
            try {
              final deviceId = DatabaseMigrations._generateDeviceId();
              await db.into(db.syncState).insert(
                    SyncStateCompanion(
                      id: const Value(1),
                      deviceId: Value(deviceId),
                      lastRemoteVersion: const Value(0),
                      lastSyncAt: const Value(null),
                    ),
                  );
            } catch (e) {}
          }
          if (from <= 8 && to >= 9) {
            // Add Google Drive metadata columns to sync_state table
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.syncState, db.syncState.lastRemoteFileId);
            } catch (e) {}
            try {
              await m.addColumn(
                  db.syncState, db.syncState.lastRemoteModifiedTime);
            } catch (e) {}
            try {
              await m.addColumn(
                  db.syncState, db.syncState.lastRemoteMd5Checksum);
            } catch (e) {}
            try {
              await m.addColumn(
                  db.syncState, db.syncState.lastRemoteHeadRevisionId);
            } catch (e) {}
            try {
              await m.addColumn(
                  db.syncState, db.syncState.lastUploadedLibraryHash);
            } catch (e) {}
          }
          if (from <= 9 && to >= 10) {
            // Create pedal_mappings table
            final db = m.database as AppDatabase;
            try {
              await m.createTable(db.pedalMappings);
            } catch (e) {}
          }
          if (from <= 10 && to >= 11) {
            // Add MIDI-specific fields to pedal_mappings table
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.pedalMappings, db.pedalMappings.deviceId);
            } catch (e) {}
            try {
              await m.addColumn(db.pedalMappings, db.pedalMappings.messageType);
            } catch (e) {}
            try {
              await m.addColumn(db.pedalMappings, db.pedalMappings.channel);
            } catch (e) {}
            try {
              await m.addColumn(db.pedalMappings, db.pedalMappings.number);
            } catch (e) {}
            try {
              await m.addColumn(db.pedalMappings, db.pedalMappings.valueMin);
            } catch (e) {}
            try {
              await m.addColumn(db.pedalMappings, db.pedalMappings.valueMax);
            } catch (e) {}
          }
          if (from <= 11 && to >= 12) {
            // Add duration column to songs table
            final db = m.database as AppDatabase;
            try {
              await m.addColumn(db.songs, db.songs.duration);
            } catch (e) {}
          }
        },
      );

  /// Custom database operations for backward compatibility
  static Future<void> ensureMidiProfilesTable(AppDatabase db) async {
    try {
      // Try to query the midi_profiles table
      await db.customSelect('SELECT COUNT(*) FROM midi_profiles').get();
    } catch (e) {
      try {
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS midi_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            program_change_number INTEGER,
            control_changes TEXT NOT NULL DEFAULT '[]',
            timing BOOLEAN NOT NULL DEFAULT FALSE,
            notes TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      } catch (createError) {
        rethrow;
      }
    }

    // Always check if profileId column exists in Songs table (moved outside the catch block)
    try {
      await db.customSelect('SELECT profile_id FROM songs LIMIT 1').get();
    } catch (e) {
      try {
        await db
            .customStatement('ALTER TABLE songs ADD COLUMN profile_id TEXT');
      } catch (alterError) {
        rethrow;
      }
    }
  }

  /// Merge database from backup
  static Future<void> mergeFromBackup(AppDatabase db, String backupPath) async {
    await db.customStatement('ATTACH DATABASE ? AS remote', [backupPath]);
    try {
      await _mergeTable(
        db,
        tableName: 'songs',
        primaryKeys: ['id'],
        columns: [
          'title',
          'artist',
          'body',
          'key',
          'capo',
          'bpm',
          'time_signature',
          'tags',
          'audio_file_path',
          'notes',
          'profile_id',
          'created_at',
          'updated_at',
          'is_deleted',
        ],
      );

      await _mergeTable(
        db,
        tableName: 'setlists',
        primaryKeys: ['id'],
        columns: [
          'name',
          'items',
          'notes',
          'image_path',
          'setlist_specific_edits_enabled',
          'created_at',
          'updated_at',
        ],
      );

      await _mergeTable(
        db,
        tableName: 'midi_profiles',
        primaryKeys: ['id'],
        columns: [
          'name',
          'program_change_number',
          'control_changes',
          'timing',
          'notes',
          'created_at',
          'updated_at',
        ],
      );

      await _mergeTable(
        db,
        tableName: 'midi_mappings',
        primaryKeys: ['id'],
        columns: [
          'song_id',
          'program_change_number',
          'control_changes',
          'timing',
          'notes',
          'created_at',
          'updated_at',
        ],
      );
    } finally {
      await db.customStatement('DETACH DATABASE remote');
    }
  }

  static Future<void> _mergeTable(
    AppDatabase db, {
    required String tableName,
    required List<String> primaryKeys,
    required List<String> columns,
  }) async {
    final allColumns = [...primaryKeys, ...columns];
    final columnsStr = allColumns.join(', ');
    final joinCondition =
        primaryKeys.map((key) => '$tableName.$key = remote.$key').join(' AND ');

    // Insert new records that don't exist locally
    await db.customStatement('''
      INSERT OR IGNORE INTO $tableName ($columnsStr)
      SELECT $columnsStr
      FROM remote.$tableName remote
    ''');

    // Update existing records where remote is newer
    await db.customStatement('''
      UPDATE $tableName
      SET ${columns.map((c) => '$c = remote.$c').join(', ')}
      FROM remote.$tableName remote
      WHERE $joinCondition
      AND remote.updated_at > $tableName.updated_at
    ''');
  }

  /// Generate a unique device ID for sync tracking
  static String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));
    return 'device_${timestamp}_${randomBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
