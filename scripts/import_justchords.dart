import 'dart:io';
import 'package:nextchord/core/utils/justchords_importer.dart';
import 'package:nextchord/data/database/app_database.dart';
import 'package:nextchord/data/repositories/song_repository.dart';

/// Script to import 5 random songs from Justchords library.json
void main() async {
  // Path to the library.json file
  const libraryPath = 'examples/library.json';

  try {
    // Import 5 random songs
    final songs = await JustchordsImporter.importFromFile(
      libraryPath,
      count: 5,
    );

    // Ask if user wants to save to database
    final response = stdin.readLineSync()?.toLowerCase();

    if (response == 'y' || response == 'yes') {
      // Initialize database
      final db = AppDatabase();
      final repository = SongRepository(db);

      // Save each song
      for (final song in songs) {
        await repository.insertSong(song);
      }

      // Close database connection
      await db.close();
    } else {
      // Import cancelled
    }
  } catch (e) {
    exit(1);
  }
}
