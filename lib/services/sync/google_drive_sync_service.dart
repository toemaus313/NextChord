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
import 'library_sync_service.dart';

class GoogleDriveSyncService {
  final VoidCallback? _onDatabaseReplaced; // Callback to trigger reconnection
  final LibrarySyncService _librarySyncService;

  static GoogleSignIn? _googleSignIn;
  static String? _windowsAccessToken;
  static String? _windowsRefreshToken;
  static const String _windowsAuthRedirectUri = 'http://localhost:8000';
  static HttpServer? _authServer;

  // SharedPreferences keys for Windows token persistence
  static const String _accessTokenKey = 'windows_access_token_v2';
  static const String _refreshTokenKey = 'windows_refresh_token_v2';

  // Backup configuration
  static const String _backupFolderName = 'NextChord';
  static const String _libraryFileName = 'library.json';

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

  GoogleDriveSyncService({
    required AppDatabase database,
    VoidCallback? onDatabaseReplaced,
  })  : _onDatabaseReplaced = onDatabaseReplaced,
        _librarySyncService = LibrarySyncService(database) {
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

      // Perform JSON-based sync
      await _performJsonSync(driveApi, folderId);

      debugPrint('JSON-based sync completed successfully');
    } catch (e) {
      debugPrint('Sync failed: $e');
      rethrow;
    }
  }

  Future<void> _performJsonSync(
      drive.DriveApi driveApi, String folderId) async {
    try {
      // Try to download existing library JSON from Google Drive
      final existingLibraryFile =
          await _findExistingFile(driveApi, folderId, _libraryFileName);

      String? remoteJson;
      if (existingLibraryFile != null) {
        try {
          // Download existing remote library
          final response = await driveApi.files.get(
            existingLibraryFile.id!,
            downloadOptions: drive.DownloadOptions.fullMedia,
          ) as drive.Media;

          final bytes = await response.stream.fold<List<int>>(
            [],
            (list, chunk) => list..addAll(chunk),
          );
          remoteJson = utf8.decode(bytes);

          // Validate JSON format
          jsonDecode(remoteJson); // Will throw if invalid
        } catch (e) {
          debugPrint('Error reading or parsing remote library JSON: $e');
          // Treat corrupted remote file as if it doesn't exist
          remoteJson = null;
        }
      }

      // Merge remote library into local database (if remote exists and is valid)
      if (remoteJson != null && remoteJson.isNotEmpty) {
        await _librarySyncService.importAndMergeLibraryFromJson(remoteJson);
      }

      // Export the merged library (now includes remote changes)
      final mergedJson = await _librarySyncService.exportLibraryToJson();

      // Upload the merged library back to Google Drive
      await _uploadLibraryJson(driveApi, folderId, mergedJson);

      debugPrint('JSON sync completed successfully');
    } catch (e) {
      debugPrint('Error during JSON sync: $e');
      rethrow;
    }
  }

  Future<void> _uploadLibraryJson(
      drive.DriveApi driveApi, String folderId, String jsonContent) async {
    try {
      // Check if file already exists
      final existingFile =
          await _findExistingFile(driveApi, folderId, _libraryFileName);

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

  Future<void> handleInitialSync() async {
    try {
      // Check authentication status
      final isAuthenticated = await isSignedIn();
      if (!isAuthenticated) {
        return;
      }
    } catch (e) {}
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
