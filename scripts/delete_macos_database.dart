#!/usr/bin/env dart

import 'dart:io';

/// Script to delete NextChord local databases for macOS debug instance
/// This script removes the local SQLite database and any backup files

void main() {
  print('🗑️  Deleting NextChord macOS local database...');

  // Get the macOS application documents directory
  final macDbPath =
      '${Platform.environment['HOME']}/Documents/nextchord_db.sqlite';

  // Check if database exists and delete it
  final dbFile = File(macDbPath);
  if (dbFile.existsSync()) {
    print('📁 Found macOS database at: $macDbPath');
    dbFile.deleteSync();
    print('✅ Deleted macOS database');
  } else {
    print('ℹ️  macOS database not found at: $macDbPath');
  }

  // Check for backup file and delete it
  final macBackupPath =
      '${Platform.environment['HOME']}/Documents/nextchord_db.sqlite.backup';
  final backupFile = File(macBackupPath);
  if (backupFile.existsSync()) {
    print('📁 Found macOS backup at: $macBackupPath');
    backupFile.deleteSync();
    print('✅ Deleted macOS backup');
  } else {
    print('ℹ️  macOS backup not found at: $macBackupPath');
  }

  // Also check in Library/Application Support (alternative location)
  final altDbPath =
      '${Platform.environment['HOME']}/Library/Application Support/nextchord_db.sqlite';
  final altDbFile = File(altDbPath);
  if (altDbFile.existsSync()) {
    print('📁 Found alternative macOS database at: $altDbPath');
    altDbFile.deleteSync();
    print('✅ Deleted alternative macOS database');
  } else {
    print('ℹ️  Alternative macOS database not found at: $altDbPath');
  }

  print('🎉 macOS database cleanup completed!');
}
