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
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:url_launcher/url_launcher.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/google_oauth_config.dart';

class GoogleDriveSyncService {
  DateTime? _lastSyncTime;
  final VoidCallback? _onDatabaseReplaced; // Callback to trigger reconnection

  // GoogleSignIn instance for native authentication
  static GoogleSignIn? _googleSignInInstance;

  // OAuth Web Flow fallback variables
  static Completer<String>? _oauthCodeCompleter;
  static HttpServer? _localServer;
  static const List<int> _possiblePorts = [8000, 8001, 8002, 8003, 8004];
  static int _currentPortIndex = 0;

  // SharedPreferences keys for persistent token storage
  static const String _accessTokenKey = 'web_access_token';
  static const String _refreshTokenKey = 'web_refresh_token';

  // Backup configuration
  static const String _backupFolderName = 'NextChord';
  static const String _backupFileName = 'nextchord_backup.db';
  static const String _syncMetadataFile = 'sync_metadata.json';

  GoogleDriveSyncService({VoidCallback? onDatabaseReplaced})
      : _onDatabaseReplaced = onDatabaseReplaced;

  GoogleSignIn get _googleSignIn =>
      GoogleDriveSyncService._getGoogleSignInInstance();

  static GoogleSignIn _getGoogleSignInInstance() {
    _googleSignInInstance ??= _createGoogleSignIn();
    return _googleSignInInstance!;
  }

  static GoogleSignIn _createGoogleSignIn() {
    // Define the scopes needed for Google Drive access
    const scopes = [
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/drive.file',
    ];

    debugPrint('Creating GoogleSignIn for platform: $defaultTargetPlatform');
    debugPrint('Client ID: ${GoogleOAuthConfig.clientId}');
    debugPrint(
        'Client ID source: ${defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android ? "Mobile (GoogleService-Info.plist)" : "Desktop/Web OAuth"}');
    debugPrint(
        'Client Secret: ${GoogleOAuthConfig.clientSecret.isNotEmpty ? 'configured' : 'missing'}');
    debugPrint('OAuth Configured: ${GoogleOAuthConfig.isConfigured}');

    // For desktop platforms (Windows, Linux, macOS), we need OAuth credentials
    // The package treats macOS as a desktop platform
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (GoogleOAuthConfig.isConfigured) {
        debugPrint('Using OAuth credentials for desktop platform');
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
        return GoogleSignIn(
          params: GoogleSignInParams(
            clientId: '',
            clientSecret: '',
            scopes: [],
          ),
        ); // Will fail gracefully
      }
    }

    // For mobile platforms (iOS, Android) - use standard flow
    debugPrint('Using standard GoogleSignIn for mobile/web platform');
    return GoogleSignIn(
      params: GoogleSignInParams(
        scopes: scopes,
      ),
    );
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

  // Helper methods for persistent token storage
  static Future<void> _storeWebTokens(
      String accessToken, String? refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      if (refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
      debugPrint('✓ Web tokens stored persistently');
    } catch (e) {
      debugPrint('Error storing web tokens: $e');
    }
  }

  static Future<String?> _getWebAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      debugPrint('Error getting web access token: $e');
      return null;
    }
  }

  static Future<void> _clearWebTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      debugPrint('✓ Web tokens cleared from persistent storage');
    } catch (e) {
      debugPrint('Error clearing web tokens: $e');
    }
  }

  Future<bool> isSignedIn() async {
    try {
      final account = await _googleSignIn.silentSignIn();
      if (account != null) return true;

      // Check web authentication
      final webAccessToken = await _getWebAccessToken();
      if (webAccessToken != null && webAccessToken.isNotEmpty) {
        return true;
      }

      return false;
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
      debugPrint('Starting Google Sign In...');
      debugPrint('Platform: $defaultTargetPlatform');
      debugPrint('OAuth Configured: ${GoogleOAuthConfig.isConfigured}');

      // Debug GoogleSignIn instance
      debugPrint('=== GoogleSignIn Instance Debug ===');
      debugPrint('GoogleSignIn instance: ${_googleSignIn.runtimeType}');

      // For iOS, try silent sign-in first to test if credentials are available
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('iOS detected - trying silent sign-in first...');
        try {
          final silentAccount = await _googleSignIn.silentSignIn();
          if (silentAccount != null) {
            debugPrint('Silent sign-in successful on iOS');
            return true;
          } else {
            debugPrint(
                'Silent sign-in returned null on iOS - proceeding with interactive sign-in');
          }
        } catch (silentError) {
          debugPrint('Silent sign-in failed on iOS: $silentError');
        }
      }

      // For macOS, try a different approach - use silentSignIn first
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        debugPrint('macOS detected - trying silent sign-in first...');
        try {
          final silentAccount = await _googleSignIn.silentSignIn();
          if (silentAccount != null) {
            debugPrint('Silent sign-in successful on macOS');
            return true;
          }
        } catch (silentError) {
          debugPrint('Silent sign-in failed on macOS: $silentError');
        }
      }

      debugPrint('Attempting full sign-in flow...');

      debugPrint('=== Starting sign-in process ===');
      debugPrint('NOTE: If sign-in UI does not appear in iOS simulator:');
      debugPrint('1. Make sure a Google account is added to iOS Simulator:');
      debugPrint('   Settings → Accounts & Passwords → Add Account → Google');
      debugPrint('2. Or try running on a physical iOS device');
      debugPrint('3. Check if the simulator has network access');

      final account = await _googleSignIn.signIn().timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('Sign in timed out after 2 minutes');
          debugPrint('This might indicate the sign-in UI is not appearing');
          throw Exception('Sign in timed out - UI may not have appeared');
        },
      ).catchError((error) {
        debugPrint('=== GoogleSignIn.signIn() error ===');
        debugPrint('Error: $error');
        debugPrint('Error type: ${error.runtimeType}');
        debugPrint('Stack trace: ${StackTrace.current}');
        return null;
      });

      debugPrint('Sign in completed, checking account details...');
      debugPrint('Account is null: ${account == null}');
      if (account != null) {
        debugPrint('Access token exists: ${account.accessToken.isNotEmpty}');
        debugPrint('Access token length: ${account.accessToken.length}');
        debugPrint('Access token preview: "${account.accessToken}"');
      } else {
        debugPrint('Account is null after sign-in');

        // For iOS, try web authentication as fallback
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint(
              '=== iOS native sign-in failed, trying web auth fallback ===');
          debugPrint('This will open a web browser for Google authentication');
          debugPrint('No Google account setup needed in iOS simulator!');

          try {
            final webAuthSuccess = await _attemptWebAuthentication();
            if (webAuthSuccess) {
              debugPrint('✓ Web authentication successful!');
              debugPrint('=== Sign-in method returning: true (web auth) ===');
              return true;
            } else {
              debugPrint('✗ Web authentication also failed');
            }
          } catch (webError) {
            debugPrint('✗ Web authentication exception: $webError');
          }
        }
      }

      if (account != null) {
        // Verify we can actually use the credentials
        try {
          final testCredentials = await _googleSignIn.silentSignIn();
          debugPrint(
              'Silent sign-in test: ${testCredentials != null ? 'Success' : 'Failed'}');
        } catch (testError) {
          debugPrint('Silent sign-in test failed: $testError');
        }
      }

      debugPrint('=== Sign-in method returning: ${account != null} ===');
      return account != null;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      debugPrint('Error type: ${e.runtimeType}');

      if (e.toString().contains('Operation not permitted')) {
        debugPrint('macOS "Operation not permitted" error detected');
        debugPrint('This is likely a macOS security restriction');
        debugPrint('Try these solutions:');
        debugPrint('1. Run: flutter run -d macos --release');
        debugPrint('2. Check System Settings → Privacy & Security → Network');
        debugPrint('3. Try building for distribution instead of debug');
        debugPrint(
            '4. Consider using iOS simulator instead of macOS for testing');
      }

      // Try to clean up any partial authentication state
      try {
        await _googleSignIn.signOut();
        debugPrint('Cleaned up partial authentication state');
      } catch (cleanupError) {
        debugPrint('Error during cleanup: $cleanupError');
      }

      return false;
    }
  }

  Future<bool> _attemptWebAuthentication() async {
    try {
      debugPrint('=== Attempting web OAuth flow ===');

      // Start localhost HTTP server
      await _startLocalServer();

      // Generate OAuth URL
      final authUrl = _buildOAuthUrl();
      debugPrint('OAuth URL: $authUrl');

      // Launch browser
      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        debugPrint('✗ Failed to launch browser');
        return false;
      }

      debugPrint('✓ Browser launched for OAuth');

      // Wait for authorization code
      _oauthCodeCompleter = Completer<String>();
      final authCode = await _oauthCodeCompleter!.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          debugPrint('OAuth flow timed out');
          throw Exception('OAuth flow timed out');
        },
      );

      debugPrint('✓ Received authorization code');

      // Exchange code for tokens
      final success = await _exchangeCodeForTokens(authCode);
      if (success) {
        debugPrint('✓ Web authentication completed successfully');
        return true;
      } else {
        debugPrint('✗ Token exchange failed');
        return false;
      }
    } catch (e) {
      debugPrint('✗ Web authentication failed: $e');
      return false;
    } finally {
      // Clean up local server
      await _localServer?.close();
      _localServer = null;
      _oauthCodeCompleter = null;
    }
  }

  Future<void> _startLocalServer() async {
    debugPrint('=== Starting local HTTP server ===');

    // Force cleanup any existing server with retries
    for (int i = 0; i < 3; i++) {
      try {
        await _localServer?.close();
        _localServer = null;
        break;
      } catch (e) {
        debugPrint('Cleanup attempt ${i + 1} failed: $e');
        await Future.delayed(Duration(milliseconds: 100));
      }
    }

    // Try each port until one works
    for (int portIndex = 0; portIndex < _possiblePorts.length; portIndex++) {
      final port = _possiblePorts[portIndex];

      // Create handler for OAuth callback
      final handler = (Request request) async {
        debugPrint('=== Local server received request: ${request.url} ===');

        // Listen on root path "/" to match redirect URI
        if (request.url.path == '/' || request.url.path.isEmpty) {
          final code = request.url.queryParameters['code'];
          final error = request.url.queryParameters['error'];

          if (error != null) {
            debugPrint('✗ OAuth error: $error');
            _oauthCodeCompleter
                ?.completeError(Exception('OAuth error: $error'));
            return Response.ok(
                'Authentication failed. You can close this window.');
          }

          if (code != null) {
            debugPrint('✓ Received authorization code');
            _oauthCodeCompleter?.complete(code);
            return Response.ok(
                'Authentication successful! You can close this window.');
          } else {
            debugPrint('✗ No code or error in OAuth callback');
            _oauthCodeCompleter
                ?.completeError(Exception('Invalid OAuth callback'));
            return Response.ok('Invalid callback. You can close this window.');
          }
        }

        return Response.notFound('Not found');
      };

      try {
        _localServer = await shelf_io.serve(handler, 'localhost', port);
        _currentPortIndex = portIndex;
        debugPrint('✓ Local server started on http://localhost:$port');
        return;
      } catch (e) {
        debugPrint('Port $port failed: $e');
        if (portIndex == _possiblePorts.length - 1) {
          rethrow; // Re-throw if all ports fail
        }
      }
    }
  }

  String _buildOAuthUrl() {
    const clientId =
        '466612959108-8jg6fk21nmj26b2euo2qgc71trkojdtr.apps.googleusercontent.com';
    final actualPort = _possiblePorts[_currentPortIndex];
    final redirectUri =
        'http://localhost:$actualPort'; // No trailing slash - matches working port 8000 format
    const scopes =
        'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/drive.file';

    // Generate random state for security
    final state = DateTime.now().millisecondsSinceEpoch.toString();

    return 'https://accounts.google.com/o/oauth2/v2/auth'
        '?client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&response_type=code'
        '&scope=$scopes'
        '&state=$state'
        '&access_type=offline'
        '&prompt=consent';
  }

  Future<bool> _exchangeCodeForTokens(String authCode) async {
    try {
      debugPrint('=== Exchanging authorization code for tokens ===');

      const clientId =
          '466612959108-8jg6fk21nmj26b2euo2qgc71trkojdtr.apps.googleusercontent.com';
      const clientSecret = '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';
      final actualPort = _possiblePorts[_currentPortIndex];
      final redirectUri =
          'http://localhost:$actualPort'; // Use same dynamic port as OAuth URL

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': authCode,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode != 200) {
        debugPrint('✗ Token exchange failed: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }

      final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String;
      final refreshToken = tokenData['refresh_token'] as String?;

      debugPrint('✓ Token exchange successful');
      debugPrint('Access token length: ${accessToken.length}');
      debugPrint('Refresh token available: ${refreshToken != null}');

      // Store tokens persistently
      await _storeWebTokens(accessToken, refreshToken);

      return true;
    } catch (e) {
      debugPrint('✗ Token exchange error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from native authentication
      await _googleSignIn.signOut();
      debugPrint('✓ Native sign-out completed');

      // Clear web authentication state from persistent storage
      await _clearWebTokens();
      debugPrint('✓ Web authentication cleared');

      // Reset authentication state
      _lastSyncTime = null;

      debugPrint('✓ Authentication state reset');
    } catch (e) {
      debugPrint('Error during sign-out: $e');
      // Reset state even if sign-out fails
      _lastSyncTime = null;
      await _clearWebTokens();
    }
  }

  Future<drive.DriveApi> _createDriveApi() async {
    String? accessToken;

    // Try native authentication first
    try {
      final nativeCredentials = await _googleSignIn.silentSignIn();
      if (nativeCredentials != null &&
          nativeCredentials.accessToken.isNotEmpty) {
        accessToken = nativeCredentials.accessToken;
      }
    } catch (e) {
      // Silent sign-in failed, try interactive sign-in
      try {
        final account = await _googleSignIn.signIn().timeout(
              const Duration(seconds: 30),
            );
        if (account != null && account.accessToken.isNotEmpty) {
          accessToken = account.accessToken;
        }
      } catch (signInError) {
        // If native sign-in fails, fall back to web auth
      }
    }

    // Fall back to web authentication from persistent storage if native failed
    if (accessToken == null) {
      try {
        accessToken = await _getWebAccessToken();
      } catch (e) {
        // Web auth also failed
      }
    }

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('No valid authentication token available');
    }

    // Create authenticated HTTP client
    final credentials = auth.AccessCredentials(
      auth.AccessToken('Bearer', accessToken,
          DateTime.now().add(const Duration(hours: 1)).toUtc()),
      null, // No refresh token for native auth
      ['https://www.googleapis.com/auth/drive.file'],
    );

    final authClient = auth.authenticatedClient(http.Client(), credentials);
    return drive.DriveApi(authClient);
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
      if (localDbPath == null) {
        debugPrint('✗ Failed to get local database path');
        return;
      }

      // Download and merge remote database if newer
      await _downloadAndMergeDatabase(driveApi, folderId, localDbPath);

      // Upload local database to Google Drive
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

  Future<void> _downloadAndMergeDatabase(
      drive.DriveApi driveApi, String folderId, String localDbPath) async {
    try {
      debugPrint('=== Checking for remote database ===');
      debugPrint('Folder ID: $folderId');
      debugPrint('Database filename: $_backupFileName');
      debugPrint('Metadata filename: $_syncMetadataFile');

      // Find existing database file
      final existingDbFile =
          await _findExistingFile(driveApi, folderId, _backupFileName);
      if (existingDbFile == null) {
        debugPrint('✓ No remote database found, using local database');
        return;
      }
      debugPrint('✓ Found remote database file: ${existingDbFile.id}');

      // Find existing metadata file
      final existingMetadataFile =
          await _findExistingFile(driveApi, folderId, _syncMetadataFile);
      if (existingMetadataFile == null) {
        debugPrint('✓ No remote metadata found, using local database');
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

      // If remote is newer, download it
      if (remoteLastSync.isAfter(localLastModified)) {
        debugPrint('✓ Remote database is newer, downloading...');
        await _downloadAndReplaceDatabase(
            driveApi, existingDbFile, localDbPath);
      } else {
        debugPrint('✓ Local database is newer or up-to-date');
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

  Future<String?> _getLocalDatabasePath() async {
    try {
      // Use the same path as AppDatabase _openConnection()
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dbFolder.path, 'nextchord_db.sqlite');

      // Check if the database file exists
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        debugPrint('✓ Found database at: $dbPath');
        return dbPath;
      }

      debugPrint('✗ Database file not found at: $dbPath');
      return null;
    } catch (e) {
      debugPrint('Error getting local database path: $e');
      return null;
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

  Future<void> _downloadAndReplaceDatabase(
      drive.DriveApi driveApi, drive.File remoteFile, String localPath) async {
    debugPrint('=== Downloading and merging database ===');

    final response = await driveApi.files.get(remoteFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    // Download to temporary file
    final tempPath = '$localPath.remote';
    final tempFile = File(tempPath);

    await response.stream.pipe(tempFile.openWrite());

    // Validate the downloaded file
    if (await _validateDatabase(tempPath)) {
      debugPrint('✓ Remote database is valid, merging data');

      // Merge data from remote database instead of replacing file
      await _mergeDatabaseData(tempPath, localPath);

      // Clean up temporary file
      await tempFile.delete();

      debugPrint('✓ Database merge completed successfully');
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

  Future<void> _mergeDatabaseData(
      String remoteDbPath, String localDbPath) async {
    try {
      // Open both databases
      final remoteDb = await sqlite.openDatabase(remoteDbPath);
      final localDb = await sqlite.openDatabase(localDbPath);

      // Check if isDeleted column exists in remote database
      final remoteTableInfo =
          await remoteDb.rawQuery("PRAGMA table_info(songs)");
      final remoteHasIsDeleted =
          remoteTableInfo.any((column) => column['name'] == 'isDeleted');

      // Check if isDeleted column exists in local database
      final localTableInfo = await localDb.rawQuery("PRAGMA table_info(songs)");
      final localHasIsDeleted =
          localTableInfo.any((column) => column['name'] == 'isDeleted');

      // Build queries based on available columns
      final remoteSongQuery = remoteHasIsDeleted
          ? 'SELECT * FROM songs WHERE isDeleted = false'
          : 'SELECT * FROM songs';
      final remoteSetlistQuery = remoteHasIsDeleted
          ? 'SELECT * FROM setlists WHERE isDeleted = false'
          : 'SELECT * FROM setlists';

      // Get data from databases
      final remoteSongs = await remoteDb.rawQuery(remoteSongQuery);
      final remoteSetlists = await remoteDb.rawQuery(remoteSetlistQuery);

      // Merge songs
      for (final song in remoteSongs) {
        final existingSong = await localDb.rawQuery(
            'SELECT id, updated_at FROM songs WHERE id = ?', [song['id']]);

        if (existingSong.isEmpty) {
          final songToInsert = Map<String, dynamic>.from(song);
          if (!remoteHasIsDeleted && localHasIsDeleted) {
            songToInsert['isDeleted'] = false;
          }
          await localDb.insert('songs', songToInsert);
        } else {
          final remoteUpdated = _parseTimestamp(song['updated_at']);
          final localUpdated =
              _parseTimestamp(existingSong.first['updated_at']);

          if (remoteUpdated.isAfter(localUpdated)) {
            final songToUpdate = Map<String, dynamic>.from(song);
            if (!remoteHasIsDeleted && localHasIsDeleted) {
              songToUpdate['isDeleted'] = false;
            }
            await localDb.update('songs', songToUpdate,
                where: 'id = ?', whereArgs: [song['id']]);
          }
        }
      }

      // Merge setlists
      for (final setlist in remoteSetlists) {
        final existingSetlist = await localDb.rawQuery(
            'SELECT id, updated_at FROM setlists WHERE id = ?',
            [setlist['id']]);

        if (existingSetlist.isEmpty) {
          final setlistToInsert = Map<String, dynamic>.from(setlist);
          if (!remoteHasIsDeleted && localHasIsDeleted) {
            setlistToInsert['isDeleted'] = false;
          }
          await localDb.insert('setlists', setlistToInsert);
        } else {
          final remoteUpdated = _parseTimestamp(setlist['updated_at']);
          final localUpdated =
              _parseTimestamp(existingSetlist.first['updated_at']);

          if (remoteUpdated.isAfter(localUpdated)) {
            final setlistToUpdate = Map<String, dynamic>.from(setlist);
            if (!remoteHasIsDeleted && localHasIsDeleted) {
              setlistToUpdate['isDeleted'] = false;
            }
            await localDb.update('setlists', setlistToUpdate,
                where: 'id = ?', whereArgs: [setlist['id']]);
          }
        }
      }

      // Close databases
      await remoteDb.close();
      await localDb.close();

      // Trigger data refresh callback
      if (_onDatabaseReplaced != null) {
        _onDatabaseReplaced!();
      }
    } catch (e) {
      debugPrint('✗ Database merge failed: $e');
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

  Future<drive.File?> _findFileByPath(
      drive.DriveApi driveApi, String path) async {
    debugPrint('=== Finding file by path: $path ===');

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
        return null; // Path component exists but is not a folder
      }

      parentId = file.id;
    }

    return null;
  }

  /// Reset the GoogleSignIn instance (useful for testing and switching auth modes)
  static void resetGoogleSignInInstance() {
    _googleSignInInstance = null;
  }
}
