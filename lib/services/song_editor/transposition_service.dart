import '../../core/utils/chordpro_parser.dart';
import '../../core/constants/music_constants.dart';

/// Service for handling key and capo transposition logic
class TranspositionService {
  static const Map<String, String> flatToSharpMap = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
  };

  /// Convert a key string to its semitone position in the chromatic scale
  static int? keyToSemitone(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^([A-Ga-g])([#b]?)(.*)$').firstMatch(trimmed);
    if (match == null) return null;

    final rootLetter = match.group(1)!.toUpperCase();
    final accidental = match.group(2) ?? '';
    String root = '$rootLetter$accidental';
    root = flatToSharpMap[root] ?? root;

    return MusicConstants.chromaticScale.indexOf(root);
  }

  /// Calculate the semitone difference between two keys
  static int? calculateKeyDifference(String fromKey, String toKey) {
    final fromIndex = keyToSemitone(fromKey);
    final toIndex = keyToSemitone(toKey);
    if (fromIndex == null || toIndex == null) return null;

    int diff = toIndex - fromIndex;
    if (diff.abs() > 6) {
      diff += diff > 0 ? -12 : 12;
    }
    return diff;
  }

  /// Transpose ChordPro text by the specified number of semitones
  static String transposeChordProText(String text, int semitones) {
    if (semitones == 0) return text;
    if (text.trim().isEmpty) return text;

    return ChordProParser.transposeChordProText(text, semitones);
  }

  /// Transpose a single chord by the specified number of semitones
  static String transposeChord(String chord, int semitones) {
    if (semitones == 0) return chord;
    if (chord.trim().isEmpty) return chord;

    return ChordProParser.transposeChord(chord, semitones);
  }

  /// Calculate capo transposition difference
  static int calculateCapoTransposeDifference(int fromCapo, int toCapo) {
    return fromCapo - toCapo;
  }

  /// Get the effective key when using a capo
  static String getEffectiveKeyWithCapo(String originalKey, int capo) {
    if (originalKey.isEmpty || capo == 0) return originalKey;

    final effectiveKey = transposeChord(originalKey, capo);
    return effectiveKey;
  }

  /// Get the original key from an effective key with capo
  static String getOriginalKeyFromCapo(String effectiveKey, int capo) {
    if (effectiveKey.isEmpty || capo == 0) return effectiveKey;

    final originalKey = transposeChord(effectiveKey, -capo);
    return originalKey;
  }

  /// Check if a key change requires transposition
  static bool requiresTransposition(String fromKey, String toKey) {
    final diff = calculateKeyDifference(fromKey, toKey);
    return diff != null && diff != 0;
  }

  /// Check if a capo change requires transposition
  static bool requiresCapoTransposition(int fromCapo, int toCapo) {
    return fromCapo != toCapo;
  }

  /// Get all available keys for dropdown
  static List<String> getAvailableKeys() {
    return [
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
      'Cm',
      'C#m',
      'Dm',
      'D#m',
      'Em',
      'Fm',
      'F#m',
      'Gm',
      'G#m',
      'Am',
      'A#m',
      'Bm'
    ];
  }

  /// Check if a key is a minor key
  static bool isMinorKey(String key) {
    return key.trim().toLowerCase().endsWith('m');
  }

  /// Get the relative major key for a minor key
  static String getRelativeMajor(String minorKey) {
    if (!isMinorKey(minorKey)) return minorKey;

    final root = minorKey.substring(0, minorKey.length - 1);
    final semitoneIndex = keyToSemitone(root);
    if (semitoneIndex == null) return minorKey;

    final majorIndex = (semitoneIndex + 3) % 12;
    final allKeys = getAvailableKeys().where((k) => !isMinorKey(k)).toList();
    return allKeys[majorIndex];
  }

  /// Get the relative minor key for a major key
  static String getRelativeMinor(String majorKey) {
    if (isMinorKey(majorKey)) return majorKey;

    final semitoneIndex = keyToSemitone(majorKey);
    if (semitoneIndex == null) return majorKey;

    final minorIndex = (semitoneIndex + 9) % 12;
    final allKeys = getAvailableKeys().where(isMinorKey).toList();
    return allKeys[minorIndex];
  }
}
