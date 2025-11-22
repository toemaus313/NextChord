import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import '../../data/database/app_database.dart';
import '../../core/config/google_oauth_config.dart';

class GoogleDriveSyncService {
  static const String _backupFolderName = 'NextChord';
  static const String _backupFileName = 'nextchord_backup.db';
  static const String _syncMetadataFile = 'sync_metadata.json';

  final AppDatabase _database;
  final GoogleSignIn _googleSignIn;
  DateTime? _lastSyncTime;

  GoogleDriveSyncService(this._database)
      : _googleSignIn = GoogleDriveSyncService._createGoogleSignIn();

  static GoogleSignIn _createGoogleSignIn() {
    // Define the scopes needed for Google Drive access
    const scopes = [
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/drive.file',
    ];

    // For desktop platforms (Windows, Linux), we need OAuth credentials
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      if (GoogleOAuthConfig.isConfigured) {
        return GoogleSignIn(
          params: GoogleSignInParams(
            clientId: GoogleOAuthConfig.clientId,
            clientSecret: GoogleOAuthConfig.clientSecret,
            scopes: scopes,
          ),
        );
      } else {
        debugPrint(
            'Google Drive sync: OAuth credentials not configured for desktop platforms');
        return GoogleSignIn(); // Will fail gracefully
      }
    }

    // For mobile platforms and web
    return GoogleSignIn(
      params: GoogleSignInParams(
        scopes: scopes,
      ),
    );
  }

  static bool _isPlatformSupported() {
    if (kIsWeb) return true;

    final isMobileOrMac = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    final isDesktopWithConfig =
        (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux) &&
            GoogleOAuthConfig.isConfigured;

    return isMobileOrMac || isDesktopWithConfig;
  }

  bool get isPlatformSupported => _isPlatformSupported();

  Future<bool> isSignedIn() async {
    try {
      final credentials = await _googleSignIn.silentSignIn();
      return credentials != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signIn() async {
    if (!_isPlatformSupported()) {
      debugPrint('Google Drive sync is not supported on this platform');
      return false;
    }
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _lastSyncTime = null;
  }

  Future<void> sync() async {
    try {
      final credentials = await _googleSignIn.silentSignIn();
      if (credentials == null) {
        debugPrint('Not signed in to Google');
        return;
      }

      final driveApi = await _createDriveApi();
      final folderId = await _getOrCreateNextChordFolder(driveApi);
      final localDbPath = await _getDatabasePath();

      // Get sync metadata
      final metadata = await _getSyncMetadata(driveApi, folderId);
      final localDbModified = await File(localDbPath).lastModified();

      // Only sync if local changes or enough time has passed since last sync
      if (_lastSyncTime == null ||
          localDbModified.isAfter(_lastSyncTime!) ||
          _lastSyncTime!
              .isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
        final latestBackup = await _getLatestBackup(driveApi, folderId);

        if (latestBackup != null) {
          await _mergeWithRemote(driveApi, latestBackup, localDbPath, metadata);
        }

        // Upload current database as new backup
        await _uploadBackup(driveApi, folderId, localDbPath, metadata);
        _lastSyncTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
      rethrow;
    }
  }

  Future<void> handleInitialSync() async {
    try {
      final driveApi = await _createDriveApi();
      final folderId = await _getOrCreateNextChordFolder(driveApi);
      final backupPath = '$_backupFolderName/$_backupFileName';

      // Check if backup exists in Google Drive
      final existingBackup = await _findFileByPath(driveApi, backupPath);
      final localDbPath = await _getDatabasePath();

      if (existingBackup != null) {
        // Backup exists in Google Drive - ask user what to do
        final useCloud = await _showMigrationDialog(
          'Database Found in Google Drive',
          'A NextChord database was found in your Google Drive. Would you like to use this cloud database (this will replace your local data) or upload your local database to the cloud?',
          'Use Cloud Database',
          'Upload Local Database',
        );

        if (useCloud) {
          // Download and replace local database
          await _downloadAndReplaceDatabase(
              driveApi, existingBackup.id!, localDbPath);
        } else {
          // Upload local database to cloud
          await _uploadBackup(driveApi, folderId, localDbPath, {});
        }
      } else {
        // No backup exists - upload local database
        await _uploadBackup(driveApi, folderId, localDbPath, {});
      }

      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Initial sync failed: $e');
      rethrow;
    }
  }

  Future<bool> _showMigrationDialog(
    String title,
    String message,
    String confirmText,
    String cancelText,
  ) async {
    // This will be handled by the UI layer
    // For now, we'll return true to use cloud database by default
    return true; // Default to using cloud database
  }

  Future<void> _mergeWithRemote(
    drive.DriveApi driveApi,
    drive.File remoteFile,
    String localDbPath,
    Map<String, dynamic> metadata,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'temp_${Uuid().v4()}.db');
    final file = File(tempPath);

    try {
      // Download remote database
      final remoteData = await driveApi.files.get(
        remoteFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await remoteData.stream.fold<List<int>>(
        const [],
        (previous, element) => previous..addAll(element),
      );
      await file.writeAsBytes(bytes);

      // Merge changes
      await _database.mergeFromBackup(tempPath);
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Map<String, dynamic>> _getSyncMetadata(
    drive.DriveApi driveApi,
    String folderId,
  ) async {
    try {
      final response = await driveApi.files.list(
        q: "'$folderId' in parents and name='$_syncMetadataFile' and trashed=false",
        $fields: 'files(id)',
      );

      if (response.files?.isNotEmpty == true) {
        final file = response.files!.first;
        final metadata = await driveApi.files.get(
          file.id!,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final content = await metadata.stream
            .transform(utf8.decoder)
            .fold('', (previous, element) => previous + element);
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading sync metadata: $e');
    }

    return {
      'lastSyncTime': DateTime.now().toIso8601String(),
      'deviceId': Uuid().v4(),
    };
  }

  Future<void> _updateSyncMetadata(
    drive.DriveApi driveApi,
    String folderId,
    Map<String, dynamic> metadata,
  ) async {
    metadata['lastSyncTime'] = DateTime.now().toIso8601String();

    final response = await driveApi.files.list(
      q: "'$folderId' in parents and name='$_syncMetadataFile' and trashed=false",
      $fields: 'files(id)',
    );

    final content = utf8.encode(jsonEncode(metadata));
    final media = drive.Media(
      Stream.value(content).asBroadcastStream(),
      content.length,
    );

    if (response.files?.isNotEmpty == true) {
      // Update existing metadata file
      await driveApi.files.update(
        drive.File()..name = _syncMetadataFile,
        response.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      // Create new metadata file
      final file = drive.File()
        ..name = _syncMetadataFile
        ..parents = [folderId];

      await driveApi.files.create(file, uploadMedia: media);
    }
  }

  Future<drive.File?> _getLatestBackup(
    drive.DriveApi driveApi,
    String folderId,
  ) async {
    final response = await driveApi.files.list(
      q: "'$folderId' in parents and name='$_backupFileName' and trashed=false",
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,modifiedTime,md5Checksum)',
    );

    return response.files?.isNotEmpty == true ? response.files!.first : null;
  }

  Future<void> _uploadBackup(
    drive.DriveApi driveApi,
    String folderId,
    String localDbPath,
    Map<String, dynamic> metadata,
  ) async {
    // First, try to find and delete existing backup
    final existing = await _getLatestBackup(driveApi, folderId);
    if (existing != null) {
      await driveApi.files.delete(existing.id!);
    }

    final file = drive.File()
      ..name = _backupFileName
      ..parents = [folderId];

    final media = drive.Media(
      File(localDbPath).openRead(),
      await File(localDbPath).length(),
    );

    // Upload the database file
    await driveApi.files.create(file, uploadMedia: media);

    // Update sync metadata
    await _updateSyncMetadata(driveApi, folderId, metadata);
  }

  Future<void> _downloadAndReplaceDatabase(
    drive.DriveApi driveApi,
    String fileId,
    String localPath,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'temp_${Uuid().v4()}.db');
    final tempFile = File(tempPath);

    try {
      // Download the file
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await media.stream.fold<List<int>>(
        const [],
        (previous, element) => previous..addAll(element),
      );
      await tempFile.writeAsBytes(bytes);

      // Verify the database is valid
      final isValid = await _validateDatabase(tempPath);
      if (!isValid) {
        throw Exception('Downloaded database is not valid');
      }

      // Replace local database
      await tempFile.copy(localPath);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<bool> _validateDatabase(String path) async {
    try {
      // Basic validation - try to open the database
      final db = await sqlite.openDatabase(path);
      await db.query('sqlite_master');
      await db.close();
      return true;
    } catch (e) {
      debugPrint('Database validation failed: $e');
      return false;
    }
  }

  Future<drive.File?> _findFileByPath(
    drive.DriveApi driveApi,
    String path,
  ) async {
    final parts = p.split(path);
    String? parentId = 'root';

    for (var i = 0; i < parts.length; i++) {
      final isLast = i == parts.length - 1;
      final name = parts[i];

      final query =
          "name = '$name' and '$parentId' in parents and trashed = false";
      final response = await driveApi.files.list(
        q: query,
        $fields: 'files(id, name, mimeType)',
      );

      if (response.files == null || response.files!.isEmpty) {
        return null;
      }

      final file = response.files!.first;

      if (isLast) {
        return file;
      } else if (file.mimeType != 'application/vnd.google-apps.folder') {
        return null;
      }

      parentId = file.id;
    }

    return null;
  }

  Future<String> _getOrCreateNextChordFolder(drive.DriveApi driveApi) async {
    final folderPath = _backupFolderName;
    final existingFolder = await _findFileByPath(driveApi, folderPath);

    if (existingFolder != null) {
      return existingFolder.id!;
    }

    // Create the folder
    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await driveApi.files.create(folder);
    return createdFolder.id!;
  }

  Future<String> _getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'nextchord_db.sqlite');
  }

  Future<drive.DriveApi> _createDriveApi() async {
    final credentials = await _googleSignIn.silentSignIn();
    if (credentials == null) {
      throw Exception('Not signed in to Google');
    }

    // Create an authenticated HTTP client using the credentials
    // We need to extract the access token from the credentials
    final accessToken = credentials.accessToken;
    final authClient = authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken(
          'Bearer',
          accessToken,
          DateTime.now().add(const Duration(hours: 1)).toUtc(),
        ),
        null, // refreshToken
        // Scopes are already included in the sign-in process
        const [drive.DriveApi.driveFileScope],
      ),
    );

    return drive.DriveApi(authClient);
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
