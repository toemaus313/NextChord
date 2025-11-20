import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nextchord/core/utils/justchords_importer.dart';
import 'package:nextchord/data/database/app_database.dart';
import 'package:nextchord/data/repositories/song_repository.dart';

/// Script to import 5 random songs from Justchords library.json
void main() async {
  debugPrint('🎵 Justchords to NextChord Importer\n');
  
  // Path to the library.json file
  const libraryPath = 'examples/library.json';
  
  debugPrint('📂 Reading from: $libraryPath');
  
  try {
    // Import 5 random songs
    final songs = await JustchordsImporter.importFromFile(
      libraryPath,
      count: 5,
    );
    
    debugPrint('✅ Successfully parsed ${songs.length} songs:\n');
    
    // Display the imported songs
    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      debugPrint('${i + 1}. "${song.title}" by ${song.artist}');
      debugPrint('   Key: ${song.key} | BPM: ${song.bpm} | Time: ${song.timeSignature}');
      debugPrint('   Tags: ${song.tags.join(", ")}');
      if (song.notes != null) {
        debugPrint('   Notes: ${song.notes}');
      }
      debugPrint('   Body preview (first 100 chars):');
      final preview = song.body.length > 100 
          ? '${song.body.substring(0, 100)}...' 
          : song.body;
      debugPrint('   ${preview.replaceAll('\n', '\n   ')}\n');
    }
    
    // Ask if user wants to save to database
    debugPrint('💾 Would you like to save these songs to the NextChord database? (y/n)');
    final response = stdin.readLineSync()?.toLowerCase();
    
    if (response == 'y' || response == 'yes') {
      debugPrint('\n📝 Saving to database...');
      
      // Initialize database
      final db = AppDatabase();
      final repository = SongRepository(db);
      
      // Save each song
      for (final song in songs) {
        await repository.insertSong(song);
        debugPrint('   ✓ Saved: ${song.title}');
      }
      
      debugPrint('\n✅ All songs saved successfully!');
      
      // Close database connection
      await db.close();
    } else {
      debugPrint('\n❌ Import cancelled. Songs were not saved to database.');
    }
    
  } catch (e) {
    debugPrint('❌ Error: $e');
    exit(1);
  }
}
