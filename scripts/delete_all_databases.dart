#!/usr/bin/env dart

import 'dart:io';

/// Script to delete ALL NextChord local databases (macOS and iOS simulators)
/// This script removes the local SQLite database and any backup files from all platforms

void main() async {
  // Deleting ALL NextChord local databases...

  // Delete macOS databases
  // Cleaning macOS databases...
  _deleteMacosDatabases();

  // Delete iOS simulator databases
  // Cleaning iOS simulator databases...
  _deleteIosDatabases();

  // All NextChord databases have been deleted!
  // Restart your app to create fresh databases.
}

void _deleteMacosDatabases() {
  // Get the macOS application documents directory
  final macDbPath =
      '${Platform.environment['HOME']}/Documents/nextchord_db.sqlite';

  // Check if database exists and delete it
  final dbFile = File(macDbPath);
  if (dbFile.existsSync()) {
    // Found and deleted macOS database
    dbFile.deleteSync();
  }

  // Check for backup file and delete it
  final macBackupPath =
      '${Platform.environment['HOME']}/Documents/nextchord_db.sqlite.backup';
  final backupFile = File(macBackupPath);
  if (backupFile.existsSync()) {
    // Found and deleted macOS backup
    backupFile.deleteSync();
  }

  // Also check in Library/Application Support (alternative location)
  final altDbPath =
      '${Platform.environment['HOME']}/Library/Application Support/nextchord_db.sqlite';
  final altDbFile = File(altDbPath);
  if (altDbFile.existsSync()) {
    // Found and deleted alternative macOS database
    altDbFile.deleteSync();
  }
}

void _deleteIosDatabases() {
  // Find all iOS simulator NextChord databases
  final homeDir = Platform.environment['HOME']!;
  final simulatorDir =
      Directory('$homeDir/Library/Developer/CoreSimulator/Devices');

  if (!simulatorDir.existsSync()) {
    // iOS simulator directory not found
    return;
  }

  final iosDbs = <String>[];
  final iosBackups = <String>[];

  // Search for database files in all simulator devices
  for (final deviceDir in simulatorDir.listSync().whereType<Directory>()) {
    try {
      final dataDir =
          Directory('${deviceDir.path}/data/Containers/Data/Application');
      if (!dataDir.existsSync()) continue;

      for (final appDir in dataDir.listSync().whereType<Directory>()) {
        final documentsDir = Directory('${appDir.path}/Documents');
        if (!documentsDir.existsSync()) continue;

        for (final file in documentsDir.listSync().whereType<File>()) {
          if (file.path.endsWith('nextchord_db.sqlite')) {
            iosDbs.add(file.path);
          } else if (file.path.endsWith('nextchord_db.sqlite.backup')) {
            iosBackups.add(file.path);
          }
        }
      }
    } catch (e) {
      // Skip directories we can't access
    }
  }

  if (iosDbs.isEmpty) {
    // No iOS simulator databases found
  } else {
    // Found iOS simulator databases
    // Deleting iOS simulator databases...
    for (final dbPath in iosDbs) {
      try {
        File(dbPath).deleteSync();
        // Deleted: $dbPath
      } catch (e) {
        // Failed to delete database
      }
    }
  }

  if (iosBackups.isEmpty) {
    // No iOS simulator backup files found
  } else {
    // Found iOS simulator backup files
    // Deleting iOS simulator backup files...
    for (final backupPath in iosBackups) {
      try {
        File(backupPath).deleteSync();
        // Deleted: $backupPath
      } catch (e) {
        // Failed to delete backup
      }
    }
  }
}
