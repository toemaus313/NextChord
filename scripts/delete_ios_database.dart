#!/usr/bin/env dart

import 'dart:io';

/// Script to delete NextChord local databases for iOS simulator debug instances
/// This script removes the local SQLite database and any backup files from iOS simulators

void main() async {
  // Deleting NextChord iOS simulator local databases...

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

  // iOS simulator database cleanup completed!
}
