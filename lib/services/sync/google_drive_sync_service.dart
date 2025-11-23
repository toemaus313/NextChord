import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        defaultTargetPlatform,
        TargetPlatform,
        debugPrint,
        VoidCallback;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import '../../core/config/google_oauth_config.dart';

class GoogleDriveSyncService {
  final VoidCallback? _onDatabaseReplaced; // Callback to trigger reconnection

  static GoogleSignIn? _googleSignIn;
  static String? _windowsAccessToken;
  static const String _windowsAuthRedirectUri = 'http://localhost:8000';
  static HttpServer? _authServer;

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

  // Backup configuration
  static const String _backupFolderName = 'NextChord';
  static const String _backupFileName = 'nextchord_backup.db';
  static const String _syncMetadataFile = 'sync_metadata.json';

  GoogleDriveSyncService({VoidCallback? onDatabaseReplaced})
      : _onDatabaseReplaced = onDatabaseReplaced;

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
    } catch (e) {
      debugPrint('Error clearing web tokens: $e');
    }
  }

  Future<bool> isSignedIn() async {
    try {
      if (_isWindows) {
        return _windowsAccessToken != null;
      } else {
        return await _googleSignInInstance.isSignedIn();
      }
    } catch (e) {
      debugPrint('Error checking sign in status: $e');
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
      debugPrint('Error signing in: $e');
      return false;
    }
  }

  Future<bool> _signInWindows() async {
    try {
      debugPrint('Starting Windows OAuth authentication...');

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

            // Close server and send success response
            await _authServer!.close();
            request.response
              ..statusCode = 200
              ..write('Authentication successful! You can close this window.');
            await request.response.close();

            debugPrint('Windows OAuth authentication successful');
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
      debugPrint('Windows OAuth authentication error: $e');
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
        _windowsAccessToken = null;
      } else {
        await _googleSignInInstance.signOut();
      }
      await _clearWebTokens();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<drive.DriveApi> _createDriveApi() async {
    try {
      if (_isWindows) {
        if (_windowsAccessToken == null) {
          throw Exception('User not authenticated on Windows');
        }

        final httpClient = GoogleHttpClient();
        await httpClient.authenticateWithAccessToken(_windowsAccessToken!);
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
      debugPrint('Error creating Drive API client: $e');
      rethrow;
    }
  }

  Future<void> sync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        debugPrint('Not signed in to Google');
        return;
      }

      // Create Drive API client
      final driveApi = await _createDriveApi();

      // Find or create backup folder
      final folderId = await _findOrCreateFolder(driveApi);
      if (folderId == null) {
        debugPrint('✗ Failed to create/find backup folder');
        return;
      }

      // Get local database path
      final localDbPath = await _getLocalDatabasePath();

      // Download and merge remote database bidirectionally
      await _bidirectionalMergeDatabase(driveApi, folderId, localDbPath);

      // Upload the merged database to Google Drive
      await _uploadBackup(driveApi, folderId, localDbPath, {
        'last_sync': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.toString(),
        'device_id': await _getDeviceId(),
      });

      debugPrint('✓ Sync completed successfully');
    } catch (e) {
      debugPrint('✗ Sync failed: $e');
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
      debugPrint('=== EMERGENCY: Checking remote database before merge ===');
      debugPrint('Folder ID: $folderId');
      debugPrint('Database filename: $_backupFileName');
      debugPrint('Metadata filename: $_syncMetadataFile');

      // Check if local database exists and get its content
      final localDbFile = File(localDbPath);
      bool localDbExists = await localDbFile.exists();

      // EMERGENCY BACKUP: Create backup of local database before any merge
      String? backupPath;
      if (localDbExists) {
        backupPath =
            '$localDbPath.backup_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('🚨 CREATING EMERGENCY BACKUP: $backupPath');
        await File(localDbPath).copy(backupPath);
      } else {
        debugPrint('🚨 No local database to backup (will download from cloud)');
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
          debugPrint('⚠️ Error reading local database: $e');
          localDbExists = false;
        }
      }

      debugPrint('🚨 LOCAL DATABASE BEFORE MERGE:');
      debugPrint('  Exists: $localDbExists');
      debugPrint('  Songs: $localSongCount');
      debugPrint('  Setlists: $localSetlistCount');

      // Find existing database file
      final existingDbFile =
          await _findExistingFile(driveApi, folderId, _backupFileName);
      if (existingDbFile == null) {
        debugPrint('✓ No remote database found, keeping local database');
        return;
      }
      debugPrint('✓ Found remote database file: ${existingDbFile.id}');

      // Find existing metadata file
      final existingMetadataFile =
          await _findExistingFile(driveApi, folderId, _syncMetadataFile);
      if (existingMetadataFile == null) {
        debugPrint('✓ No remote metadata found, keeping local database');
        return;
      }
      debugPrint('✓ Found remote metadata file: ${existingMetadataFile.id}');

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

      debugPrint('Remote last sync: $remoteLastSync');
      debugPrint('Local last modified: $localLastModified');
      debugPrint(
          'Remote is newer: ${remoteLastSync.isAfter(localLastModified)}');

      // EMERGENCY: Validate remote database content before merge
      debugPrint('🚨 VALIDATING REMOTE DATABASE CONTENT...');
      await _performBidirectionalMerge(driveApi, existingDbFile, localDbPath);

      // Verify merge didn't lose data
      final postMergeDb = await sqlite.openDatabase(localDbPath);
      final postMergeSongCount =
          await postMergeDb.rawQuery('SELECT COUNT(*) as count FROM songs');
      final postMergeSetlistCount =
          await postMergeDb.rawQuery('SELECT COUNT(*) as count FROM setlists');
      await postMergeDb.close();

      debugPrint('🚨 LOCAL DATABASE AFTER MERGE:');
      debugPrint('  Songs: ${postMergeSongCount.first['count']}');
      debugPrint('  Setlists: ${postMergeSetlistCount.first['count']}');

      // EMERGENCY: Restore from backup if data was lost
      final finalSongCount =
          int.parse(postMergeSongCount.first['count'].toString());
      final finalSetlistCount =
          int.parse(postMergeSetlistCount.first['count'].toString());

      if (finalSongCount < localSongCount ||
          finalSetlistCount < localSetlistCount) {
        debugPrint('🚨🚨🚨 DATA LOSS DETECTED! RESTORING FROM BACKUP!');
        if (backupPath != null) {
          await File(localDbPath).delete();
          await File(backupPath).copy(localDbPath);
          debugPrint('✓ Database restored from backup');
        } else {
          debugPrint('⚠️ No backup available to restore from');
        }
      } else {
        debugPrint('✓ Merge successful - no data loss detected');
        if (backupPath != null) {
          await File(backupPath).delete(); // Clean up backup only if it existed
        }
      }
    } catch (e) {
      debugPrint('✗ Error checking remote database: $e');
    }
  }

  Future<drive.File?> _findExistingFile(
      drive.DriveApi driveApi, String folderId, String fileName) async {
    try {
      debugPrint('=== Searching for file: $fileName in folder: $folderId ===');
      final response = await driveApi.files.list(
        q: "name='$fileName' and '$folderId' in parents",
        spaces: 'drive',
      );

      debugPrint('Found ${response.files?.length ?? 0} files matching search');
      if (response.files != null && response.files!.isNotEmpty) {
        debugPrint('✓ Found file: ${response.files!.first.id}');
        return response.files!.first;
      }
      debugPrint('✗ No files found matching search criteria');
      return null;
    } catch (e) {
      debugPrint('Error finding existing file: $e');
      return null;
    }
  }

  Future<String?> _findOrCreateFolder(drive.DriveApi driveApi) async {
    debugPrint('=== Finding or creating backup folder ===');

    try {
      // Search for existing folder
      final response = await driveApi.files.list(
        q: "name='$_backupFolderName' and mimeType='application/vnd.google-apps.folder'",
        spaces: 'drive',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final existingFolder = response.files!.first;
        debugPrint('✓ Found existing folder: ${existingFolder.id}');
        return existingFolder.id;
      }

      // Create new folder
      debugPrint('Creating new backup folder...');
      final folderMetadata = drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folderMetadata);
      debugPrint('✓ Created new folder: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      debugPrint('✗ Failed to find or create folder: $e');
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
      if (await dbFile.exists()) {
        debugPrint('✓ Found database at: $dbPath');
      } else {
        debugPrint(
            '⚠️ Database file not found at: $dbPath (will download from cloud)');
      }

      return dbPath; // Always return path, even if file doesn't exist
    } catch (e) {
      debugPrint('Error getting local database path: $e');
      rethrow;
    }
  }

  Future<void> handleInitialSync() async {
    try {
      debugPrint('=== Starting Initial Sync ===');

      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        debugPrint('Not signed in to Google - skipping initial sync');
        return;
      }

      debugPrint('✓ Initial sync completed');
    } catch (e) {
      debugPrint('Initial sync failed: $e');
    }
  }

  Future<void> _performBidirectionalMerge(
      drive.DriveApi driveApi, drive.File remoteFile, String localPath) async {
    debugPrint('=== Performing bidirectional database merge ===');

    final response = await driveApi.files.get(remoteFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    // Download to temporary file
    final tempPath = '$localPath.remote';
    final tempFile = File(tempPath);

    await response.stream.pipe(tempFile.openWrite());

    // Validate the downloaded file
    if (await _validateDatabase(tempPath)) {
      debugPrint('✓ Remote database is valid, performing bidirectional merge');

      // Perform bidirectional merge: merge remote into local AND local into remote
      await _bidirectionalMergeData(tempPath, localPath);

      // Clean up temporary file
      await tempFile.delete();

      debugPrint('✓ Bidirectional database merge completed successfully');
    } else {
      debugPrint('✗ Downloaded database is invalid, keeping original');
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
        debugPrint('Failed to parse string timestamp: $timestamp, error: $e');
        return DateTime.now();
      }
    }

    if (timestamp is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } catch (e) {
        debugPrint('Failed to parse int timestamp: $timestamp, error: $e');
        return DateTime.now();
      }
    }

    debugPrint(
        'Unknown timestamp type: ${timestamp.runtimeType}, value: $timestamp');
    return DateTime.now();
  }

  Future<void> _bidirectionalMergeData(
      String remoteDbPath, String localDbPath) async {
    try {
      debugPrint('=== Starting bidirectional merge ===');

      // Check if local database file exists
      final localDbFile = File(localDbPath);
      if (!await localDbFile.exists()) {
        debugPrint(
            '🚨 Local database does not exist - copying remote database directly');
        await File(remoteDbPath).copy(localDbPath);
        debugPrint('✓ Remote database copied to local location');
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

      debugPrint(
          'Remote songs: ${remoteSongs.length}, Local songs: ${localSongs.length}');
      debugPrint(
          'Remote setlists: ${remoteSetlists.length}, Local setlists: ${localSetlists.length}');

      // Create a map of all records by ID with their timestamps
      final allSongs = <String, Map<String, dynamic>>{};
      final allSetlists = <String, Map<String, dynamic>>{};

      // Add remote records
      for (final song in remoteSongs) {
        allSongs[song['id'] as String] = song;
      }
      for (final setlist in remoteSetlists) {
        allSetlists[setlist['id'] as String] = setlist;
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
            // Remote is deleted, local is not - if remote deletion is newer, keep deletion
            if (!localUpdated.isAfter(remoteUpdated)) {
              allSongs[songId] = allSongs[songId]!;
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
        debugPrint('⚠️ No data to merge - keeping existing local data');
        await remoteDb.close();
        await localDb.close();
        return;
      }

      debugPrint(
          '✓ Merging data: ${allSongs.length} songs, ${allSetlists.length} setlists');

      // Get local schema to check which columns exist
      final localSongSchema =
          await localDb.rawQuery("PRAGMA table_info(songs)");
      final localSetlistSchema =
          await localDb.rawQuery("PRAGMA table_info(setlists)");
      final localSongColumns =
          localSongSchema.map((col) => col['name'] as String).toSet();
      final localSetlistColumns =
          localSetlistSchema.map((col) => col['name'] as String).toSet();

      debugPrint('Local song columns: $localSongColumns');
      debugPrint('Local setlist columns: $localSetlistColumns');

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
          debugPrint('🚨 TRANSACTION FAILED - ROLLING BACK: $e');
          rethrow; // This will rollback the transaction
        }
      });

      debugPrint(
          '✓ Bidirectional merge completed: ${allSongs.length} songs, ${allSetlists.length} setlists');

      // Close databases
      await remoteDb.close();
      await localDb.close();

      // Trigger data refresh callback
      if (_onDatabaseReplaced != null) {
        _onDatabaseReplaced!();
      }
    } catch (e) {
      debugPrint('✗ Bidirectional merge failed: $e');
      rethrow;
    }
  }

  Future<bool> _validateDatabase(String dbPath) async {
    try {
      final db = await sqlite.openDatabase(dbPath);
      // Simple validation: check if main table exists
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='songs'");
      await db.close();
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Database validation failed: $e');
      return false;
    }
  }

  Future<void> _uploadBackup(drive.DriveApi driveApi, String folderId,
      String localDbPath, Map<String, dynamic> metadata) async {
    debugPrint('=== Uploading backup ===');
    debugPrint('Folder ID: $folderId');
    debugPrint('Local DB path: $localDbPath');

    // Upload database file
    final dbFile = File(localDbPath);
    final dbStream = dbFile.openRead();

    // Check if database file already exists
    debugPrint('=== Checking for existing database file ===');
    final existingDbFile =
        await _findExistingFile(driveApi, folderId, _backupFileName);

    drive.File uploadedDb;
    if (existingDbFile != null) {
      debugPrint(
          '✓ Found existing database file, updating: ${existingDbFile.id}');
      // Update existing file (parents field not allowed in update)
      uploadedDb = await driveApi.files.update(
        drive.File()..name = _backupFileName,
        existingDbFile.id!,
        uploadMedia: drive.Media(dbStream, dbFile.lengthSync()),
      );
    } else {
      debugPrint('✓ No existing database file found, creating new file');
      // Create new file
      final dbMetadata = drive.File()
        ..name = _backupFileName
        ..parents = [folderId];

      uploadedDb = await driveApi.files.create(
        dbMetadata,
        uploadMedia: drive.Media(dbStream, dbFile.lengthSync()),
      );
    }

    debugPrint('✓ Database uploaded: ${uploadedDb.id}');

    // Update and upload metadata
    metadata['lastSync'] = DateTime.now().toIso8601String();
    metadata['databaseFileId'] = uploadedDb.id;

    final metadataContent = utf8.encode(jsonEncode(metadata));
    final metadataStream = Stream.value(metadataContent);

    // Check if metadata file already exists
    debugPrint('=== Checking for existing metadata file ===');
    final existingMetadataFile =
        await _findExistingFile(driveApi, folderId, _syncMetadataFile);

    drive.File uploadedMetadata;
    if (existingMetadataFile != null) {
      debugPrint(
          '✓ Found existing metadata file, updating: ${existingMetadataFile.id}');
      // Update existing metadata file
      uploadedMetadata = await driveApi.files.update(
        drive.File()..name = _syncMetadataFile,
        existingMetadataFile.id!,
        uploadMedia: drive.Media(metadataStream, metadataContent.length),
      );
    } else {
      debugPrint('✓ No existing metadata file found, creating new file');
      // Create new metadata file
      final metadataFile = drive.File()
        ..name = _syncMetadataFile
        ..parents = [folderId];

      uploadedMetadata = await driveApi.files.create(
        metadataFile,
        uploadMedia: drive.Media(metadataStream, metadataContent.length),
      );
    }

    debugPrint('✓ Metadata uploaded: ${uploadedMetadata.id}');
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
