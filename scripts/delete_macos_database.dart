#!/usr/bin/env dart

import 'dart:io';

/// Script to delete Troubadour local databases for macOS debug instance
/// This script removes the local SQLite database and any backup files

void main() async {
  // Deleting Troubadour macOS local database...

  // Get the macOS application documents directory
  final macDbPath =
      '${Platform.environment['HOME']}/Documents/troubadour_db.sqlite';

  // Check if database exists and delete it
  final dbFile = File(macDbPath);
  if (dbFile.existsSync()) {
    // Found and deleted macOS database
    dbFile.deleteSync();
  }

  // Check for backup file and delete it
  final macBackupPath =
      '${Platform.environment['HOME']}/Documents/troubadour_db.sqlite.backup';
  final backupFile = File(macBackupPath);
  if (backupFile.existsSync()) {
    // Found and deleted macOS backup
    backupFile.deleteSync();
  }

  // Also check in Library/Application Support (alternative location)
  final altDbPath =
      '${Platform.environment['HOME']}/Library/Application Support/troubadour_db.sqlite';
  final altDbFile = File(altDbPath);
  if (altDbFile.existsSync()) {
    // Found and deleted alternative macOS database
    altDbFile.deleteSync();
  }

  // macOS database cleanup completed!
}
