#!/usr/bin/env dart

import 'dart:io';

/// Script to delete ALL NextChord local databases (macOS and iOS simulators)
/// This script removes the local SQLite database and any backup files from all platforms

void main() {
  print('🗑️  Deleting ALL NextChord local databases...');

  // Delete macOS databases
  print('');
  print('🍎 Cleaning macOS databases...');
  _deleteMacosDatabases();

  // Delete iOS simulator databases
  print('');
  print('📱 Cleaning iOS simulator databases...');
  _deleteIosDatabases();

  print('');
  print('🎉 All NextChord databases have been deleted!');
  print('💡 Restart your app to create fresh databases.');
}

void _deleteMacosDatabases() {
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
}

void _deleteIosDatabases() {
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
}
