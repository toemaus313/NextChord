import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:flutter/foundation.dart';

class DatabaseMerger {
  final sqlite.Database localDb;
  final String tempDbPath;

  DatabaseMerger(this.localDb, this.tempDbPath);

  Future<void> mergeFromBackup() async {
    // Attach the remote database
    await localDb.execute('ATTACH DATABASE ? AS remote', [tempDbPath]);

    try {
      // Merge songs table
      await _mergeTable(
        'songs',
        ['id'],
        [
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
          'updated_at',
          'is_deleted'
        ],
      );

      // Merge setlists table
      await _mergeTable(
        'setlists',
        ['id'],
        [
          'name',
          'items',
          'notes',
          'image_path',
          'setlist_specific_edits_enabled',
          'updated_at'
        ],
      );

      // Merge profiles table
      await _mergeTable(
        'profiles',
        ['id'],
        ['name', 'bpm', 'key', 'capo', 'transpose', 'updated_at'],
      );

      // Merge other tables as needed...
    } finally {
      // Ensure we always detach the remote database
      await localDb.execute('DETACH DATABASE remote');
    }
  }

  Future<void> _mergeTable(
    String tableName,
    List<String> primaryKeys,
    List<String> columns,
  ) async {
    try {
      final allColumns = [...primaryKeys, ...columns];
      final columnsStr = allColumns.join(', ');
      final updateSet = columns.map((c) => '$c = remote.$c').join(', ');
      final joinCondition =
          primaryKeys.map((k) => 'local.$k = remote.$k').join(' AND ');

      // Insert new records from remote that don't exist locally
      await localDb.execute('''
        INSERT OR IGNORE INTO $tableName ($columnsStr)
        SELECT $columnsStr 
        FROM remote.$tableName remote
      ''');

      // Update existing records where remote is newer
      await localDb.execute('''
        UPDATE $tableName
        SET $updateSet
        FROM remote.$tableName remote
        WHERE $joinCondition
        AND (remote.updated_at > $tableName.updated_at 
             OR (remote.updated_at IS NULL AND $tableName.updated_at IS NULL)
             OR (remote.updated_at = $tableName.updated_at AND remote.id > $tableName.id))
      ''');

      debugPrint('Successfully merged $tableName table');
    } catch (e) {
      debugPrint('Error merging $tableName: $e');
      rethrow;
    }
  }
}
