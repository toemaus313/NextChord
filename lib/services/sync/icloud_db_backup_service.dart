import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'icloud_sync_service.dart';
import '../../data/database/app_database.dart';

/// Service for managing iCloud Drive database backups
class ICloudDbBackupService {
  // Legacy backup filename kept for backward compatibility with existing cloud backups
  static const String _backupFileName = 'nextchord_backup.db';
  final ICloudSyncService _syncService;
  final AppDatabase _database;

  ICloudDbBackupService({
    required ICloudSyncService syncService,
    required AppDatabase database,
  })  : _syncService = syncService,
        _database = database;

  /// Check and maintain cloud backup on app startup
  /// Returns true if backup was created/updated, false if no action needed
  Future<bool> maintainCloudBackup() async {
    try {
      // Check if iCloud Drive is available
      if (!await _syncService.isSignedIn()) {
        return false;
      }

      // Find or create backup folder
      final folderId = await _syncService.findOrCreateFolder();
      if (folderId == null) {
        return false;
      }

      // Check if backup file exists
      final existingBackup =
          await _syncService.findExistingFile(folderId, _backupFileName);

      if (!existingBackup) {
        // CASE A: No backup exists - create initial backup
        await _uploadDatabaseBackup();
        return true;
      } else {
        // CASE B: Backup exists - check if it needs refresh
        final metadata = await _syncService.getLibraryJsonMetadata();
        if (metadata == null) {
          await _uploadDatabaseBackup();
          return true;
        }

        final backupModifiedTime = DateTime.tryParse(metadata.modifiedTime);
        if (backupModifiedTime == null) {
          await _uploadDatabaseBackup();
          return true;
        }

        final now = DateTime.now();
        final ageDifference = now.difference(backupModifiedTime);

        if (ageDifference.inHours >= 1) {
          await _uploadDatabaseBackup();
          return true;
        } else {
          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }

  /// Restore database from cloud backup
  /// Returns true if restore was successful, false otherwise
  Future<bool> restoreFromCloudBackup() async {
    try {
      // Check if iCloud Drive is available
      if (!await _syncService.isSignedIn()) {
        throw Exception('iCloud Drive not signed in');
      }

      // Find backup folder
      final folderId = await _syncService.findOrCreateFolder();
      if (folderId == null) {
        throw Exception('Failed to find backup folder');
      }

      // Find backup file
      final backupFile =
          await _syncService.findExistingFile(folderId, _backupFileName);
      if (!backupFile) {
        throw Exception('No cloud backup found');
      }

      // Download backup to temporary file
      final tempBackupPath = await _downloadBackupToTempFile();

      // Validate downloaded backup
      if (!await _validateDatabaseFile(tempBackupPath)) {
        throw Exception('Downloaded backup file is not a valid database');
      }

      // Replace local database safely
      await _replaceLocalDatabase(tempBackupPath);

      // Clean up temporary file
      try {
        await File(tempBackupPath).delete();
      } catch (e) {}

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload current local database to cloud backup
  Future<void> _uploadDatabaseBackup() async {
    try {
      // Get local database file path
      final dbFile = await _getLocalDatabaseFile();
      if (!await dbFile.exists()) {
        throw Exception('Local database file not found');
      }

      // Upload to iCloud Drive using platform channel
      final success =
          await ICloudDriveChannel.uploadFile(dbFile.path, _backupFileName);

      if (!success) {
        throw Exception('Failed to upload database backup to iCloud Drive');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Download backup file to temporary location
  Future<String> _downloadBackupToTempFile() async {
    try {
      // Download file from iCloud Drive using platform channel
      final downloadedPath =
          await ICloudDriveChannel.downloadFile(_backupFileName);
      if (downloadedPath == null) {
        throw Exception('Failed to download backup file from iCloud Drive');
      }

      return downloadedPath;
    } catch (e) {
      rethrow;
    }
  }

  /// Validate that downloaded file is a valid SQLite database
  Future<bool> _validateDatabaseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists() || await file.length() < 1024) {
        return false;
      }

      // Basic SQLite validation - check for SQLite header
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes);

      if (!header.startsWith('SQLite format 3')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Replace local database with downloaded backup
  Future<void> _replaceLocalDatabase(String backupFilePath) async {
    try {
      // Get local database file path
      final localDbFile = await _getLocalDatabaseFile();
      final backupFile = File(backupFilePath);

      // Create backup of current database before replacement
      final backupCurrentPath =
          '${localDbFile.path}.backup_${DateTime.now().millisecondsSinceEpoch}';
      await localDbFile.copy(backupCurrentPath);

      try {
        // Close database connection
        await _database.close();

        // Replace the database file
        await backupFile.copy(localDbFile.path);
      } catch (e) {
        // If replacement fails, try to restore from backup
        try {
          if (await File(backupCurrentPath).exists()) {
            await File(backupCurrentPath).copy(localDbFile.path);
          }
        } catch (restoreError) {}
        rethrow;
      }

      // Clean up the safety backup after successful replacement
      try {
        await File(backupCurrentPath).delete();
      } catch (e) {}
    } catch (e) {
      rethrow;
    }
  }

  /// Get the local database file
  Future<File> _getLocalDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    // Legacy database filename kept for backward compatibility with existing user data
    return File(p.join(dbFolder.path, 'nextchord_db.sqlite'));
  }

  /// Check if cloud backup exists
  Future<bool> hasCloudBackup() async {
    try {
      if (!await _syncService.isSignedIn()) {
        return false;
      }

      final folderId = await _syncService.findOrCreateFolder();
      if (folderId == null) {
        return false;
      }

      final backupFile =
          await _syncService.findExistingFile(folderId, _backupFileName);
      return backupFile;
    } catch (e) {
      return false;
    }
  }
}
