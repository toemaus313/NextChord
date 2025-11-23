import '../../domain/entities/song.dart';
import '../../domain/entities/midi_profile.dart';
import '../../data/repositories/song_repository.dart';

/// Service for handling song persistence operations (create, update, delete)
class SongPersistenceService {
  /// Save a new song to the database with optional MIDI profile assignment
  static Future<SongPersistenceResult> saveSong({
    required Song song,
    required String? midiProfileId,
    required SongRepository repository,
  }) async {
    try {
      // Ensure database schema is up to date before operations
      // await repository.database.ensureMidiProfilesTable(); // MIDI profiles removed during refactoring

      // Save the song
      final newSongId = await repository.insertSong(song);
      final savedSong = song.copyWith(id: newSongId);

      // Assign MIDI profile if provided
      if (midiProfileId != null) {
        await repository.assignMidiProfileToSong(newSongId, midiProfileId);
      }

      return SongPersistenceResult.success(savedSong);
    } catch (e) {
      return SongPersistenceResult.failure('Error saving song: $e');
    }
  }

  /// Update an existing song with optional MIDI profile assignment
  static Future<SongPersistenceResult> updateSong({
    required Song song,
    required String? midiProfileId,
    required SongRepository repository,
  }) async {
    try {
      // Ensure database schema is up to date before operations
      // await repository.database.ensureMidiProfilesTable(); // MIDI profiles removed during refactoring

      // Update the song
      await repository.updateSong(song);

      // Update MIDI profile assignment
      await repository.assignMidiProfileToSong(song.id, midiProfileId);

      return SongPersistenceResult.success(song);
    } catch (e) {
      return SongPersistenceResult.failure('Error updating song: $e');
    }
  }

  /// Delete a song from the database
  static Future<SongPersistenceResult> deleteSong({
    required String songId,
    required SongRepository repository,
  }) async {
    try {
      await repository.deleteSong(songId);
      return SongPersistenceResult.success(null);
    } catch (e) {
      return SongPersistenceResult.failure('Error deleting song: $e');
    }
  }

  /// Load MIDI profile for a song
  static Future<MidiProfile?> loadSongMidiProfile({
    required String songId,
    required SongRepository repository,
  }) async {
    try {
      return await repository.getSongMidiProfile(songId);
    } catch (e) {
      // Return null on error - MIDI profile is optional
      return null;
    }
  }

  /// Load all available MIDI profiles
  static Future<List<MidiProfile>> loadMidiProfiles({
    required SongRepository repository,
  }) async {
    try {
      // Ensure database schema is up to date before loading profiles
      // await repository.database.ensureMidiProfilesTable(); // MIDI profiles removed during refactoring

      return await repository.getAllMidiProfiles();
    } catch (e) {
      // Return empty list on error - MIDI profiles are optional
      return [];
    }
  }

  /// Validate song data before saving
  static SongValidationResult validateSongData({
    required String title,
    required String artist,
    required String body,
    required String bpm,
    required String duration,
  }) {
    // Check required fields
    if (title.trim().isEmpty) {
      return SongValidationResult.failure('Title is required');
    }

    if (artist.trim().isEmpty) {
      return SongValidationResult.failure('Artist is required');
    }

    if (body.trim().isEmpty) {
      return SongValidationResult.failure('Song body is required');
    }

    // Validate BPM
    final bpmValue = int.tryParse(bpm.trim());
    if (bpmValue == null || bpmValue < 1 || bpmValue > 300) {
      return SongValidationResult.failure('BPM must be between 1 and 300');
    }

    // Validate duration (optional)
    if (duration.trim().isNotEmpty) {
      final pattern = RegExp(r'^(\d{1,2}:)?\d{1,2}:\d{2}$');
      if (!pattern.hasMatch(duration.trim())) {
        return SongValidationResult.failure(
            'Duration format should be MM:SS or H:MM:SS');
      }
    }

    return SongValidationResult.success();
  }

  /// Update ChordPro body with duration directive
  static String updateBodyWithDuration(String body, String duration) {
    if (duration.trim().isEmpty) return body;

    // Check if duration directive already exists
    final durationRegex = RegExp(r'\{duration:[^}]*\}', caseSensitive: false);
    String updatedBody = body.trim();

    if (durationRegex.hasMatch(updatedBody)) {
      // Update existing duration
      updatedBody =
          updatedBody.replaceFirst(durationRegex, '{duration:$duration}');
    } else {
      // Add duration directive at the beginning (after title/artist if present)
      final lines = updatedBody.split('\n');
      int insertIndex = 0;

      // Find position after title/artist/key directives
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('{') &&
            (lines[i].contains('title:') ||
                lines[i].contains('artist:') ||
                lines[i].contains('subtitle:') ||
                lines[i].contains('key:'))) {
          insertIndex = i + 1;
        } else if (!lines[i].trim().startsWith('{')) {
          break;
        }
      }

      lines.insert(insertIndex, '{duration:$duration}');
      updatedBody = lines.join('\n');
    }

    return updatedBody;
  }
}

/// Result of a song persistence operation
class SongPersistenceResult {
  final bool success;
  final Song? song;
  final String? error;

  const SongPersistenceResult._({
    required this.success,
    this.song,
    this.error,
  });

  factory SongPersistenceResult.success(Song? song) {
    return SongPersistenceResult._(success: true, song: song);
  }

  factory SongPersistenceResult.failure(String error) {
    return SongPersistenceResult._(success: false, error: error);
  }
}

/// Result of song data validation
class SongValidationResult {
  final bool isValid;
  final String? error;

  const SongValidationResult._({
    required this.isValid,
    this.error,
  });

  factory SongValidationResult.success() {
    return const SongValidationResult._(isValid: true);
  }

  factory SongValidationResult.failure(String error) {
    return SongValidationResult._(isValid: false, error: error);
  }
}
