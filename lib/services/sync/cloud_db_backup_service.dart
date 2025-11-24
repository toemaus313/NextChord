import 'dart:io';
import 'dart:async';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'google_drive_sync_service.dart';
import '../../data/database/app_database.dart';

/// Service for managing cloud database backups
class CloudDbBackupService {
  static const String _backupFileName = 'nextchord_backup.db';
  final GoogleDriveSyncService _syncService;
  final AppDatabase _database;

  CloudDbBackupService({
    required GoogleDriveSyncService syncService,
    required AppDatabase database,
  })  : _syncService = syncService,
        _database = database;

  /// Check and maintain cloud backup on app startup
  /// Returns true if backup was created/updated, false if no action needed
  Future<bool> maintainCloudBackup() async {
    try {
      // Check if Google Drive is available
      if (!await _syncService.isSignedIn()) {
        return false;
      }

      // Create Drive API client
      final driveApi = await _syncService.createDriveApi();

      // Find or create backup folder
      final folderId = await _syncService.findOrCreateFolder(driveApi);
      if (folderId == null) {
        return false;
      }

      // Check if backup file exists
      final existingBackup = await _syncService.findExistingFile(
          driveApi, folderId, _backupFileName);

      if (existingBackup == null) {
        // CASE A: No backup exists - create initial backup
        await _uploadDatabaseBackup(driveApi, folderId);
        return true;
      } else {
        // CASE B: Backup exists - check if it needs refresh
        final backupModifiedTime = existingBackup.modifiedTime;
        if (backupModifiedTime == null) {
          await _uploadDatabaseBackup(driveApi, folderId);
          return true;
        }

        final now = DateTime.now();
        final ageDifference = now.difference(backupModifiedTime);

        if (ageDifference.inHours >= 1) {
          await _uploadDatabaseBackup(driveApi, folderId);
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
      // Check if Google Drive is available
      if (!await _syncService.isSignedIn()) {
        throw Exception('Google Drive not signed in');
      }

      // Create Drive API client
      final driveApi = await _syncService.createDriveApi();

      // Find backup folder
      final folderId = await _syncService.findOrCreateFolder(driveApi);
      if (folderId == null) {
        throw Exception('Failed to find backup folder');
      }

      // Find backup file
      final backupFile = await _syncService.findExistingFile(
          driveApi, folderId, _backupFileName);
      if (backupFile == null) {
        throw Exception('No cloud backup found');
      }

      // Download backup to temporary file
      final tempBackupPath =
          await _downloadBackupToTempFile(driveApi, backupFile.id!);

      // Validate downloaded backup
      if (!await _validateDatabaseFile(tempBackupPath)) {
        throw Exception('Downloaded backup file is not a valid database');
      }

      // Replace local database safely
      await _replaceLocalDatabase(tempBackupPath);

      // Clean up temporary file
      try {
        await File(tempBackupPath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload current local database to cloud backup
  Future<void> _uploadDatabaseBackup(
      drive.DriveApi driveApi, String folderId) async {
    try {
      // Get local database file path
      final dbFile = await _getLocalDatabaseFile();
      if (!await dbFile.exists()) {
        throw Exception('Local database file not found');
      }

      // Read database file
      final dbBytes = await dbFile.readAsBytes();

      // Create media stream
      final media = drive.Media(
        Stream.value(dbBytes),
        dbBytes.length,
      );

      // Check if backup file already exists
      final existingFile = await _syncService.findExistingFile(
          driveApi, folderId, _backupFileName);

      if (existingFile != null) {
        // Update existing file
        await driveApi.files.update(
          drive.File(), // Empty metadata - only updating content
          existingFile.id!,
          uploadMedia: media,
        );
      } else {
        // Create new file
        final fileMetadata = drive.File()
          ..name = _backupFileName
          ..parents = [folderId];

        await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Download backup file to temporary location
  Future<String> _downloadBackupToTempFile(
      drive.DriveApi driveApi, String fileId) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path,
          'temp_backup_${DateTime.now().millisecondsSinceEpoch}.db'));

      // Download file
      final response = await driveApi.files
          .get(fileId, downloadOptions: drive.DownloadOptions.fullMedia);
      final media = response as drive.Media;

      // Write to temporary file
      final fileSink = tempFile.openWrite();
      await media.stream.pipe(fileSink);
      await fileSink.close();

      return tempFile.path;
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
        } catch (restoreError) {
          // Ignore restore errors
        }
        rethrow;
      }

      // Clean up the safety backup after successful replacement
      try {
        await File(backupCurrentPath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get the local database file
  Future<File> _getLocalDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'nextchord_db.sqlite'));
  }

  /// Check if cloud backup exists
  Future<bool> hasCloudBackup() async {
    try {
      if (!await _syncService.isSignedIn()) {
        return false;
      }

      final driveApi = await _syncService.createDriveApi();
      final folderId = await _syncService.findOrCreateFolder(driveApi);
      if (folderId == null) {
        return false;
      }

      final backupFile = await _syncService.findExistingFile(
          driveApi, folderId, _backupFileName);
      return backupFile != null;
    } catch (e) {
      return false;
    }
  }
}
