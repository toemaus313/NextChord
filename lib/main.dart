import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'data/database/app_database.dart';
import 'data/repositories/song_repository.dart';
import 'data/repositories/setlist_repository.dart';
import 'presentation/providers/song_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/global_sidebar_provider.dart';
import 'presentation/providers/metronome_provider.dart';
import 'presentation/providers/metronome_settings_provider.dart';
import 'presentation/providers/autoscroll_provider.dart';
import 'presentation/providers/setlist_provider.dart';
import 'services/midi/midi_service.dart';
import 'presentation/widgets/app_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hide the iOS status bar while the app is open to avoid overlaying UI.
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
  }

  // Initialize database
  final database = AppDatabase();

  // Initialize repository
  final songRepository = SongRepository(database);
  final setlistRepository = SetlistRepository(database);

  runApp(NextChordApp(
    database: database,
    songRepository: songRepository,
    setlistRepository: setlistRepository,
  ));
}

class NextChordApp extends StatelessWidget {
  final AppDatabase database;
  final SongRepository songRepository;
  final SetlistRepository setlistRepository;

  const NextChordApp({
    Key? key,
    required this.database,
    required this.songRepository,
    required this.setlistRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<SongRepository>.value(value: songRepository),
        Provider<SetlistRepository>.value(value: setlistRepository),
        ChangeNotifierProvider(
          create: (_) => SongProvider(songRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => SetlistProvider(setlistRepository),
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
