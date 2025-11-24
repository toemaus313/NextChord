import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        defaultTargetPlatform,
        TargetPlatform,
        VoidCallback,
        debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/google_oauth_config.dart';
import '../../data/database/app_database.dart';
import '../../core/services/sync_service_locator.dart';
import 'library_sync_service.dart';

/// Helper for timestamped debug logging
String _timestampedLog(String message) {
  final timestamp = DateTime.now().toIso8601String();
  return '[$timestamp] $message';
}

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
    try {
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

      debugPrint('Tokens saved, expiry: $_tokenExpiryTime');
    } catch (e) {
      debugPrint('Error saving universal tokens: $e');
    }
  }

  /// Load universal tokens from SharedPreferences on app startup
  static Future<void> _loadUniversalTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _universalAccessToken = prefs.getString(_accessTokenKey);
      _universalRefreshToken = prefs.getString(_refreshTokenKey);

      final expiryMillis = prefs.getInt(_tokenExpiryKey);
      if (expiryMillis != null) {
        _tokenExpiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      }
    } catch (e) {}
  }

  /// Clear universal tokens from SharedPreferences
  static Future<void> _clearUniversalTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiryKey);
      _universalAccessToken = null;
      _universalRefreshToken = null;
      _tokenExpiryTime = null;
    } catch (e) {
      debugPrint('Error clearing universal tokens: $e');
    }
  }

  /// Check if the access token is expired or about to expire (within 5 minutes)
  static bool _isTokenExpired() {
    if (_tokenExpiryTime == null) {
      return true; // Assume expired if we don't have expiry info
    }

    // Consider token expired if it expires within 5 minutes
    final bufferTime = DateTime.now().add(Duration(minutes: 5));
    return _tokenExpiryTime!.isBefore(bufferTime);
  }

  /// Refresh universal access token using stored refresh token
  static Future<bool> _refreshUniversalToken() async {
    try {
      if (_universalRefreshToken == null) {
        debugPrint('No refresh token available');
        return false;
      }

      debugPrint('Refreshing access token...');
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

        debugPrint('Token refresh successful');
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
            debugPrint('Refresh token invalid or expired, clearing tokens');
            await _clearUniversalTokens();
            return false;
          }
        }

        debugPrint(
            'Token refresh failed: ${response.statusCode} - ${response.body}');
        // For other errors (network, server issues), don't clear tokens
        return false;
      }
    } catch (e) {
      debugPrint('Token refresh error: $e');
      // Don't clear tokens on network errors - they might be temporary
      if (e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('timeout')) {
        // Network error - preserve tokens
      } else {
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
    await _loadUniversalTokens();
  }

  bool get isPlatformSupported => _isPlatformSupported();

  Future<bool> isSignedIn() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        return await _googleSignInInstance.isSignedIn();
      } else {
        // Use universal web OAuth for desktop platforms
        await _loadUniversalTokens(); // Ensure tokens are loaded from storage
        return _universalAccessToken != null;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> signIn() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        debugPrint(_timestampedLog('Using GoogleSignIn for mobile platform'));
        final GoogleSignInAccount? account =
            await _googleSignInInstance.signIn();
        return account != null;
      } else {
        // Use universal web OAuth for desktop platforms
        debugPrint(_timestampedLog('Using web OAuth for desktop platform'));
        return await _signInWeb();
      }
    } catch (e) {
      debugPrint(_timestampedLog('Sign in failed: $e'));
      return false;
    }
  }

  Future<bool> _signInWeb() async {
    try {
      // Create local server for OAuth callback on fixed port 8000 (Google OAuth compliance)
      _authServer = await HttpServer.bind('localhost', 8000);

      debugPrint(_timestampedLog('OAuth server started on port 8000'));

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
      } else {
        throw Exception('Could not launch authentication URL');
      }

      // Wait for OAuth callback with timeout
      await for (HttpRequest request
          in _authServer!.timeout(Duration(minutes: 5))) {
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

            // Close server and send success response
            await _authServer!.close();
            request.response
              ..statusCode = 200
              ..write('Authentication successful! You can close this window.');
            await request.response.close();

            debugPrint(
                _timestampedLog('OAuth authentication completed successfully'));
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
      debugPrint(_timestampedLog('OAuth authentication failed: $e'));
      return false;
    }

    // This should not be reached, but return false as a fallback
    return false;
  }

  Future<void> signOut() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        debugPrint(
            _timestampedLog('Using GoogleSignIn sign out for mobile platform'));
        await _googleSignInInstance.signOut();
      } else {
        // Use universal web OAuth for desktop platforms
        debugPrint(
            _timestampedLog('Clearing universal tokens for desktop platform'));
        await _clearUniversalTokens();
      }
    } catch (e) {
      debugPrint(_timestampedLog('Sign out error: $e'));
    }
  }

  Future<drive.DriveApi> createDriveApi() async {
    try {
      if (_isMobilePlatform()) {
        // Use GoogleSignIn for mobile platforms
        debugPrint(
            _timestampedLog('Using GoogleSignIn API for mobile platform'));
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
      } else {
        // Use universal web OAuth for desktop platforms
        debugPrint(
            _timestampedLog('Using universal tokens for desktop platform'));
        await _loadUniversalTokens(); // Ensure tokens are loaded from storage

        if (_universalAccessToken == null) {
          throw Exception('User not authenticated');
        }

        // Proactively refresh token if it's expired or about to expire
        if (_isTokenExpired()) {
          debugPrint(_timestampedLog(
              'Access token expired or expiring soon, refreshing'));
          if (!await _refreshUniversalToken()) {
            throw Exception('Token refresh failed - please sign in again');
          }
        }

        final httpClient = GoogleHttpClient(
          onUnauthorized: () async {
            // Handle 401 errors by refreshing the token
            debugPrint(_timestampedLog('Received 401 error, refreshing token'));
            if (await _refreshUniversalToken()) {
              return _universalAccessToken;
            }
            return null;
          },
        );
        await httpClient.authenticateWithAccessToken(_universalAccessToken!);

        return drive.DriveApi(httpClient);
      }
    } catch (e) {
      debugPrint(_timestampedLog('Failed to create Drive API: $e'));
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
        throw Exception('Not signed in to Google');
      }

      // Create Drive API client
      final driveApi = await createDriveApi();

      // Find or create backup folder
      final folderId = await findOrCreateFolder(driveApi);
      if (folderId == null) {
        throw Exception('Failed to create/find backup folder');
      }

      // Find existing library file
      final existingFile =
          await findExistingFile(driveApi, folderId, _libraryFileName);

      if (existingFile == null) {
        debugPrint(_timestampedLog('Library metadata: No remote file found'));
        return null;
      }

      // Fetch only metadata fields (minimal traffic)
      final response = await driveApi.files.get(
        existingFile.id!,
        $fields: 'id,modifiedTime,md5Checksum,headRevisionId',
      ) as drive.File;

      final metadata = DriveLibraryMetadata.fromDriveFile(response);
      debugPrint(_timestampedLog(
          'Library metadata retrieved: modified=${metadata.modifiedTime}, md5=${metadata.md5Checksum.substring(0, 8)}'));

      return metadata;
    } catch (e) {
      debugPrint('Error getting library metadata: $e');
      return null;
    }
  }

  Future<void> sync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
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
      debugPrint(_timestampedLog('Local DB change detected - starting sync'));
      await _performJsonSync(driveApi, folderId);
      debugPrint(_timestampedLog('Sync completed successfully'));
    } catch (e) {
      debugPrint('Sync failed: $e');
      rethrow;
    }
  }

  Future<void> _performJsonSync(
      drive.DriveApi driveApi, String folderId) async {
    try {
      debugPrint(_timestampedLog('Remote change detection started'));

      // Try to download existing library JSON from Google Drive
      final existingLibraryFile =
          await findExistingFile(driveApi, folderId, _libraryFileName);

      String? remoteJson;
      DriveLibraryMetadata? remoteMetadata;
      if (existingLibraryFile != null) {
        try {
          debugPrint(_timestampedLog('Remote library file found, downloading'));
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

          debugPrint(_timestampedLog(
              'Remote change detected - JSON downloaded and validated'));
        } catch (e) {
          debugPrint(_timestampedLog(
              'Error reading or parsing remote library JSON: $e'));
          // Treat corrupted remote file as if it doesn't exist
          remoteJson = null;
          remoteMetadata = null;
        }
      } else {
        debugPrint(_timestampedLog('No remote library file found'));
      }

      // Get current sync state to compare versions
      final syncState = await _librarySyncService.getSyncState();
      debugPrint(_timestampedLog(
          'Current sync state - Last remote version: ${syncState?.lastRemoteVersion}, Last sync: ${syncState?.lastSyncAt}'));

      // Merge remote library into local database (if remote exists and is valid)
      if (remoteJson != null && remoteJson.isNotEmpty) {
        debugPrint(
            _timestampedLog('Merge started - processing remote changes'));
        await _librarySyncService.importAndMergeLibraryFromJson(remoteJson);
        debugPrint(
            _timestampedLog('Merge completed - remote changes integrated'));
      } else {
        debugPrint(
            _timestampedLog('No merge needed - no remote changes to apply'));
      }

      // Export the merged library (now includes remote changes)
      final mergedJson = await _librarySyncService.exportLibraryToJson();
      debugPrint(_timestampedLog(
          'Local library exported - size: ${mergedJson.length} characters'));

      // Determine if upload is needed
      bool shouldUpload = false;
      if (remoteJson == null || remoteJson.isEmpty) {
        // No remote file exists, always upload
        shouldUpload = true;
        debugPrint(
            _timestampedLog('No remote file - will upload local library'));
      } else {
        // Check if merged library differs from remote
        shouldUpload =
            _librarySyncService.hasMergedLibraryChanged(mergedJson, remoteJson);
        if (shouldUpload) {
          debugPrint(_timestampedLog('Library changes detected - will upload'));
        } else {
          debugPrint(_timestampedLog('No library changes - skipping upload'));
        }
      }

      // Upload only if there are changes
      if (shouldUpload) {
        debugPrint(_timestampedLog('Uploading merged library to remote'));
        await _uploadLibraryJson(driveApi, folderId, mergedJson);

        // Store the hash of uploaded content and update metadata
        await _librarySyncService.storeUploadedLibraryHash(mergedJson);

        // Update sync state with remote metadata (after successful upload)
        if (remoteMetadata != null) {
          await _librarySyncService.database.updateSyncState(
            lastRemoteVersion: syncState?.lastRemoteVersion ?? 0,
            lastSyncAt: DateTime.now(),
            remoteMetadata: remoteMetadata,
          );
        }

        debugPrint(_timestampedLog('Remote upload completed'));
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
    } catch (e) {
      debugPrint(_timestampedLog('Merge failed: $e'));
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
      debugPrint('Error uploading library JSON: $e');
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
      debugPrint(_timestampedLog('Metadata polling already active'));
      return;
    }

    debugPrint(_timestampedLog('Starting metadata polling (10s interval)'));
    _isPollingActive = true;

    _metadataPollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      if (!_isPollingActive) {
        timer.cancel();
        return;
      }

      try {
        debugPrint(
            _timestampedLog('🔍 Metadata poll: checking remote file changes'));

        // Get remote metadata without downloading content
        final remoteMetadata = await getLibraryJsonMetadata();

        if (remoteMetadata != null) {
          // Check if remote file has changed since last sync
          final hasRemoteChanges =
              await _librarySyncService.hasRemoteChanges(remoteMetadata);

          if (hasRemoteChanges) {
            debugPrint(_timestampedLog(
                '🔄 Remote changes detected, triggering full sync'));
            // Trigger full sync through the sync provider
            await SyncServiceLocator.triggerAutoSync();
          } else {
            debugPrint(_timestampedLog('✅ No remote changes detected'));
          }
        }
      } catch (e) {
        debugPrint(_timestampedLog('⚠️ Error during metadata poll: $e'));
      }
    });
  }

  /// Stop metadata polling when app is paused/backgrounded
  void stopMetadataPolling() {
    if (!_isPollingActive) {
      return;
    }

    debugPrint(_timestampedLog('Stopping metadata polling'));
    _isPollingActive = false;
    _metadataPollingTimer?.cancel();
    _metadataPollingTimer = null;
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
