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

      // Add/update with local records (keeping newest)
      for (final song in localSongs) {
        final songId = song['id'] as String;
        final localUpdated = _parseTimestamp(song['updated_at']);

        if (allSongs.containsKey(songId)) {
          final remoteUpdated =
              _parseTimestamp(allSongs[songId]!['updated_at']);
          if (localUpdated.isAfter(remoteUpdated)) {
            allSongs[songId] = song;
          }
        } else {
          allSongs[songId] = song;
        }
      }

      for (final setlist in localSetlists) {
        final setlistId = setlist['id'] as String;
        final localUpdated = _parseTimestamp(setlist['updated_at']);

        if (allSetlists.containsKey(setlistId)) {
          final remoteUpdated =
              _parseTimestamp(allSetlists[setlistId]!['updated_at']);
          if (localUpdated.isAfter(remoteUpdated)) {
            allSetlists[setlistId] = setlist;
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
