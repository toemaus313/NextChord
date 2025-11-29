import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/database/app_database.dart';
import '../../core/services/sync_service_locator.dart';
import 'library_sync_service.dart';
import 'windows_icloud_utils.dart';

/// Platform channel for iCloud Drive operations
class ICloudDriveChannel {
  static const MethodChannel _channel = MethodChannel('icloud_drive');

  /// Check if iCloud Drive is available and enabled
  static Future<bool> isICloudDriveAvailable() async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final bool result =
              await _channel.invokeMethod('isICloudDriveAvailable');
          return result;
        } catch (e) {
          return false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        return await WindowsICloudUtils.isICloudDriveAvailable();
      }
    }
    return false;
  }

  /// Get the URL for the NextChord folder in iCloud Drive
  static Future<String?> getICloudDriveFolderPath() async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final String? result =
              await _channel.invokeMethod('getICloudDriveFolderPath');
          return result;
        } catch (e) {
          return null;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        return await WindowsICloudUtils.getNextChordFolderPath();
      }
    }
    return null;
  }

  /// Ensure NextChord folder exists in iCloud Drive
  static Future<bool> ensureNextChordFolder() async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final bool result =
              await _channel.invokeMethod('ensureNextChordFolder');
          return result;
        } catch (e) {
          return false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        return await WindowsICloudUtils.ensureNextChordFolder();
      }
    }
    return false;
  }

  /// Upload file to iCloud Drive
  static Future<bool> uploadFile(String localPath, String relativePath) async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final bool result = await _channel.invokeMethod('uploadFile', {
            'localPath': localPath,
            'relativePath': relativePath,
          });
          return result;
        } catch (e) {
          return false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        try {
          return await WindowsICloudUtils.uploadFile(localPath, relativePath);
        } catch (e) {
          return false;
        }
      }
    }
    return false;
  }

  /// Download file from iCloud Drive
  static Future<String?> downloadFile(String relativePath) async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final String? result = await _channel.invokeMethod('downloadFile', {
            'relativePath': relativePath,
          });
          return result;
        } catch (e) {
          return null;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        try {
          return await WindowsICloudUtils.downloadFile(relativePath);
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  /// Get file metadata (size, modification date)
  static Future<Map<String, dynamic>?> getFileMetadata(
      String relativePath) async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          // Platform channels return a Map<Object?, Object?> by default; we
          // need to cast it to Map<String, dynamic> explicitly.
          final dynamic raw = await _channel.invokeMethod('getFileMetadata', {
            'relativePath': relativePath,
          });

          if (raw == null) {
            return null;
          }

          final result = (raw as Map).cast<String, dynamic>();
          return result;
        } catch (e) {
          return null;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        try {
          return await WindowsICloudUtils.getFileMetadata(relativePath);
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  /// Check if file exists in iCloud Drive
  static Future<bool> fileExists(String relativePath) async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          final bool result = await _channel.invokeMethod('fileExists', {
            'relativePath': relativePath,
          });
          return result;
        } catch (e) {
          return false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Use Windows iCloud Drive utilities
        try {
          return await WindowsICloudUtils.fileExists(relativePath);
        } catch (e) {
          return false;
        }
      }
    }
    return false;
  }
}

/// iCloud Drive sync service - mirrors GoogleDriveSyncService API
class ICloudSyncService {
  final LibrarySyncService _librarySyncService;

  // Metadata polling infrastructure
  Timer? _metadataPollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);
  bool _isPollingActive = false;

  // Backup configuration - same as Google Drive for compatibility
  static const String _libraryFileName = 'library.json';

  ICloudSyncService({
    required AppDatabase database,
  }) : _librarySyncService = LibrarySyncService(database);

  /// Check if iCloud Drive is supported on current platform
  static bool _isApplePlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool _isWindowsPlatform() {
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  static bool _isPlatformSupported() {
    if (kIsWeb) return false;
    return _isApplePlatform() || _isWindowsPlatform();
  }

  /// Check if iCloud Drive is available and enabled
  bool get isPlatformSupported => _isPlatformSupported();

  /// Check if user is signed in to iCloud Drive
  Future<bool> isSignedIn() async {
    try {
      if (!_isPlatformSupported()) {
        return false;
      }

      final result = await ICloudDriveChannel.isICloudDriveAvailable();
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Sign in to iCloud Drive (system-level, no app-level sign-in needed)
  Future<bool> signIn() async {
    try {
      if (!_isPlatformSupported()) {
        return false;
      }

      // iCloud Drive authentication is system-level
      // Just check if it's available and ensure folder exists
      final isAvailable = await ICloudDriveChannel.isICloudDriveAvailable();

      if (isAvailable) {
        final folderResult = await ICloudDriveChannel.ensureNextChordFolder();
        return folderResult;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Sign out from iCloud Drive (system-level, no app-level sign-out needed)
  Future<void> signOut() async {
    // No app-level sign-out needed for iCloud Drive
    // Just stop polling and clean up
    stopMetadataPolling();
  }

  /// Get metadata for library.json file without downloading content
  Future<ICloudLibraryMetadata?> getLibraryJsonMetadata() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        throw Exception('Not signed in to iCloud Drive');
      }

      // Ensure NextChord folder exists
      if (!await ICloudDriveChannel.ensureNextChordFolder()) {
        throw Exception('Failed to create/find NextChord folder');
      }

      // Check if library file exists
      final fileExists = await ICloudDriveChannel.fileExists(_libraryFileName);
      if (!fileExists) {
        return null;
      }

      // Get file metadata
      final metadata =
          await ICloudDriveChannel.getFileMetadata(_libraryFileName);
      if (metadata == null) {
        return null;
      }

      return ICloudLibraryMetadata.fromMap(metadata);
    } catch (e) {
      return null;
    }
  }

  /// Perform full sync with iCloud Drive
  Future<void> sync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        throw Exception('Not signed in to iCloud Drive');
      }

      // Ensure NextChord folder exists
      if (!await ICloudDriveChannel.ensureNextChordFolder()) {
        throw Exception('Failed to create/find NextChord folder');
      }

      // Perform JSON-based sync
      await _performJsonSync();
    } catch (e) {
      rethrow;
    }
  }

  /// Perform JSON-based sync with iCloud Drive
  Future<void> _performJsonSync() async {
    try {
      // Try to download existing library JSON from iCloud Drive
      String? remoteJson;
      ICloudLibraryMetadata? remoteMetadata;

      final fileExists = await ICloudDriveChannel.fileExists(_libraryFileName);

      if (fileExists) {
        try {
          final downloadedPath =
              await ICloudDriveChannel.downloadFile(_libraryFileName);

          if (downloadedPath != null) {
            final file = File(downloadedPath);
            remoteJson = await file.readAsString();

            // Validate JSON format
            jsonDecode(remoteJson); // Will throw if invalid

            // Get metadata for the remote file
            final metadata =
                await ICloudDriveChannel.getFileMetadata(_libraryFileName);

            if (metadata != null) {
              remoteMetadata = ICloudLibraryMetadata.fromMap(metadata);
            }

            // Clean up temporary file
            await file.delete();
          }
        } catch (e) {
          remoteJson = null;
          remoteMetadata = null;
        }
      }

      // Get current sync state to compare versions
      final syncState = await _librarySyncService.getSyncState();

      // Merge remote library into local database (if remote exists and is valid)
      if (remoteJson != null && remoteJson.isNotEmpty) {
        await _librarySyncService.importAndMergeLibraryFromJson(remoteJson);
      } else {}

      // Export the merged library (now includes remote changes)
      final mergedJson = await _librarySyncService.exportLibraryToJson();

      // Determine if upload is needed
      bool shouldUpload = false;
      if (remoteJson == null || remoteJson.isEmpty) {
        // No remote file exists, always upload
        shouldUpload = true;
      } else {
        // Check if merged library differs from remote
        shouldUpload =
            _librarySyncService.hasMergedLibraryChanged(mergedJson, remoteJson);
      }

      // Upload only if there are changes
      if (shouldUpload) {
        await _uploadLibraryJson(mergedJson);

        // Store the hash of uploaded content
        await _librarySyncService.storeUploadedLibraryHash(mergedJson);

        // Re-fetch metadata for library.json after upload so future polls
        // compare against the latest state
        final updatedMetadata = await getLibraryJsonMetadata();
        if (updatedMetadata != null) {
          await _librarySyncService.database.updateSyncState(
            lastRemoteVersion: syncState?.lastRemoteVersion ?? 0,
            lastSyncAt: DateTime.now(),
            remoteMetadata: DriveLibraryMetadata(
              fileId: updatedMetadata.fileId,
              modifiedTime: updatedMetadata.modifiedTime,
              md5Checksum: updatedMetadata.md5Checksum,
              headRevisionId: updatedMetadata.headRevisionId,
            ),
          );
        }
      } else {
        // Still update sync state to record that we checked for changes
        if (remoteMetadata != null) {
          await _librarySyncService.database.updateSyncState(
            lastRemoteVersion: syncState?.lastRemoteVersion ?? 0,
            lastSyncAt: DateTime.now(),
            remoteMetadata: DriveLibraryMetadata(
              fileId: remoteMetadata.fileId,
              modifiedTime: remoteMetadata.modifiedTime,
              md5Checksum: remoteMetadata.md5Checksum,
              headRevisionId: remoteMetadata.headRevisionId,
            ),
          );
        }
      }

      // After a successful JSON sync, purge old soft-deleted setlists
      await _librarySyncService.database
          .purgeDeletedSetlistsOlderThan(const Duration(minutes: 5));

      // Also purge permanently deleted songs after a 10-day retention window
      await _librarySyncService.database
          .purgeDeletedSongsOlderThan(const Duration(days: 10));
    } catch (e) {
      rethrow;
    }
  }

  /// Upload library JSON to iCloud Drive
  Future<void> _uploadLibraryJson(String jsonContent) async {
    try {
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path,
          'library_${DateTime.now().millisecondsSinceEpoch}.json'));
      await tempFile.writeAsString(jsonContent);

      // Upload to iCloud Drive
      final success =
          await ICloudDriveChannel.uploadFile(tempFile.path, _libraryFileName);

      // Clean up temporary file
      try {
        await tempFile.delete();
      } catch (e) {}

      if (!success) {
        throw Exception('Failed to upload library.json to iCloud Drive');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Handle initial sync when app starts
  Future<void> handleInitialSync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        return;
      }
    } catch (e) {}
  }

  /// Start metadata polling for automatic sync when app is active
  void startMetadataPolling() {
    if (_isPollingActive) {
      return;
    }

    _isPollingActive = true;

    _metadataPollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      if (!_isPollingActive) {
        timer.cancel();
        return;
      }

      try {
        // Get remote metadata without downloading content
        final remoteMetadata = await getLibraryJsonMetadata();

        if (remoteMetadata != null) {
          // Check if remote file has changed since last sync
          final hasRemoteChanges = await _librarySyncService.hasRemoteChanges(
            DriveLibraryMetadata(
              fileId: remoteMetadata.fileId,
              modifiedTime: remoteMetadata.modifiedTime,
              md5Checksum: remoteMetadata.md5Checksum,
              headRevisionId: remoteMetadata.headRevisionId,
            ),
          );

          if (hasRemoteChanges) {
            // Trigger full sync through the sync provider
            await SyncServiceLocator.triggerAutoSync();
          }
        }
      } catch (e) {}
    });
  }

  /// Stop metadata polling when app is paused/backgrounded
  void stopMetadataPolling() {
    if (!_isPollingActive) {
      return;
    }

    _isPollingActive = false;
    _metadataPollingTimer?.cancel();
    _metadataPollingTimer = null;
  }

  /// Check if metadata polling is currently active
  bool get isPollingActive => _isPollingActive;

  /// Find existing file in iCloud Drive (for compatibility with GoogleDriveSyncService API)
  Future<bool> findExistingFile(String folderId, String fileName) async {
    // In iCloud Drive, we just check if the file exists in the NextChord folder
    // folderId is ignored since we always use the NextChord folder
    return await ICloudDriveChannel.fileExists(fileName);
  }

  /// Find or create backup folder (for compatibility with GoogleDriveSyncService API)
  Future<String?> findOrCreateFolder() async {
    // In iCloud Drive, we ensure the NextChord folder exists and return a placeholder ID
    final success = await ICloudDriveChannel.ensureNextChordFolder();
    return success ? 'NextChord' : null;
  }

  /// Create Drive API equivalent for iCloud Drive (returns self for compatibility)
  Future<ICloudSyncService> createDriveApi() async {
    // Check authentication status
    final isAuthenticated = await isSignedIn();
    if (!isAuthenticated) {
      throw Exception('Not signed in to iCloud Drive');
    }
    return this;
  }
}

/// Model for iCloud Drive file metadata - mirrors DriveLibraryMetadata
class ICloudLibraryMetadata {
  final String fileId;
  final String modifiedTime;
  final String md5Checksum;
  final String headRevisionId;

  ICloudLibraryMetadata({
    required this.fileId,
    required this.modifiedTime,
    required this.md5Checksum,
    required this.headRevisionId,
  });

  /// Create from map returned by platform channel
  factory ICloudLibraryMetadata.fromMap(Map<String, dynamic> map) {
    return ICloudLibraryMetadata(
      fileId: map['fileId'] as String? ?? '',
      modifiedTime: map['modifiedTime'] as String? ?? '',
      md5Checksum: map['md5Checksum'] as String? ?? '',
      headRevisionId: map['headRevisionId'] as String? ?? '',
    );
  }

  /// Check if this metadata represents a different version than another
  bool hasChanged(ICloudLibraryMetadata? other) {
    if (other == null) return true;
    return md5Checksum != other.md5Checksum ||
        modifiedTime != other.modifiedTime ||
        headRevisionId != other.headRevisionId;
  }

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'modifiedTime': modifiedTime,
        'md5Checksum': md5Checksum,
        'headRevisionId': headRevisionId,
      };

  factory ICloudLibraryMetadata.fromJson(Map<String, dynamic> json) =>
      ICloudLibraryMetadata(
        fileId: json['fileId'] as String,
        modifiedTime: json['modifiedTime'] as String,
        md5Checksum: json['md5Checksum'] as String,
        headRevisionId: json['headRevisionId'] as String,
      );
}
