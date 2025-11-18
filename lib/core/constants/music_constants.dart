/// Music theory constants and utilities
class MusicConstants {
  // All semitones in chromatic scale
  static const List<String> chromaticScale = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  // Enharmonic equivalents (flats)
  static const Map<String, String> enharmonicFlats = {
    'C#': 'Db',
    'D#': 'Eb',
    'F#': 'Gb',
    'G#': 'Ab',
    'A#': 'Bb',
  };

  /// Get the position of a note in the chromatic scale
  static int getNotePosition(String note) {
    final cleanNote = note.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
    return chromaticScale.indexOf(cleanNote);
  }

  /// Transpose a note by a given number of semitones
  static String transposeNote(String note, int semitones) {
    final cleanNote = note.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
    int position = getNotePosition(cleanNote);

    if (position == -1) {
      return note; // Return original if not found
    }

    position = (position + semitones) % 12;
    if (position < 0) {
      position += 12;
    }

    return chromaticScale[position];
  }
}
