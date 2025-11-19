import 'dart:io';
import '../lib/core/utils/justchords_importer.dart';
import '../lib/data/database/app_database.dart';
import '../lib/data/repositories/song_repository.dart';

/// Script to import 5 random songs from Justchords library.json
void main() async {
  print('🎵 Justchords to NextChord Importer\n');
  
  // Path to the library.json file
  final libraryPath = 'examples/library.json';
  
  print('📂 Reading from: $libraryPath');
  
  try {
    // Import 5 random songs
    final songs = await JustchordsImporter.importFromFile(
      libraryPath,
      count: 5,
    );
    
    print('✅ Successfully parsed ${songs.length} songs:\n');
    
    // Display the imported songs
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      print('${i + 1}. "${song.title}" by ${song.artist}');
      print('   Key: ${song.key} | BPM: ${song.bpm} | Time: ${song.timeSignature}');
      print('   Tags: ${song.tags.join(", ")}');
      if (song.notes != null) {
        print('   Notes: ${song.notes}');
      }
      print('   Body preview (first 100 chars):');
      final preview = song.body.length > 100 
          ? '${song.body.substring(0, 100)}...' 
          : song.body;
      print('   ${preview.replaceAll('\n', '\n   ')}\n');
    }
    
    // Ask if user wants to save to database
    print('💾 Would you like to save these songs to the NextChord database? (y/n)');
    final response = stdin.readLineSync()?.toLowerCase();
    
    if (response == 'y' || response == 'yes') {
      print('\n📝 Saving to database...');
      
      // Initialize database
      final db = AppDatabase();
      final repository = SongRepository(db);
      
      // Save each song
      for (final song in songs) {
        await repository.insertSong(song);
        print('   ✓ Saved: ${song.title}');
      }
      
      print('\n✅ All songs saved successfully!');
      
      // Close database connection
      await db.close();
    } else {
      print('\n❌ Import cancelled. Songs were not saved to database.');
    }
    
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
