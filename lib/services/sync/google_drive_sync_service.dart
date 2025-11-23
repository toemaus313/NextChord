import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, VoidCallback;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/google_oauth_config.dart';

class GoogleDriveSyncService {
  final VoidCallback? _onDatabaseReplaced; // Callback to trigger reconnection

  static GoogleSignIn? _googleSignIn;
  static String? _windowsAccessToken;
  static String? _windowsRefreshToken;
  static const String _windowsAuthRedirectUri = 'http://localhost:8000';
  static HttpServer? _authServer;

  // SharedPreferences keys for Windows token persistence
  static const String _accessTokenKey = 'windows_access_token';
  static const String _refreshTokenKey = 'windows_refresh_token';

  // Static flag to prevent multiple database factory assignments
  static bool _databaseFactoryInitialized = false;

  static GoogleSignIn get _googleSignInInstance {
    _googleSignIn ??= GoogleSignIn(
      clientId: GoogleOAuthConfig.clientId,
      scopes: [
        drive.DriveApi.driveScope,
        drive.DriveApi.driveFileScope,
      ],
    );
    return _googleSignIn!;
  }

  static bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  /// Save Windows tokens to SharedPreferences for persistence
  static Future<void> _saveWindowsTokens(
      String accessToken, String? refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      if (refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
    } catch (e) {}
  }

  /// Load Windows tokens from SharedPreferences on app startup
  static Future<void> _loadWindowsTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _windowsAccessToken = prefs.getString(_accessTokenKey);
      _windowsRefreshToken = prefs.getString(_refreshTokenKey);
    } catch (e) {}
  }

  /// Clear Windows tokens from SharedPreferences
  static Future<void> _clearWindowsTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      _windowsAccessToken = null;
      _windowsRefreshToken = null;
    } catch (e) {}
  }

  /// Refresh Windows access token using stored refresh token
  static Future<bool> _refreshWindowsToken() async {
    try {
      if (_windowsRefreshToken == null) {
        return false;
      }

      final response = await http.post(
        Uri.https('oauth2.googleapis.com', 'token'),
        body: {
          'client_id': GoogleOAuthConfig.webAuthClientId,
          'client_secret': GoogleOAuthConfig.webAuthClientSecret,
          'refresh_token': _windowsRefreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        _windowsAccessToken = tokenData['access_token'];

        // Save the new access token (refresh token stays the same)
        await _saveWindowsTokens(_windowsAccessToken!, _windowsRefreshToken);

        return true;
      } else {
        // Check if refresh token is expired/invalid
        if (response.statusCode == 400 || response.statusCode == 401) {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error'] == 'invalid_grant' ||
              errorBody['error'] == 'invalid_token' ||
              errorBody['error_description']
                      ?.toString()
                      .toLowerCase()
                      .contains('expired') ==
                  true) {
            await _clearWindowsTokens();
            return false;
          }
        }

        // For other errors (network, server issues), don't clear tokens
        return false;
      }
    } catch (e) {
      // Don't clear tokens on network errors - they might be temporary
      if (e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('timeout')) {
        // Network error - preserve tokens
      } else {
        await _clearWindowsTokens();
      }

      return false;
    }
  }

  // Backup configuration
  static const String _backupFolderName = 'NextChord';
  static const String _backupFileName = 'nextchord_backup.db';
  static const String _syncMetadataFile = 'sync_metadata.json';

  GoogleDriveSyncService({VoidCallback? onDatabaseReplaced})
      : _onDatabaseReplaced = onDatabaseReplaced {
    // Note: Windows tokens will be loaded when needed or explicitly via initialize()
  }

  /// Explicit async initialization for Windows token loading
  static Future<void> initialize() async {
    if (_isWindows) {
      await _loadWindowsTokens();
    }
  }

  static bool _isPlatformSupported() {
    if (kIsWeb) return true;

    // Mobile platforms (iOS, Android) and macOS are supported
    final isMobileOrMac = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // Desktop platforms (Windows, Linux) need OAuth config
    final isDesktopWithConfig =
        (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux) &&
            GoogleOAuthConfig.isConfigured;

    return isMobileOrMac || isDesktopWithConfig;
  }

  bool get isPlatformSupported => _isPlatformSupported();

  static Future<void> _clearWebTokens() async {
    try {
      if (kIsWeb) {
        await _googleSignInInstance.signOut();
      }
    } catch (e) {}
  }

  Future<bool> isSignedIn() async {
    try {
      if (_isWindows) {
        return _windowsAccessToken != null;
      } else {
        return await _googleSignInInstance.isSignedIn();
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> signIn() async {
    try {
      if (_isWindows) {
        return await _signInWindows();
      } else {
        final GoogleSignInAccount? account =
            await _googleSignInInstance.signIn();
        return account != null;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _signInWindows() async {
    try {
      // Create local server for OAuth callback
      _authServer = await HttpServer.bind('localhost', 8000);

      // Generate OAuth URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': GoogleOAuthConfig.webAuthClientId,
        'redirect_uri': _windowsAuthRedirectUri,
        'scope':
            '${drive.DriveApi.driveScope} ${drive.DriveApi.driveFileScope}',
        'response_type': 'code',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      // Launch browser for authentication
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch authentication URL');
      }

      // Wait for OAuth callback
      await for (HttpRequest request in _authServer!) {
        final code = request.uri.queryParameters['code'];
        if (code != null) {
          // Exchange code for access token
          final response = await http.post(
            Uri.https('oauth2.googleapis.com', 'token'),
            body: {
              'client_id': GoogleOAuthConfig.webAuthClientId,
              'client_secret': GoogleOAuthConfig.webAuthClientSecret,
              'code': code,
              'grant_type': 'authorization_code',
              'redirect_uri': _windowsAuthRedirectUri,
            },
          );

          if (response.statusCode == 200) {
            final tokenData = jsonDecode(response.body);
            _windowsAccessToken = tokenData['access_token'];
            _windowsRefreshToken = tokenData['refresh_token'];

            // Save tokens to persistent storage
            await _saveWindowsTokens(
                _windowsAccessToken!, _windowsRefreshToken);

            // Close server and send success response
            await _authServer!.close();
            request.response
              ..statusCode = 200
              ..write('Authentication successful! You can close this window.');
            await request.response.close();

            return true;
          } else {
            throw Exception(
                'Failed to exchange code for token: ${response.body}');
          }
        }

        // Send error response if no code
        request.response
          ..statusCode = 400
          ..write('Authentication failed: No authorization code received.');
        await request.response.close();
        await _authServer!.close();
        return false;
      }
    } catch (e) {
      if (_authServer != null) {
        await _authServer!.close();
      }
      return false;
    }

    // This should not be reached, but return false as a fallback
    return false;
  }

  Future<void> signOut() async {
    try {
      if (_isWindows) {
        await _clearWindowsTokens();
      } else {
        await _googleSignInInstance.signOut();
      }
      await _clearWebTokens();
    } catch (e) {}
  }

  Future<drive.DriveApi> _createDriveApi() async {
    try {
      if (_isWindows) {
        if (_windowsAccessToken == null) {
          throw Exception('User not authenticated on Windows');
        }

        final httpClient = GoogleHttpClient();

        // Try to authenticate with current access token
        try {
          await httpClient.authenticateWithAccessToken(_windowsAccessToken!);
        } catch (e) {
          // If authentication fails, try to refresh the token
          if (await _refreshWindowsToken()) {
            if (_windowsAccessToken == null) {
              throw Exception(
                  'Token refresh failed - user not authenticated on Windows');
            }
            await httpClient.authenticateWithAccessToken(_windowsAccessToken!);
          } else {
            throw Exception('Token refresh failed - please sign in again');
          }
        }

        return drive.DriveApi(httpClient);
      } else {
        final GoogleSignInAccount? account =
            await _googleSignInInstance.signInSilently();
        if (account == null) {
          throw Exception('User not signed in');
        }

        final GoogleSignInAuthentication auth = await account.authentication;
        final accessToken = auth.accessToken;

        if (accessToken == null) {
          throw Exception('Failed to get access token');
        }

        final httpClient = GoogleHttpClient();
        await httpClient.authenticateWithAccessToken(accessToken);
        return drive.DriveApi(httpClient);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sync() async {
    try {
      // CRITICAL: Check for sync failure marker to prevent empty DB uploads
      final localDbPath = await _getLocalDatabasePath();
      final markerFile = File('$localDbPath.sync_failed');
      if (await markerFile.exists()) {
        final markerContent = await markerFile.readAsString();
        print('DEBUG: Sync failure marker found: $markerContent');

        // Check if marker is older than 24 hours (auto-cleanup for transient failures)
        try {
          final markerStat = await markerFile.stat();
          final markerAge = DateTime.now().difference(markerStat.modified);
          if (markerAge.inHours > 24) {
            print(
                'DEBUG: Sync failure marker is older than 24 hours, auto-cleaning up');
            await markerFile.delete();
          } else {
            throw Exception(
                'Previous sync failed within the last 24 hours. Please check internet connection and try again. If the issue persists, delete the marker file at $localDbPath.sync_failed to force sync.');
          }
        } catch (statError) {
          // If we can't read file stats, treat as recent failure
          throw Exception(
              'Previous sync failed. Please check internet connection and try again, or delete the marker file at $localDbPath.sync_failed to force sync.');
        }
      }

      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        throw Exception('Not signed in to Google');
      }

      // Create Drive API client
      final driveApi = await _createDriveApi();

      // Find or create backup folder
      final folderId = await _findOrCreateFolder(driveApi);
      if (folderId == null) {
        throw Exception('Failed to create/find backup folder');
      }

      // Download and merge remote database bidirectionally
      await _bidirectionalMergeDatabase(driveApi, folderId, localDbPath);

      // Upload the merged database to Google Drive
      await _uploadBackup(driveApi, folderId, localDbPath, {
        'last_sync': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.toString(),
        'device_id': await _getDeviceId(),
      });

      // Clean up sync failure marker on successful sync
      if (await markerFile.exists()) {
        await markerFile.delete();
        print('DEBUG: Sync failure marker cleaned up after successful sync');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _getDeviceId() async {
    // Simple device identification using platform and timestamp
    return '${defaultTargetPlatform.toString()}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _bidirectionalMergeDatabase(
      drive.DriveApi driveApi, String folderId, String localDbPath) async {
    try {
      // DEBUG: Log database state at start
      final localDbFile = File(localDbPath);
      final localExists = await localDbFile.exists();
      final localSize = localExists ? await localDbFile.length() : 0;
      print('DEBUG: Local DB exists: $localExists, size: $localSize bytes');

      // Initialize databaseFactory for Windows (only once)
      if (_isWindows && !_databaseFactoryInitialized) {
        sqlite.databaseFactory = databaseFactoryFfi;
        _databaseFactoryInitialized = true;
      }

      // Check if local database exists and get its content
      bool localDbExists = localExists && localSize > 0;
      print('DEBUG: localDbExists after size check: $localDbExists');

      // EMERGENCY BACKUP: Create backup of local database before any merge
      String? backupPath;
      if (localDbExists) {
        backupPath =
            '$localDbPath.backup_${DateTime.now().millisecondsSinceEpoch}';
        await File(localDbPath).copy(backupPath);
      }

      int localSongCount = 0;
      int localSetlistCount = 0;

      if (localDbExists) {
        try {
          final localDb = await sqlite.openDatabase(localDbPath);
          final songResult =
              await localDb.rawQuery('SELECT COUNT(*) as count FROM songs');
          final setlistResult =
              await localDb.rawQuery('SELECT COUNT(*) as count FROM setlists');
          localSongCount = int.parse(songResult.first['count'].toString());
          localSetlistCount =
              int.parse(setlistResult.first['count'].toString());
          await localDb.close();
        } catch (e) {
          localDbExists = false;
        }
      }

      // Find existing database file
      final existingDbFile =
          await _findExistingFile(driveApi, folderId, _backupFileName);
      if (existingDbFile == null) {
        return;
      }

      // Find existing metadata file
      final existingMetadataFile =
          await _findExistingFile(driveApi, folderId, _syncMetadataFile);
      if (existingMetadataFile == null) {
        return;
      }

      // CRITICAL FIX: If local database doesn't exist, download remote directly without merge
      if (!localDbExists) {
        print('DEBUG: Local DB empty, calling _downloadRemoteDatabase');
        await _downloadRemoteDatabase(driveApi, existingDbFile, localDbPath);
        print('DEBUG: _downloadRemoteDatabase completed');
        return;
      }

      // Download metadata to check timestamps
      final metadataResponse = await driveApi.files.get(
          existingMetadataFile.id!,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final metadataBytes = await metadataResponse.stream
          .fold<List<int>>([], (list, chunk) => list..addAll(chunk));
      final metadata =
          jsonDecode(utf8.decode(metadataBytes)) as Map<String, dynamic>;

      final remoteLastSync = DateTime.parse(metadata['last_sync'] as String);
      final localLastModified = await File(localDbPath).lastModified();

      // EMERGENCY: Validate remote database content before merge
      await _performBidirectionalMerge(driveApi, existingDbFile, localDbPath);

      // Verify merge didn't lose data
      final postMergeDb = await sqlite.openDatabase(localDbPath);
      final postMergeSongCount =
          await postMergeDb.rawQuery('SELECT COUNT(*) as count FROM songs');
      final postMergeSetlistCount =
          await postMergeDb.rawQuery('SELECT COUNT(*) as count FROM setlists');
      await postMergeDb.close();

      // EMERGENCY: Restore from backup if data was lost
      final finalSongCount =
          int.parse(postMergeSongCount.first['count'].toString());
      final finalSetlistCount =
          int.parse(postMergeSetlistCount.first['count'].toString());

      if (finalSongCount < localSongCount ||
          finalSetlistCount < localSetlistCount) {
        if (backupPath != null) {
          await File(localDbPath).delete();
          await File(backupPath).copy(localDbPath);
        }
      } else {
        if (backupPath != null) {
          await File(backupPath).delete(); // Clean up backup only if it existed
        }
      }
    } catch (e) {}
  }

  Future<drive.File?> _findExistingFile(
      drive.DriveApi driveApi, String folderId, String fileName) async {
    try {
      final response = await driveApi.files.list(
        q: "name='$fileName' and '$folderId' in parents",
        spaces: 'drive',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        return response.files!.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _findOrCreateFolder(drive.DriveApi driveApi) async {
    try {
      // Search for existing folder
      final response = await driveApi.files.list(
        q: "name='$_backupFolderName' and mimeType='application/vnd.google-apps.folder'",
        spaces: 'drive',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final existingFolder = response.files!.first;
        return existingFolder.id;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folderMetadata);
      return createdFolder.id;
    } catch (e) {
      return null;
    }
  }

  Future<String> _getLocalDatabasePath() async {
    try {
      // Use the same path as AppDatabase _openConnection()
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'nextchord_db.sqlite');

      // Check if the database file exists
      final dbFile = File(dbPath);

      return dbPath; // Always return path, even if file doesn't exist
    } catch (e) {
      rethrow;
    }
  }

  Future<void> handleInitialSync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        return;
      }
    } catch (e) {}
  }

  Future<void> _downloadRemoteDatabase(
      drive.DriveApi driveApi, drive.File remoteFile, String localPath) async {
    try {
      // Initialize databaseFactory for Windows (only once)
      if (_isWindows && !_databaseFactoryInitialized) {
        sqlite.databaseFactory = databaseFactoryFfi;
        _databaseFactoryInitialized = true;
      }

      final response = await driveApi.files.get(remoteFile.id!,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      // Download directly to local path
      final localFile = File(localPath);
      await response.stream.pipe(localFile.openWrite());

      // Validate the downloaded database
      if (!await _validateDatabase(localPath)) {
        throw Exception('Downloaded database is invalid');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _performBidirectionalMerge(
      drive.DriveApi driveApi, drive.File remoteFile, String localPath) async {
    final response = await driveApi.files.get(remoteFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    // Download to temporary file
    final tempPath = '$localPath.remote';
    final tempFile = File(tempPath);

    await response.stream.pipe(tempFile.openWrite());

    // Validate the downloaded file
    if (await _validateDatabase(tempPath)) {
      // Perform bidirectional merge: merge remote into local AND local into remote
      await _bidirectionalMergeData(tempPath, localPath);

      // Clean up temporary file
      await tempFile.delete();
    } else {
      await tempFile.delete();
    }
  }

  // Helper function to safely parse timestamps from mixed formats
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now(); // Fallback to current time
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }

    if (timestamp is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }

    return DateTime.now();
  }

  Future<void> _bidirectionalMergeData(
      String remoteDbPath, String localDbPath) async {
    try {
      // Initialize databaseFactory for Windows (only once)
      if (_isWindows && !_databaseFactoryInitialized) {
        sqlite.databaseFactory = databaseFactoryFfi;
        _databaseFactoryInitialized = true;
      }

      // Check if local database file exists
      final localDbFile = File(localDbPath);
      if (!await localDbFile.exists()) {
        await File(remoteDbPath).copy(localDbPath);
        return;
      }

      // Open both databases
      final remoteDb = await sqlite.openDatabase(remoteDbPath);
      final localDb = await sqlite.openDatabase(localDbPath);

      // Get all data from both databases
      final remoteSongs = await remoteDb.rawQuery('SELECT * FROM songs');
      final localSongs = await localDb.rawQuery('SELECT * FROM songs');
      final remoteSetlists = await remoteDb.rawQuery('SELECT * FROM setlists');
      final localSetlists = await localDb.rawQuery('SELECT * FROM setlists');

      // Create sets of local record IDs to track what exists locally
      final localSongIds =
          localSongs.map((song) => song['id'] as String).toSet();
      final localSetlistIds =
          localSetlists.map((setlist) => setlist['id'] as String).toSet();

      // Create a map of all records by ID with their timestamps
      final allSongs = <String, Map<String, dynamic>>{};
      final allSetlists = <String, Map<String, dynamic>>{};

      // Add remote records
      for (final song in remoteSongs) {
        final songId = song['id'] as String;
        // Only include remote song if it still exists locally (wasn't permanently deleted)
        if (localSongIds.contains(songId)) {
          allSongs[songId] = song;
        }
        // If song doesn't exist locally, it was permanently deleted - don't add it back
      }
      for (final setlist in remoteSetlists) {
        final setlistId = setlist['id'] as String;
        // Only include remote setlist if it still exists locally (wasn't permanently deleted)
        if (localSetlistIds.contains(setlistId)) {
          allSetlists[setlistId] = setlist;
        }
        // If setlist doesn't exist locally, it was permanently deleted - don't add it back
      }

      // Add/update with local records (keeping newest, but respecting deletions)
      for (final song in localSongs) {
        final songId = song['id'] as String;
        final localUpdated = _parseTimestamp(song['updated_at']);
        final localIsDeleted =
            song['is_deleted'] == 1 || song['is_deleted'] == true;

        if (allSongs.containsKey(songId)) {
          final remoteUpdated =
              _parseTimestamp(allSongs[songId]!['updated_at']);
          final remoteIsDeleted = allSongs[songId]!['is_deleted'] == 1 ||
              allSongs[songId]!['is_deleted'] == true;

          // If either version is deleted, the most recent deletion wins
          if (localIsDeleted && remoteIsDeleted) {
            // Both deleted - keep the most recently deleted version
            if (localUpdated.isAfter(remoteUpdated)) {
              allSongs[songId] = song;
            }
          } else if (localIsDeleted) {
            // Local is deleted, remote is not - if local deletion is newer, keep deletion
            if (localUpdated.isAfter(remoteUpdated)) {
              allSongs[songId] = song;
            }
          } else if (remoteIsDeleted) {
            // Remote is deleted, local is not - keep local version unless remote deletion is newer
            if (remoteUpdated.isAfter(localUpdated)) {
              allSongs[songId] = allSongs[songId]!;
            } else {
              // Local restoration wins - keep local version
              allSongs[songId] = song;
            }
          } else {
            // Neither deleted - keep newest version
            if (localUpdated.isAfter(remoteUpdated)) {
              allSongs[songId] = song;
            }
          }
        } else {
          allSongs[songId] = song;
        }
      }

      for (final setlist in localSetlists) {
        final setlistId = setlist['id'] as String;
        final localUpdated = _parseTimestamp(setlist['updated_at']);
        final localIsDeleted =
            setlist['is_deleted'] == 1 || setlist['is_deleted'] == true;

        if (allSetlists.containsKey(setlistId)) {
          final remoteUpdated =
              _parseTimestamp(allSetlists[setlistId]!['updated_at']);
          final remoteIsDeleted = allSetlists[setlistId]!['is_deleted'] == 1 ||
              allSetlists[setlistId]!['is_deleted'] == true;

          // If either version is deleted, the most recent deletion wins
          if (localIsDeleted && remoteIsDeleted) {
            // Both deleted - keep the most recently deleted version
            if (localUpdated.isAfter(remoteUpdated)) {
              allSetlists[setlistId] = setlist;
            }
          } else if (localIsDeleted) {
            // Local is deleted, remote is not - if local deletion is newer, keep deletion
            if (localUpdated.isAfter(remoteUpdated)) {
              allSetlists[setlistId] = setlist;
            }
          } else if (remoteIsDeleted) {
            // Remote is deleted, local is not - if remote deletion is newer, keep deletion
            if (!localUpdated.isAfter(remoteUpdated)) {
              allSetlists[setlistId] = allSetlists[setlistId]!;
            }
          } else {
            // Neither deleted - keep newest version
            if (localUpdated.isAfter(remoteUpdated)) {
              allSetlists[setlistId] = setlist;
            }
          }
        } else {
          allSetlists[setlistId] = setlist;
        }
      }

      // Safety check: don't proceed if we have no data to merge
      if (allSongs.isEmpty && allSetlists.isEmpty) {
        await remoteDb.close();
        await localDb.close();
        return;
      }

      // Get local schema to check which columns exist
      final localSongSchema =
          await localDb.rawQuery("PRAGMA table_info(songs)");
      final localSetlistSchema =
          await localDb.rawQuery("PRAGMA table_info(setlists)");
      final localSongColumns =
          localSongSchema.map((col) => col['name'] as String).toSet();
      final localSetlistColumns =
          localSetlistSchema.map((col) => col['name'] as String).toSet();

      // Filter records to only include columns that exist in local schema
      final filteredSongs = allSongs.values.map((song) {
        final filteredSong = <String, dynamic>{};
        for (final entry in song.entries) {
          if (localSongColumns.contains(entry.key)) {
            filteredSong[entry.key] = entry.value;
          }
        }
        return filteredSong;
      }).toList();

      final filteredSetlists = allSetlists.values.map((setlist) {
        final filteredSetlist = <String, dynamic>{};
        for (final entry in setlist.entries) {
          if (localSetlistColumns.contains(entry.key)) {
            filteredSetlist[entry.key] = entry.value;
          }
        }
        return filteredSetlist;
      }).toList();

      // Use transaction to ensure atomic operation
      await localDb.transaction((txn) async {
        try {
          // Clear local tables and insert merged data
          await txn.delete('songs');
          await txn.delete('setlists');

          for (final song in filteredSongs) {
            await txn.insert('songs', song);
          }

          for (final setlist in filteredSetlists) {
            await txn.insert('setlists', setlist);
          }
        } catch (e) {
          rethrow; // This will rollback the transaction
        }
      });

      // Close databases
      await remoteDb.close();
      await localDb.close();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _validateDatabase(String dbPath) async {
    try {
      // Initialize databaseFactory for Windows (only once)
      if (_isWindows && !_databaseFactoryInitialized) {
        sqlite.databaseFactory = databaseFactoryFfi;
        _databaseFactoryInitialized = true;
      }

      final db = await sqlite.openDatabase(dbPath);
      // Simple validation: check if main table exists
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='songs'");
      await db.close();
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _uploadBackup(drive.DriveApi driveApi, String folderId,
      String localDbPath, Map<String, dynamic> metadata) async {
    // Upload database file
    final dbFile = File(localDbPath);
    final dbStream = dbFile.openRead();

    // Check if database file already exists
    final existingDbFile =
        await _findExistingFile(driveApi, folderId, _backupFileName);

    drive.File uploadedDb;
    if (existingDbFile != null) {
      // Update existing file (parents field not allowed in update)
      uploadedDb = await driveApi.files.update(
        drive.File()..name = _backupFileName,
        existingDbFile.id!,
        uploadMedia: drive.Media(dbStream, dbFile.lengthSync()),
      );
    } else {
      // Create new file
      final dbMetadata = drive.File()
        ..name = _backupFileName
        ..parents = [folderId];

      uploadedDb = await driveApi.files.create(
        dbMetadata,
        uploadMedia: drive.Media(dbStream, dbFile.lengthSync()),
      );
    }

    // Update and upload metadata
    metadata['lastSync'] = DateTime.now().toIso8601String();
    metadata['databaseFileId'] = uploadedDb.id;

    final metadataContent = utf8.encode(jsonEncode(metadata));
    final metadataStream = Stream.value(metadataContent);

    // Check if metadata file already exists
    final existingMetadataFile =
        await _findExistingFile(driveApi, folderId, _syncMetadataFile);

    drive.File uploadedMetadata;
    if (existingMetadataFile != null) {
      // Update existing metadata file
      uploadedMetadata = await driveApi.files.update(
        drive.File()..name = _syncMetadataFile,
        existingMetadataFile.id!,
        uploadMedia: drive.Media(metadataStream, metadataContent.length),
      );
    } else {
      // Create new metadata file
      final metadataFile = drive.File()
        ..name = _syncMetadataFile
        ..parents = [folderId];

      uploadedMetadata = await driveApi.files.create(
        metadataFile,
        uploadMedia: drive.Media(metadataStream, metadataContent.length),
      );
    }
  }

  /// Reset the GoogleSignIn instance (useful for testing and switching auth modes)
  static void resetGoogleSignInInstance() {
    _googleSignInInstance.signOut();
  }
}

/// Custom HTTP client for authenticated Google API requests
class GoogleHttpClient extends http.BaseClient {
  http.Client _client = http.Client();
  String? _accessToken;

  Future<void> authenticateWithAccessToken(String accessToken) async {
    _accessToken = accessToken;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
