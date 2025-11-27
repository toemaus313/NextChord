import 'dart:io';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:path_provider/path_provider.dart';
import '../../main.dart' as main;

/// Utility class for Windows iCloud Drive operations
class WindowsICloudUtils {
  /// Check if running on Windows platform
  static bool _isWindows() {
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Check if iCloud Drive is available and working on Windows
  static Future<bool> isICloudDriveAvailable() async {
    if (!_isWindows()) {
      main.myDebug("Not running on Windows, returning false");
      return false;
    }

    try {
      main.myDebug("Checking iCloud Drive availability on Windows...");

      final iCloudPath = await getICloudDrivePath();
      if (iCloudPath == null) {
        main.myDebug("iCloud Drive path not found");
        return false;
      }
      main.myDebug("Found iCloud Drive path: $iCloudPath");

      final iCloudDir = Directory(iCloudPath);
      if (!await iCloudDir.exists()) {
        main.myDebug("iCloud Drive directory does not exist: $iCloudPath");
        return false;
      }
      main.myDebug("iCloud Drive directory exists");

      // Ensure NextChord folder exists before testing write permissions
      main.myDebug("Ensuring NextChord folder exists...");
      final folderCreated = await ensureNextChordFolder();
      if (!folderCreated) {
        main.myDebug("Failed to create NextChord folder");
        return false;
      }
      main.myDebug("NextChord folder exists or was created successfully");

      // Test write permissions by attempting to create a temporary test file
      // This verifies iCloud sync is actually working, not just that folder exists
      main.myDebug("Testing write permissions in NextChord folder...");
      final testFile = File(
          '$iCloudPath\\iCloud~us~antonovich~nextchord\\NextChord\\.icloud_test_${DateTime.now().millisecondsSinceEpoch}.tmp');
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        main.myDebug(
            "iCloud Drive write test successful - sync appears to be working");
        return true;
      } catch (e) {
        main.myDebug(
            "iCloud Drive write test failed - sync may be disabled: $e");
        return false;
      }
    } catch (e) {
      main.myDebug("Error checking iCloud Drive availability on Windows: $e");
      return false;
    }
  }

  /// Get the iCloud Drive path on Windows
  /// Returns null if iCloud Drive is not installed/available
  static Future<String?> getICloudDrivePath() async {
    if (!_isWindows()) return null;

    try {
      // Get user profile directory
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile == null) {
        main.myDebug("USERPROFILE environment variable not found");
        return null;
      }

      // Common iCloud Drive paths on Windows
      final possiblePaths = [
        '$userProfile\\iCloudDrive', // Most common
        '$userProfile\\iCloud Drive', // With space
        '$userProfile\\OneDrive\\iCloudDrive', // If using OneDrive integration
        '$userProfile\\OneDrive\\iCloud Drive', // If using OneDrive integration with space
      ];

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          main.myDebug("Found iCloud Drive at: $path");
          return path;
        }
      }

      // Check registry as fallback (more complex, but more reliable)
      final registryPath = await _getICloudPathFromRegistry();
      if (registryPath != null) {
        return registryPath;
      }

      main.myDebug("iCloud Drive folder not found in common locations");
      return null;
    } catch (e) {
      main.myDebug("Error getting iCloud Drive path: $e");
      return null;
    }
  }

  /// Get iCloud Drive path from Windows registry
  /// This is more reliable but requires additional complexity
  static Future<String?> _getICloudPathFromRegistry() async {
    if (!_isWindows()) return null;

    try {
      // For now, return null - registry access would require additional packages
      // Could be implemented later with 'win32_registry' package if needed
      // Registry key: HKEY_CURRENT_USER\Software\Apple Inc.\iCloud
      // Value: iCloudDocumentsPath
      return null;
    } catch (e) {
      main.myDebug("Error reading iCloud path from registry: $e");
      return null;
    }
  }

  /// Ensure NextChord folder exists in iCloud Drive
  static Future<bool> ensureNextChordFolder() async {
    if (!_isWindows()) return false;

    try {
      final iCloudPath = await getICloudDrivePath();
      if (iCloudPath == null) return false;

      // Check for old Windows path and migrate files if needed
      await _migrateFromOldPath(iCloudPath);

      // Use app container path: <icloud root>/iCloud~us~antonovich~nextchord/NextChord/
      // This matches the iOS/macOS iCloud container structure
      final containerDir =
          Directory('$iCloudPath\\iCloud~us~antonovich~nextchord');
      if (!await containerDir.exists()) {
        await containerDir.create(recursive: true);
        main.myDebug(
            "Created container folder in iCloud Drive: ${containerDir.path}");
      }

      final nextChordDir =
          Directory('$iCloudPath\\iCloud~us~antonovich~nextchord\\NextChord');
      if (!await nextChordDir.exists()) {
        await nextChordDir.create(recursive: true);
        main.myDebug(
            "Created NextChord folder in iCloud Drive: ${nextChordDir.path}");
      }

      return await nextChordDir.exists();
    } catch (e) {
      main.myDebug("Error ensuring NextChord folder exists: $e");
      return false;
    }
  }

  /// Migrate files from old Windows paths to new app container path
  /// Checks both <icloud root>/NextChord and <icloud root>/Documents/NextChord
  static Future<void> _migrateFromOldPath(String iCloudPath) async {
    if (!_isWindows()) return;

    // Check old paths in priority order
    final oldPaths = [
      '$iCloudPath\\Documents\\NextChord', // Previous implementation
      '$iCloudPath\\NextChord', // Even older path
    ];

    for (final oldPath in oldPaths) {
      final oldDir = Directory(oldPath);
      if (!await oldDir.exists()) continue;

      main.myDebug("Found old NextChord folder at: $oldPath");
      await _migrateFilesFromDirectory(oldDir, iCloudPath);
      return; // Only migrate from first found old path
    }

    main.myDebug("No old Windows NextChord folder found, no migration needed");
  }

  /// Helper method to migrate files from an old directory
  static Future<void> _migrateFilesFromDirectory(
      Directory oldDir, String iCloudPath) async {
    try {
      main.myDebug("Found old Windows NextChord folder, starting migration...");

      final newPath = '$iCloudPath\\iCloud~us~antonovich~nextchord\\NextChord';
      final newDir = Directory(newPath);

      // Ensure new directory exists
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }

      // List all files in old directory
      await for (final entity in oldDir.list()) {
        if (entity is File) {
          final fileName = entity.path.split('\\').last;
          final newFile = File('$newPath\\$fileName');

          // Only migrate if file doesn't already exist in new location
          if (!await newFile.exists()) {
            try {
              main.myDebug("Migrating file: $fileName");
              await entity.copy(newFile.path);

              // Verify copy succeeded before deleting original
              if (await newFile.exists() &&
                  await newFile.length() == await entity.length()) {
                await entity.delete();
                main.myDebug("Successfully migrated and removed: $fileName");
              } else {
                main.myDebug("Migration verification failed for: $fileName");
              }
            } catch (e) {
              main.myDebug("Error migrating file $fileName: $e");
            }
          } else {
            main.myDebug(
                "File already exists in new location, skipping: $fileName");
          }
        }
      }

      // Try to remove old directory if it's empty
      try {
        if (await oldDir.list().isEmpty) {
          await oldDir.delete();
          main.myDebug("Removed old empty NextChord directory");
        }
      } catch (e) {
        main.myDebug("Could not remove old directory (may not be empty): $e");
      }

      main.myDebug("Migration completed");
    } catch (e) {
      main.myDebug("Error during migration: $e");
    }
  }

  /// Get the NextChord folder path in iCloud Drive
  static Future<String?> getNextChordFolderPath() async {
    if (!_isWindows()) return null;

    try {
      final iCloudPath = await getICloudDrivePath();
      if (iCloudPath == null) return null;

      // Use app container path: <icloud root>/iCloud~us~antonovich~nextchord/NextChord/
      // This matches the iOS/macOS iCloud container structure
      final nextChordPath =
          '$iCloudPath\\iCloud~us~antonovich~nextchord\\NextChord';
      final nextChordDir = Directory(nextChordPath);

      if (await nextChordDir.exists()) {
        return nextChordPath;
      }

      // Try to create it if it doesn't exist
      if (await ensureNextChordFolder()) {
        return nextChordPath;
      }

      return null;
    } catch (e) {
      main.myDebug("Error getting NextChord folder path: $e");
      return null;
    }
  }

  /// Check if a file exists in the NextChord iCloud folder
  static Future<bool> fileExists(String fileName) async {
    if (!_isWindows()) return false;

    try {
      main.myDebug("WindowsICloudUtils.fileExists() called for: $fileName");
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) {
        main.myDebug("NextChord folder path is null, returning false");
        return false;
      }

      final fullPath = '$folderPath\\$fileName';
      main.myDebug("Checking file existence at: $fullPath");
      final file = File(fullPath);
      final exists = await file.exists();
      main.myDebug("File exists result: $exists");
      return exists;
    } catch (e) {
      main.myDebug("Error checking file existence in iCloud Drive: $e");
      return false;
    }
  }

  /// Get file metadata (size, modification date)
  static Future<Map<String, dynamic>?> getFileMetadata(String fileName) async {
    if (!_isWindows()) return null;

    try {
      main.myDebug(
          "WindowsICloudUtils.getFileMetadata() called for: $fileName");
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) {
        main.myDebug("NextChord folder path is null, returning null metadata");
        return null;
      }

      final fullPath = '$folderPath\\$fileName';
      main.myDebug("Getting metadata for file at: $fullPath");
      final file = File(fullPath);
      if (!await file.exists()) {
        main.myDebug("File does not exist for metadata, returning null");
        return null;
      }

      final stat = await file.stat();
      final modifiedTime = stat.modified.toIso8601String();
      final fileSize = stat.size;

      main.myDebug("File metadata - size: $fileSize, modified: $modifiedTime");

      // Generate a simple hash for change detection (using size + modified time)
      final md5Checksum = '${fileSize}_$modifiedTime';

      final metadata = {
        'fileId': fileName, // Use filename as ID for consistency
        'modifiedTime': modifiedTime,
        'md5Checksum': md5Checksum,
        'headRevisionId': modifiedTime, // Use modified time as revision
      };

      main.myDebug("Returning metadata: $metadata");
      return metadata;
    } catch (e) {
      main.myDebug("Error getting file metadata from iCloud Drive: $e");
      return null;
    }
  }

  /// Upload file to iCloud Drive (copy to iCloud folder)
  static Future<bool> uploadFile(String localPath, String fileName) async {
    if (!_isWindows()) return false;

    try {
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) return false;

      final sourceFile = File(localPath);
      if (!await sourceFile.exists()) {
        main.myDebug("Source file does not exist: $localPath");
        return false;
      }

      final destFile = File('$folderPath\\$fileName');

      // Copy file to iCloud Drive
      await sourceFile.copy(destFile.path);
      main.myDebug("Successfully uploaded file to iCloud Drive: $fileName");

      return true;
    } catch (e) {
      main.myDebug("Error uploading file to iCloud Drive: $e");
      return false;
    }
  }

  /// Download file from iCloud Drive (copy to temp location)
  static Future<String?> downloadFile(String fileName) async {
    if (!_isWindows()) return null;

    try {
      main.myDebug("WindowsICloudUtils.downloadFile() called for: $fileName");
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) {
        main.myDebug("NextChord folder path is null, cannot download");
        return null;
      }

      final sourcePath = '$folderPath\\$fileName';
      main.myDebug("Attempting to download file from: $sourcePath");
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        main.myDebug("Source file does not exist in iCloud Drive: $fileName");
        return null;
      }

      // Check if file is fully downloaded (not a placeholder)
      main.myDebug("Checking if file is fully downloaded...");
      if (!await isFileFullyDownloaded(fileName)) {
        main.myDebug("File is not fully downloaded, skipping: $fileName");
        return null;
      }

      // Check file freshness - compare actual file time with current time
      final fileStat = await sourceFile.stat();
      final now = DateTime.now();
      final fileAge = now.difference(fileStat.modified);
      main.myDebug(
          "File age: ${fileAge.inMinutes} minutes (modified: ${fileStat.modified})");

      // If file is older than 5 minutes, it might be stale/cached
      if (fileAge.inMinutes > 5) {
        main.myDebug(
            "WARNING: File appears to be stale (${fileAge.inMinutes} minutes old). iCloud may not have synced latest version.");
      }

      // Add small debounce delay to avoid race conditions with iCloud sync daemon
      await Future.delayed(const Duration(milliseconds: 500));

      // Create temporary file
      main.myDebug("Creating temporary file...");
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}\\icloud_temp_${DateTime.now().millisecondsSinceEpoch}_$fileName');

      // Copy from iCloud Drive to temp location
      main.myDebug(
          "Copying file from iCloud to temp location: ${tempFile.path}");
      await sourceFile.copy(tempFile.path);
      main.myDebug("Successfully downloaded file from iCloud Drive: $fileName");

      // Verify the copied file has the expected content
      final tempStat = await tempFile.stat();
      main.myDebug(
          "Downloaded file size: ${tempStat.size}, modified: ${tempStat.modified}");

      return tempFile.path;
    } catch (e) {
      main.myDebug("Error downloading file from iCloud Drive: $e");
      return null;
    }
  }

  /// Check if file is fully downloaded (not a .icloud placeholder)
  static Future<bool> isFileFullyDownloaded(String fileName) async {
    if (!_isWindows()) return false;

    try {
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) return false;

      final file = File('$folderPath\\$fileName');
      if (!await file.exists()) return false;

      // Check for .icloud placeholder files
      final iCloudPlaceholder = File('$folderPath\\$fileName.icloud');
      if (await iCloudPlaceholder.exists()) {
        main.myDebug(
            "File is not fully downloaded (placeholder exists): $fileName");
        return false;
      }

      // Check file size - placeholder files are typically very small
      final stat = await file.stat();
      if (stat.size < 1024) {
        // Less than 1KB might be a placeholder
        try {
          final content = await file.readAsString();
          if (content.contains('iCloud') || content.contains('placeholder')) {
            main.myDebug("File appears to be a placeholder: $fileName");
            return false;
          }
        } catch (e) {
          // If we can't read as string, it might be binary or corrupted
          main.myDebug("File appears to be binary or corrupted: $fileName");
          return false;
        }
      }

      return true;
    } catch (e) {
      main.myDebug("Error checking if file is fully downloaded: $e");
      return false;
    }
  }
}
