import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, VoidCallback;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextchord/main.dart' as main;
import '../../core/config/google_oauth_config.dart';
import '../../data/database/app_database.dart';
import '../../core/services/sync_service_locator.dart';
import 'library_sync_service.dart';

class GoogleDriveSyncService {
  final VoidCallback? _onDatabaseReplaced; // Callback to trigger reconnection
  final LibrarySyncService _librarySyncService;

  // Metadata polling infrastructure
  Timer? _metadataPollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);
  bool _isPollingActive = false;

  static GoogleSignIn? _googleSignIn;
  static String? _universalAccessToken;
  static String? _universalRefreshToken;
  static DateTime? _tokenExpiryTime;
  static const String _authRedirectUri =
      'http://localhost:8000'; // Fixed port for Google OAuth compliance
  static HttpServer? _authServer;

  // SharedPreferences keys for universal token persistence (works on all platforms)
  static const String _accessTokenKey = 'universal_access_token_v2';
  static const String _refreshTokenKey = 'universal_refresh_token_v2';
  static const String _tokenExpiryKey = 'universal_token_expiry_v2';

  // Backup configuration
  // Legacy name kept for backward compatibility with existing cloud backups
  static const String _backupFolderName = 'NextChord';
  static const String _libraryFileName = 'library.json';

  static GoogleSignIn get _googleSignInInstance {
    _googleSignIn ??= GoogleSignIn(
      scopes: [
        drive.DriveApi.driveScope,
        drive.DriveApi.driveFileScope,
      ],
    );
    return _googleSignIn!;
  }

  static bool _isMobilePlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
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

  /// Save universal tokens to SharedPreferences for persistence
  static Future<void> _saveUniversalTokens(
      String accessToken, String? refreshToken,
      {int? expiresIn}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    // Calculate and save token expiry time (default 1 hour if not provided)
    final expirySeconds = expiresIn ?? 3600;
    _tokenExpiryTime = DateTime.now().add(Duration(seconds: expirySeconds));
    await prefs.setInt(
        _tokenExpiryKey, _tokenExpiryTime!.millisecondsSinceEpoch);

    _universalAccessToken = accessToken;
    _universalRefreshToken = refreshToken;

    main.myDebug('[GoogleDriveSyncService] _saveUniversalTokens: '
        'accessTokenSet=${accessToken.isNotEmpty}, '
        'hasRefreshToken=${refreshToken != null}, '
        'expiresInSeconds=$expirySeconds, '
        'expiryTime=$_tokenExpiryTime');
  }

  /// Load universal tokens from SharedPreferences on app startup
  static Future<void> _loadUniversalTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _universalAccessToken = prefs.getString(_accessTokenKey);
    _universalRefreshToken = prefs.getString(_refreshTokenKey);

    final expiryMillis = prefs.getInt(_tokenExpiryKey);
    if (expiryMillis != null) {
      _tokenExpiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    }

    main.myDebug('[GoogleDriveSyncService] _loadUniversalTokens: '
        'hasAccessToken=${_universalAccessToken != null}, '
        'hasRefreshToken=${_universalRefreshToken != null}, '
        'expiryTime=$_tokenExpiryTime');
  }

  /// Clear universal tokens from SharedPreferences
  static Future<void> _clearUniversalTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
    _universalAccessToken = null;
    _universalRefreshToken = null;
    _tokenExpiryTime = null;

    main.myDebug('[GoogleDriveSyncService] _clearUniversalTokens: '
        'All stored tokens and expiry cleared');
  }

  /// Check if the access token is expired or about to expire (within 5 minutes)
  static bool _isTokenExpired() {
    if (_tokenExpiryTime == null) {
      main.myDebug('[GoogleDriveSyncService] _isTokenExpired: '
          'no expiry stored, treating as expired');
      return true; // Assume expired if we don't have expiry info
    }

    // Consider token expired if it expires within 5 minutes
    final now = DateTime.now();
    final bufferTime = now.add(Duration(minutes: 5));
    final isExpired = _tokenExpiryTime!.isBefore(bufferTime);

    main.myDebug('[GoogleDriveSyncService] _isTokenExpired: '
        'now=$now, '
        'expiry=$_tokenExpiryTime, '
        'bufferTime=$bufferTime, '
        'isExpired=$isExpired');

    return isExpired;
  }

  /// Refresh universal access token using stored refresh token
  static Future<bool> _refreshUniversalToken() async {
    try {
      if (_universalRefreshToken == null) {
        main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
            'no refresh token available, cannot refresh');
        return false;
      }

      main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
          'attempting token refresh with stored refresh token');

      final response = await http.post(
        Uri.https('oauth2.googleapis.com', 'token'),
        body: {
          'client_id': GoogleOAuthConfig.webAuthClientId,
          'client_secret': GoogleOAuthConfig.webAuthClientSecret,
          'refresh_token': _universalRefreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        _universalAccessToken = tokenData['access_token'];
        final expiresIn = tokenData['expires_in'] as int?;

        // Save the new access token with expiry time
        await _saveUniversalTokens(
            _universalAccessToken!, _universalRefreshToken,
            expiresIn: expiresIn);

        main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
            'success statusCode=${response.statusCode}, '
            'hasAccessToken=${_universalAccessToken != null}, '
            'expiresInSeconds=$expiresIn');

        return true;
      } else {
        main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
            'failed statusCode=${response.statusCode}, body=${response.body}');
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
            main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
                'refresh token invalid/expired, clearing stored tokens');
            await _clearUniversalTokens();
            return false;
          }
        }

        return false;
      }
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
          'exception=$e');
      if (e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('timeout')) {
        // Network error - preserve tokens
        main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
            'network-related error, preserving tokens');
      } else {
        main.myDebug('[GoogleDriveSyncService] _refreshUniversalToken: '
            'non-network error, clearing tokens');
        await _clearUniversalTokens();
      }

      return false;
    }
  }

  GoogleDriveSyncService({
    required AppDatabase database,
    VoidCallback? onDatabaseReplaced,
  })  : _onDatabaseReplaced = onDatabaseReplaced,
        _librarySyncService = LibrarySyncService(database) {
    // Note: Universal tokens will be loaded when needed or explicitly via initialize()
  }

  /// Explicit async initialization for universal token loading
  static Future<void> initialize() async {
    main.myDebug('[GoogleDriveSyncService] initialize: '
        'loading stored universal tokens on startup');
    await _loadUniversalTokens();
  }

  bool get isPlatformSupported => _isPlatformSupported();

  Future<bool> isSignedIn() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        final bool isSignedIn = await _googleSignInInstance.isSignedIn();
        main.myDebug('[GoogleDriveSyncService] isSignedIn (mobile): '
            'isSignedIn=$isSignedIn');
        return isSignedIn;
      } else {
        // Use universal web OAuth for desktop platforms
        await _loadUniversalTokens(); // Ensure tokens are loaded from storage
        final bool hasToken = _universalAccessToken != null;
        main.myDebug('[GoogleDriveSyncService] isSignedIn (desktop): '
            'hasAccessToken=$hasToken, '
            'hasRefreshToken=${_universalRefreshToken != null}, '
            'expiryTime=$_tokenExpiryTime');
        return hasToken;
      }
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] isSignedIn: exception=$e');
      return false;
    }
  }

  Future<bool> signIn() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        final GoogleSignInAccount? account =
            await _googleSignInInstance.signIn();
        final result = account != null;
        main.myDebug('[GoogleDriveSyncService] signIn (mobile): '
            'result=$result, accountEmail=${account?.email}');
        return result;
      } else {
        // Use universal web OAuth for desktop platforms
        main.myDebug('[GoogleDriveSyncService] signIn (desktop): '
            'delegating to _signInWeb');
        final result = await _signInWeb();
        main.myDebug('[GoogleDriveSyncService] signIn (desktop): '
            'result=$result, '
            'hasAccessToken=${_universalAccessToken != null}, '
            'hasRefreshToken=${_universalRefreshToken != null}, '
            'expiryTime=$_tokenExpiryTime');
        return result;
      }
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] signIn: exception=$e');
      return false;
    }
  }

  Future<bool> _signInWeb() async {
    try {
      main.myDebug('[GoogleDriveSyncService] _signInWeb: starting OAuth '
          'flow on localhost:8000');
      // Create local server for OAuth callback on fixed port 8000 (Google OAuth compliance)
      _authServer = await HttpServer.bind('localhost', 8000);

      // Generate OAuth URL with fixed redirect URI
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': GoogleOAuthConfig.webAuthClientId,
        'redirect_uri': _authRedirectUri,
        'scope':
            '${drive.DriveApi.driveScope} ${drive.DriveApi.driveFileScope}',
        'response_type': 'code',
        'access_type': 'offline',
        'prompt':
            'select_account', // Changed from 'consent' to avoid forcing re-authentication
      });

      // Launch browser for authentication
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
        main.myDebug('[GoogleDriveSyncService] _signInWeb: launched '
            'external browser for OAuth, waiting for callback');
      } else {
        main.myDebug('[GoogleDriveSyncService] _signInWeb: could not '
            'launch authentication URL');
        throw Exception('Could not launch authentication URL');
      }

      // Wait for OAuth callback with timeout
      await for (HttpRequest request
          in _authServer!.timeout(Duration(minutes: 5))) {
        final code = request.uri.queryParameters['code'];
        if (code != null) {
          main.myDebug('[GoogleDriveSyncService] _signInWeb: received '
              'authorization code, exchanging for tokens');
          // Exchange code for access token
          final response = await http.post(
            Uri.https('oauth2.googleapis.com', 'token'),
            body: {
              'client_id': GoogleOAuthConfig.webAuthClientId,
              'client_secret': GoogleOAuthConfig.webAuthClientSecret,
              'code': code,
              'grant_type': 'authorization_code',
              'redirect_uri': _authRedirectUri,
            },
          );

          if (response.statusCode == 200) {
            final tokenData = jsonDecode(response.body);
            _universalAccessToken = tokenData['access_token'];
            _universalRefreshToken = tokenData['refresh_token'];
            final expiresIn = tokenData['expires_in'] as int?;

            // Save tokens to persistent storage with expiry time
            await _saveUniversalTokens(
                _universalAccessToken!, _universalRefreshToken,
                expiresIn: expiresIn);

            main.myDebug('[GoogleDriveSyncService] _signInWeb: token '
                'exchange success statusCode=${response.statusCode}, '
                'hasAccessToken=${_universalAccessToken != null}, '
                'hasRefreshToken=${_universalRefreshToken != null}, '
                'expiresInSeconds=$expiresIn');

            // Close server and send success response
            await _authServer!.close();
            request.response
              ..statusCode = 200
              ..write('Authentication successful! You can close this window.');
            await request.response.close();

            return true;
          } else {
            main.myDebug('[GoogleDriveSyncService] _signInWeb: token '
                'exchange failed statusCode=${response.statusCode}, '
                'body=${response.body}');
            throw Exception(
                'OAuth authorization failed: no authorization code received');
          }
        }

        // Send error response if no code
        request.response
          ..statusCode = 400
          ..write('Authorization failed: no code received');
        await request.response.close();
        await _authServer!.close();
        main.myDebug('[GoogleDriveSyncService] _signInWeb: callback '
            'received without authorization code');
        return false;
      }
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] _signInWeb: exception=$e');
      if (_authServer != null) {
        await _authServer!.close();
      }
      return false;
    }

    // This should not be reached, but return false as a fallback
    return false;
  }

  Future<void> signOut() async {
    if (_isMobilePlatform()) {
      // Use GoogleSignIn for mobile platforms
      main.myDebug('[GoogleDriveSyncService] signOut (mobile): '
          'signing out via GoogleSignIn');
      await _googleSignInInstance.signOut();
    } else {
      // Use universal web OAuth for desktop platforms
      main.myDebug('[GoogleDriveSyncService] signOut (desktop): '
          'clearing stored universal tokens');
      await _clearUniversalTokens();
    }
  }

  Future<drive.DriveApi> createDriveApi() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        final GoogleSignInAccount? account =
            await _googleSignInInstance.signInSilently();
        if (account == null) {
          main.myDebug('[GoogleDriveSyncService] createDriveApi '
              '(mobile): signInSilently returned null account');
          throw Exception('User not signed in');
        }

        final GoogleSignInAuthentication auth = await account.authentication;
        final accessToken = auth.accessToken;

        if (accessToken == null) {
          main.myDebug('[GoogleDriveSyncService] createDriveApi '
              '(mobile): authentication returned null accessToken');
          throw Exception('Failed to get access token');
        }

        final httpClient = GoogleHttpClient();
        await httpClient.authenticateWithAccessToken(accessToken);
        main.myDebug('[GoogleDriveSyncService] createDriveApi (mobile): '
            'created DriveApi with GoogleSignIn access token');
        return drive.DriveApi(httpClient);
      } else {
        // Use universal web OAuth for desktop platforms
        main.myDebug('[GoogleDriveSyncService] createDriveApi (desktop): '
            'loading stored tokens and preparing Drive client');
        await _loadUniversalTokens(); // Ensure tokens are loaded from storage

        if (_universalAccessToken == null) {
          main.myDebug('[GoogleDriveSyncService] createDriveApi (desktop): '
              'no access token found, treating as unauthenticated');
          throw Exception('User not authenticated');
        }

        // Proactively refresh token if it's expired or about to expire
        if (_isTokenExpired()) {
          main.myDebug('[GoogleDriveSyncService] createDriveApi (desktop): '
              'token considered expired/expiring, attempting refresh');
          if (!await _refreshUniversalToken()) {
            main.myDebug('[GoogleDriveSyncService] createDriveApi (desktop): '
                'proactive refresh failed, forcing sign-in');
            throw Exception('Token refresh failed - please sign in again');
          }
        }

        final httpClient = GoogleHttpClient(
          onUnauthorized: () async {
            // Handle 401 errors by refreshing the token
            main.myDebug('[GoogleDriveSyncService] GoogleHttpClient '
                'onUnauthorized: received 401, attempting refresh');
            if (await _refreshUniversalToken()) {
              main.myDebug('[GoogleDriveSyncService] GoogleHttpClient '
                  'onUnauthorized: refresh succeeded, returning new token');
              return _universalAccessToken;
            }
            main.myDebug('[GoogleDriveSyncService] GoogleHttpClient '
                'onUnauthorized: refresh failed, returning null');
            return null;
          },
        );
        await httpClient.authenticateWithAccessToken(_universalAccessToken!);

        main.myDebug('[GoogleDriveSyncService] createDriveApi (desktop): '
            'created DriveApi with current access token');

        return drive.DriveApi(httpClient);
      }
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] createDriveApi: exception=$e');
      rethrow;
    }
  }

  /// Get metadata for library.json file without downloading content
  /// Returns null if file doesn't exist
  Future<DriveLibraryMetadata?> getLibraryJsonMetadata() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        main.myDebug('[GoogleDriveSyncService] getLibraryJsonMetadata: '
            'not signed in, aborting metadata fetch');
        throw Exception('Not signed in to Google');
      }

      // Create Drive API client
      final driveApi = await createDriveApi();

      // Find or create backup folder
      final folderId = await findOrCreateFolder(driveApi);
      if (folderId == null) {
        main.myDebug('[GoogleDriveSyncService] sync: failed to find/create '
            'backup folder');
        throw Exception('Failed to create/find backup folder');
      }

      // Find existing library file
      final existingFile =
          await findExistingFile(driveApi, folderId, _libraryFileName);

      if (existingFile == null) {
        return null;
      }

      // Fetch only metadata fields (minimal traffic)
      final response = await driveApi.files.get(
        existingFile.id!,
        $fields: 'id,modifiedTime,md5Checksum,headRevisionId',
      ) as drive.File;

      final metadata = DriveLibraryMetadata.fromDriveFile(response);
      main.myDebug('[GoogleDriveSyncService] getLibraryJsonMetadata: '
          'fetched metadata for library.json, '
          'fileId=${metadata.fileId}, '
          'modifiedTime=${metadata.modifiedTime}, '
          'md5=${metadata.md5Checksum}, '
          'headRevision=${metadata.headRevisionId}');
      return metadata;
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] getLibraryJsonMetadata: '
          'exception=$e');
      return null;
    }
  }

  Future<void> sync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        main.myDebug('[GoogleDriveSyncService] sync: not signed in, '
            'throwing authentication error');
        throw Exception('Not signed in to Google');
      }

      // Create Drive API client
      final driveApi = await createDriveApi();

      // Find or create backup folder
      final folderId = await findOrCreateFolder(driveApi);
      if (folderId == null) {
        throw Exception('Failed to create/find backup folder');
      }

      // Perform JSON-based sync
      await _performJsonSync(driveApi, folderId);
      main.myDebug('[GoogleDriveSyncService] sync: JSON sync completed '
          'successfully');
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] sync: exception=$e');
      rethrow;
    }
  }

  Future<void> _performJsonSync(
      drive.DriveApi driveApi, String folderId) async {
    try {
      // Try to download existing library JSON from Google Drive
      final existingLibraryFile =
          await findExistingFile(driveApi, folderId, _libraryFileName);

      String? remoteJson;
      DriveLibraryMetadata? remoteMetadata;
      if (existingLibraryFile != null) {
        try {
          final response = await driveApi.files.get(existingLibraryFile.id!,
              downloadOptions: drive.DownloadOptions.fullMedia);

          final remoteContent = await (response as drive.Media)
              .stream
              .transform(utf8.decoder)
              .join();
          remoteJson = remoteContent;

          // Validate JSON format
          jsonDecode(remoteJson); // Will throw if invalid

          // Get metadata for the remote file
          final metadataResponse = await driveApi.files.get(
            existingLibraryFile.id!,
            $fields: 'id,modifiedTime,md5Checksum,headRevisionId',
          ) as drive.File;
          remoteMetadata = DriveLibraryMetadata.fromDriveFile(metadataResponse);
        } catch (e) {
          // Treat corrupted remote file as if it doesn't exist
          remoteJson = null;
          remoteMetadata = null;
          main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
              'error reading existing library.json; treating as missing. '
              'exception=$e');
        }
      } else {
        // No remote file found
        main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
            'no existing library.json found in backup folder');
      }

      // Get current sync state to compare versions
      final syncState = await _librarySyncService.getSyncState();

      // Merge remote library into local database (if remote exists and is valid)
      if (remoteJson != null && remoteJson.isNotEmpty) {
        main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
            'merging remote library into local database');
        await _librarySyncService.importAndMergeLibraryFromJson(remoteJson);
      } else {
        // No merge needed - no remote changes to apply
        main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
            'no remote library content to merge');
      }

      // Export the merged library (now includes remote changes)
      final mergedJson = await _librarySyncService.exportLibraryToJson();

      // Determine if upload is needed
      bool shouldUpload = false;
      if (remoteJson == null || remoteJson.isEmpty) {
        // No remote file exists, always upload
        shouldUpload = true;
        main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
            'no remote file present, will upload merged library');
      } else {
        // Check if merged library differs from remote
        shouldUpload =
            _librarySyncService.hasMergedLibraryChanged(mergedJson, remoteJson);
        if (shouldUpload) {
          // Library has changes - will upload
          main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
              'merged library differs from remote, will upload');
        } else {
          // Library unchanged - no upload needed
          main.myDebug('[GoogleDriveSyncService] _performJsonSync: '
              'merged library matches remote, skipping upload');
        }
      }

      // Upload only if there are changes
      if (shouldUpload) {
        await _uploadLibraryJson(driveApi, folderId, mergedJson);

        // Store the hash of uploaded content
        await _librarySyncService.storeUploadedLibraryHash(mergedJson);

        // Re-fetch remote metadata after upload so future polls compare
        // against the latest state of library.json
        final updatedMetadata = await getLibraryJsonMetadata();
        if (updatedMetadata != null) {
          await _librarySyncService.database.updateSyncState(
            lastRemoteVersion: syncState?.lastRemoteVersion ?? 0,
            lastSyncAt: DateTime.now(),
            remoteMetadata: updatedMetadata,
          );
        }
      } else {
        // Still update sync state to record that we checked for changes
        // This prevents repeated downloads on next metadata poll
        if (remoteMetadata != null) {
          await _librarySyncService.database.updateSyncState(
            lastRemoteVersion: syncState?.lastRemoteVersion ?? 0,
            lastSyncAt: DateTime.now(),
            remoteMetadata: remoteMetadata,
          );
        }
      }

      // After a successful JSON sync, purge old soft-deleted setlists
      await _librarySyncService.database
          .purgeDeletedSetlistsOlderThan(const Duration(minutes: 1));

      // Also purge permanently deleted songs after a 10-day retention window
      await _librarySyncService.database
          .purgeDeletedSongsOlderThan(const Duration(days: 10));
      main.myDebug('[GoogleDriveSyncService] _performJsonSync: completed '
          'merge, conditional upload (shouldUpload=$shouldUpload), and '
          'cleanup of deleted entities');
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] _performJsonSync: exception=$e');
      rethrow;
    }
  }

  Future<void> _uploadLibraryJson(
      drive.DriveApi driveApi, String folderId, String jsonContent) async {
    try {
      // Check if file already exists
      final existingFile =
          await findExistingFile(driveApi, folderId, _libraryFileName);

      final media = drive.Media(
        Stream.value(utf8.encode(jsonContent)),
        utf8.encode(jsonContent).length,
      );

      if (existingFile != null) {
        // Update existing file content (minimal metadata to avoid read-only field errors)
        await driveApi.files.update(
          drive.File(), // Empty metadata - only updating content, not metadata
          existingFile.id!,
          uploadMedia: media,
        );
      } else {
        // Create new file
        final fileMetadata = drive.File()
          ..name = _libraryFileName
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

  Future<drive.File?> findExistingFile(
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
      main.myDebug('[GoogleDriveSyncService] findExistingFile: '
          'exception=$e');
      return null;
    }
  }

  Future<String?> findOrCreateFolder(drive.DriveApi driveApi) async {
    try {
      // Search for existing folder
      final response = await driveApi.files.list(
        q: "name='$_backupFolderName' and mimeType='application/vnd.google-apps.folder'",
        spaces: 'drive',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        final existingFolder = response.files!.first;
        main.myDebug('[GoogleDriveSyncService] findOrCreateFolder: '
            'found existing NextChord folder with id=${existingFolder.id}');
        return existingFolder.id;
      }

      // Create new folder
      final folderMetadata = drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folderMetadata);
      main.myDebug('[GoogleDriveSyncService] findOrCreateFolder: '
          'created new NextChord folder with id=${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      main.myDebug('[GoogleDriveSyncService] findOrCreateFolder: '
          'exception=$e');
      return null;
    }
  }

  Future<void> handleInitialSync() async {
    // Check authentication status
    final isAuthenticated = await isSignedIn();
    if (!isAuthenticated) {
      main.myDebug('[GoogleDriveSyncService] handleInitialSync: '
          'not signed in, skipping initial sync');
      return;
    }
    main.myDebug('[GoogleDriveSyncService] handleInitialSync: '
        'signed in, initial sync will be driven by SyncProvider');
  }

  /// Start metadata polling for automatic sync when app is active
  void startMetadataPolling() {
    if (_isPollingActive) {
      main.myDebug('[GoogleDriveSyncService] startMetadataPolling: '
          'already active, ignoring');
      return;
    }

    _isPollingActive = true;
    main.myDebug('[GoogleDriveSyncService] startMetadataPolling: '
        'starting periodic metadata polling every '
        '$_pollingInterval');

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
          final hasRemoteChanges =
              await _librarySyncService.hasRemoteChanges(remoteMetadata);

          if (hasRemoteChanges) {
            // Trigger full sync through the sync provider
            main.myDebug('[GoogleDriveSyncService] startMetadataPolling: '
                'detected remote changes, triggering auto sync');
            await SyncServiceLocator.triggerAutoSync();
          }
        }
      } catch (e) {
        // Error during metadata polling - will retry on next interval
        main.myDebug('[GoogleDriveSyncService] startMetadataPolling: '
            'metadata polling exception=$e');
      }
    });
  }

  /// Stop metadata polling when app is paused/backgrounded
  void stopMetadataPolling() {
    if (!_isPollingActive) {
      main.myDebug('[GoogleDriveSyncService] stopMetadataPolling: '
          'not active, ignoring');
      return;
    }

    _isPollingActive = false;
    _metadataPollingTimer?.cancel();
    _metadataPollingTimer = null;
    main.myDebug('[GoogleDriveSyncService] stopMetadataPolling: '
        'stopped periodic metadata polling');
  }

  /// Check if metadata polling is currently active
  bool get isPollingActive => _isPollingActive;
}

/// Custom HTTP client for authenticated Google API requests
class GoogleHttpClient extends http.BaseClient {
  http.Client _client = http.Client();
  String? _accessToken;
  final Future<String?> Function()? onUnauthorized;

  GoogleHttpClient({this.onUnauthorized});

  Future<void> authenticateWithAccessToken(String accessToken) async {
    _accessToken = accessToken;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    // Send the request
    var response = await _client.send(request);

    // If we get a 401 and have an onUnauthorized callback, try to refresh
    if (response.statusCode == 401 && onUnauthorized != null) {
      // Try to get a new token
      final newToken = await onUnauthorized!();
      if (newToken != null) {
        // Update our token and retry the request
        _accessToken = newToken;

        // Clone the request with the new token
        final newRequest = _cloneRequest(request);
        newRequest.headers['Authorization'] = 'Bearer $newToken';
        response = await _client.send(newRequest);
      }
    }

    return response;
  }

  /// Clone a request for retry with new token
  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    http.BaseRequest newRequest;

    if (request is http.Request) {
      newRequest = http.Request(request.method, request.url)
        ..bodyBytes = request.bodyBytes;
    } else if (request is http.MultipartRequest) {
      newRequest = http.MultipartRequest(request.method, request.url)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
    } else if (request is http.StreamedRequest) {
      throw Exception('Cannot clone StreamedRequest');
    } else {
      throw Exception('Unknown request type');
    }

    newRequest.headers.addAll(request.headers);
    return newRequest;
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
