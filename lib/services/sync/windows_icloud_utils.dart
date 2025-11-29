import 'dart:io';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:path_provider/path_provider.dart';
import 'package:nextchord/main.dart' as main;

/// Utility class for Windows iCloud Drive operations
class WindowsICloudUtils {
  /// Check if running on Windows platform
  static bool _isWindows() {
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Check if iCloud Drive is available and working on Windows
  static Future<bool> isICloudDriveAvailable() async {
    if (!_isWindows()) {
      return false;
    }

    try {
      final iCloudPath = await getICloudDrivePath();
      if (iCloudPath == null) {
        return false;
      }

      final iCloudDir = Directory(iCloudPath);
      if (!await iCloudDir.exists()) {
        return false;
      }

      // Ensure NextChord folder exists before testing write permissions
      final folderCreated = await ensureNextChordFolder();
      if (!folderCreated) {
        return false;
      }

      // Test write permissions by attempting to create a temporary test file
      // This verifies iCloud sync is actually working, not just that folder exists
      final testFile = File(
          '$iCloudPath\\iCloud~us~antonovich~nextchord\\NextChord\\.icloud_test_${DateTime.now().millisecondsSinceEpoch}.tmp');
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
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
          return path;
        }
      }

      // Check registry as fallback (more complex, but more reliable)
      final registryPath = await _getICloudPathFromRegistry();
      if (registryPath != null) {
        return registryPath;
      }

      return null;
    } catch (e) {
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
      }

      final nextChordDir =
          Directory('$iCloudPath\\iCloud~us~antonovich~nextchord\\NextChord');
      if (!await nextChordDir.exists()) {
        await nextChordDir.create(recursive: true);
      }

      return await nextChordDir.exists();
    } catch (e) {
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

      await _migrateFilesFromDirectory(oldDir, iCloudPath);
      return; // Only migrate from first found old path
    }
  }

  /// Helper method to migrate files from an old directory
  static Future<void> _migrateFilesFromDirectory(
      Directory oldDir, String iCloudPath) async {
    try {
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
              await entity.copy(newFile.path);

              // Verify copy succeeded before deleting original
              if (await newFile.exists() &&
                  await newFile.length() == await entity.length()) {
                await entity.delete();
              } else {}
            } catch (e) {
              main.myDebug(
                  '[WindowsICloudUtils] Failed to migrate file \'${entity.path}\': $e');
            }
          } else {}
        }
      }

      // Try to remove old directory if it's empty
      try {
        if (await oldDir.list().isEmpty) {
          await oldDir.delete();
        }
      } catch (e) {
        main.myDebug(
            '[WindowsICloudUtils] Failed to delete old NextChord directory: $e');
      }
    } catch (e) {
      main.myDebug(
          '[WindowsICloudUtils] _migrateFilesFromDirectory encountered error: $e');
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
      return null;
    }
  }

  /// Check if a file exists in the NextChord iCloud folder
  static Future<bool> fileExists(String fileName) async {
    if (!_isWindows()) return false;

    try {
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) {
        return false;
      }

      final fullPath = '$folderPath\\$fileName';
      final file = File(fullPath);
      final exists = await file.exists();
      return exists;
    } catch (e) {
      return false;
    }
  }

  /// Get file metadata (size, modification date)
  static Future<Map<String, dynamic>?> getFileMetadata(String fileName) async {
    if (!_isWindows()) return null;

    try {
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) {
        return null;
      }

      final fullPath = '$folderPath\\$fileName';
      final file = File(fullPath);
      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final modifiedTime = stat.modified.toIso8601String();
      final fileSize = stat.size;

      // Generate a simple hash for change detection (using size + modified time)
      final md5Checksum = '${fileSize}_$modifiedTime';

      final metadata = {
        'fileId': fileName, // Use filename as ID for consistency
        'modifiedTime': modifiedTime,
        'md5Checksum': md5Checksum,
        'headRevisionId': modifiedTime, // Use modified time as revision
      };

      return metadata;
    } catch (e) {
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
        return false;
      }

      final destFile = File('$folderPath\\$fileName');

      // Copy file to iCloud Drive
      await sourceFile.copy(destFile.path);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Download file from iCloud Drive (copy to temp location)
  static Future<String?> downloadFile(String fileName) async {
    if (!_isWindows()) return null;

    try {
      final folderPath = await getNextChordFolderPath();
      if (folderPath == null) {
        return null;
      }

      final sourcePath = '$folderPath\\$fileName';
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // Check if file is fully downloaded (not a placeholder)
      if (!await isFileFullyDownloaded(fileName)) {
        return null;
      }

      // Check file freshness - compare actual file time with current time
      final fileStat = await sourceFile.stat();
      final now = DateTime.now();
      final fileAge = now.difference(fileStat.modified);

      // If file is older than 5 minutes, it might be stale/cached
      if (fileAge.inMinutes > 5) {}

      // Add small debounce delay to avoid race conditions with iCloud sync daemon
      await Future.delayed(const Duration(milliseconds: 500));

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}\\icloud_temp_${DateTime.now().millisecondsSinceEpoch}_$fileName');

      // Copy from iCloud Drive to temp location
      await sourceFile.copy(tempFile.path);

      return tempFile.path;
    } catch (e) {
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
        return false;
      }

      // Check file size - placeholder files are typically very small
      final stat = await file.stat();
      if (stat.size < 1024) {
        // Less than 1KB might be a placeholder
        try {
          final content = await file.readAsString();
          if (content.contains('iCloud') || content.contains('placeholder')) {
            return false;
          }
        } catch (e) {
          // If we can't read as string, it might be binary or corrupted
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
