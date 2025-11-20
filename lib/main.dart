import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database/app_database.dart';
import 'data/repositories/song_repository.dart';
import 'presentation/providers/song_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/global_sidebar_provider.dart';
import 'presentation/providers/metronome_provider.dart';
import 'presentation/widgets/app_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final database = AppDatabase();

  // Initialize repository
  final songRepository = SongRepository(database);

  runApp(NextChordApp(
    songRepository: songRepository,
  ));
}

class NextChordApp extends StatelessWidget {
  final SongRepository songRepository;

  const NextChordApp({
    Key? key,
    required this.songRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SongRepository>.value(value: songRepository),
        ChangeNotifierProvider(
          create: (_) => SongProvider(songRepository),
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
