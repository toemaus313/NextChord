import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/database/app_database.dart';
import 'data/repositories/song_repository.dart';
import 'data/repositories/setlist_repository.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/appearance_provider.dart';
import 'presentation/providers/global_sidebar_provider.dart';
import 'presentation/providers/metronome_provider.dart';
import 'presentation/providers/metronome_settings_provider.dart';
import 'presentation/providers/autoscroll_provider.dart';
import 'presentation/providers/metadata_visibility_provider.dart';
import 'presentation/providers/song_provider.dart';
import 'presentation/providers/setlist_provider.dart';
import 'presentation/providers/share_import_provider.dart';
import 'providers/sync_provider.dart';
import 'presentation/widgets/app_wrapper.dart';
import 'core/services/database_change_service.dart';
import 'core/services/sync_service_locator.dart';
import 'services/import/share_import_service.dart';
import 'services/midi/midi_service.dart';

// Global debug configuration
bool isDebug = true;

void myDebug(String message) {
  if (isDebug) {
    final timestamp =
        DateTime.now().toIso8601String().substring(11, 19); // HH:MM:SS
    debugPrint('[$timestamp] $message');
  }
}

// Global navigator key for navigation from providers/services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handlers to catch SQLite errors and other exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    if (isDebug) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      debugPrint('[$timestamp] FRAMEWORK ERROR: ${details.exception}');
      debugPrint('[$timestamp] Stack trace: ${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (isDebug) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      debugPrint('[$timestamp] GLOBAL ERROR: $error');
      debugPrint('[$timestamp] Stack trace: $stack');
    }
    return true; // Prevent default error handling
  };

  // Configure system UI for all platforms
  if (Platform.isIOS || Platform.isAndroid) {
    // iOS (including iPad) and Android: Show status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Set status bar to be visible with dark icons on light background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons
        statusBarBrightness: Brightness.light, // Light background (iOS)
      ),
    );
  } else {
    // Desktop: Fullscreen
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  // Initialize database
  final database = AppDatabase();

  // Initialize services that depend on the database
  ShareImportService().initialize(database);

  // Initialize database change monitoring service
  DatabaseChangeService().initialize();

  // Initialize repository
  final songRepository = SongRepository(database);
  final setlistRepository = SetlistRepository(database);

  // Initialize providers
  final songProvider = SongProvider(songRepository);
  final setlistProvider = SetlistProvider(setlistRepository);

  // Initialize SyncProvider with refresh callback to ensure UI updates after sync
  final syncProvider = SyncProvider(
    database: database,
    onSyncCompleted: () {
      // Refresh data in providers after successful sync
      // Use post-frame callback to avoid build-phase setState errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        songProvider.loadSongs();
        songProvider
            .loadDeletedSongs(); // Also refresh deleted songs to prevent disappearing
        setlistProvider.loadSetlists();
      });
    },
  );
  SyncServiceLocator.initialize(syncProvider);

  runApp(NextChordApp(
    database: database,
    songRepository: songRepository,
    setlistRepository: setlistRepository,
    syncProvider: syncProvider,
    songProvider: songProvider,
    setlistProvider: setlistProvider,
  ));
}

class NextChordApp extends StatelessWidget {
  final AppDatabase database;
  final SongRepository songRepository;
  final SetlistRepository setlistRepository;
  final SyncProvider syncProvider;
  final SongProvider songProvider;
  final SetlistProvider setlistProvider;

  const NextChordApp({
    Key? key,
    required this.database,
    required this.songRepository,
    required this.setlistRepository,
    required this.syncProvider,
    required this.songProvider,
    required this.setlistProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Android-specific fix: Use FutureBuilder to delay widget tree construction
    // to prevent build-phase setState errors on Android
    return FutureBuilder<void>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _buildProviderTree(context);
        }
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _initializeApp() async {
    // Wait for next frame to ensure build phase is complete
    await Future.delayed(Duration.zero);
  }

  Widget _buildProviderTree(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<SongRepository>.value(value: songRepository),
        Provider<SetlistRepository>.value(value: setlistRepository),
        ChangeNotifierProvider.value(
          value: songProvider,
        ),
        ChangeNotifierProvider.value(
          value: setlistProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppearanceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => GlobalSidebarProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MetronomeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MetronomeSettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AutoscrollProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MetadataVisibilityProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ShareImportProvider(),
          lazy:
              false, // Must be non-lazy to initialize immediately and listen for share intents
        ),
        ChangeNotifierProvider.value(
          value: syncProvider,
        ),
        ChangeNotifierProvider.value(
          value: MidiService(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'NextChord',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode == ThemeModeType.system
                ? ThemeMode.system
                : (themeProvider.themeMode == ThemeModeType.dark
                    ? ThemeMode.dark
                    : ThemeMode.light),
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}
