#!/usr/bin/env dart

import 'dart:io';

/// Script to delete NextChord local databases for iOS simulator debug instances
/// This script removes the local SQLite database and any backup files from iOS simulators

void main() {
  print('🗑️  Deleting NextChord iOS simulator local databases...');

  // Find all iOS simulator NextChord databases
  final homeDir = Platform.environment['HOME']!;
  final simulatorDir =
      Directory('$homeDir/Library/Developer/CoreSimulator/Devices');

  if (!simulatorDir.existsSync()) {
    print('ℹ️  iOS simulator directory not found');
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
    print('ℹ️  No iOS simulator databases found');
  } else {
    print('📁 Found iOS simulator databases:');
    for (final dbPath in iosDbs) {
      print('  - $dbPath');
    }

    print('');
    print('🗑️  Deleting iOS simulator databases...');
    for (final dbPath in iosDbs) {
      try {
        File(dbPath).deleteSync();
        print('✅ Deleted: $dbPath');
      } catch (e) {
        print('❌ Failed to delete $dbPath: $e');
      }
    }
  }

  if (iosBackups.isEmpty) {
    print('ℹ️  No iOS simulator backup files found');
  } else {
    print('');
    print('📁 Found iOS simulator backup files:');
    for (final backupPath in iosBackups) {
      print('  - $backupPath');
    }

    print('');
    print('🗑️  Deleting iOS simulator backup files...');
    for (final backupPath in iosBackups) {
      try {
        File(backupPath).deleteSync();
        print('✅ Deleted: $backupPath');
      } catch (e) {
        print('❌ Failed to delete $backupPath: $e');
      }
    }
  }

  print('');
  print('🎉 iOS simulator database cleanup completed!');
}
