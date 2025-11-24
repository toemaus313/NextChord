import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'data/database/app_database.dart';
import 'data/repositories/song_repository.dart';
import 'data/repositories/setlist_repository.dart';
import 'presentation/providers/song_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/global_sidebar_provider.dart';
import 'presentation/providers/metadata_visibility_provider.dart';
import 'presentation/providers/metronome_provider.dart';
import 'presentation/providers/metronome_settings_provider.dart';
import 'presentation/providers/autoscroll_provider.dart';
import 'presentation/providers/setlist_provider.dart';
import 'providers/sync_provider.dart';
import 'services/midi/midi_service.dart';
import 'core/services/sync_service_locator.dart';
import 'core/services/database_change_service.dart';
import 'presentation/widgets/app_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable system status bar on mobile devices, hide on desktop/tablet
  if (Platform.isIOS || Platform.isAndroid) {
    // Mobile: Show status bar with clock and icons
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  } else {
    // Desktop/Tablet: Hide status bar for fullscreen experience
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  // Initialize database
  final database = AppDatabase();

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
      debugPrint(
          '🔄 onSyncCompleted callback triggered - checking if in build phase');
      // Refresh data in providers after successful sync
      // Use post-frame callback to avoid build-phase setState errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('🔄 Post-frame callback executing - calling loadSongs()');
        songProvider.loadSongs();
        songProvider
            .loadDeletedSongs(); // Also refresh deleted songs to prevent disappearing
        setlistProvider.loadSetlists();
        debugPrint(
            '🔄 All provider load methods called in post-frame callback');
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
    debugPrint(
        '🏗️ NextChordApp.build() called - platform-specific build phase');

    // Android-specific fix: Use FutureBuilder to delay widget tree construction
    // to prevent build-phase setState errors on Android
    return FutureBuilder<void>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          debugPrint('🏗️ App initialization complete - building widget tree');
          return _buildProviderTree(context);
        }
        debugPrint('🏗️ App initializing - showing loading indicator');
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
    debugPrint('🏗️ App initialization completed after frame delay');
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
        ChangeNotifierProvider.value(
          value: syncProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => MidiService(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'NextChord',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}
