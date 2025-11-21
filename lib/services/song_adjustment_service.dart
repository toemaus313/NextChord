import '../../core/utils/chordpro_parser.dart';
import '../../core/constants/song_viewer_constants.dart';

/// Service for handling song adjustments like transpose and capo
class SongAdjustmentService {
  /// Calculate the effective transpose steps considering capo offset
  static int calculateEffectiveTranspose(int transposeSteps, int capoOffset) {
    return transposeSteps + capoOffset;
  }

  /// Calculate the capo offset from the original song
  static int calculateCapoOffset(int originalCapo, int currentCapo) {
    return originalCapo - currentCapo;
  }

  /// Format a signed value for display
  static String formatSignedValue(int value) {
    return value > 0 ? '+$value' : value.toString();
  }

  /// Generate transpose status label
  static String formatTransposeLabel(int effectiveTransposeSteps) {
    if (effectiveTransposeSteps == 0) return 'No transposition';
    final unit = effectiveTransposeSteps.abs() == 1 ? 'semitone' : 'semitones';
    return 'Transposed ${formatSignedValue(effectiveTransposeSteps)} $unit';
  }

  /// Generate capo status label
  static String formatCapoLabel(int currentCapo, int originalCapo) {
    if (currentCapo == originalCapo) {
      return 'Capo $currentCapo (song default)';
    }
    final direction = currentCapo > originalCapo ? 'higher' : 'lower';
    final difference = (originalCapo - currentCapo).abs();
    return 'Capo $currentCapo ($difference frets $direction than song)';
  }

  /// Get the transposed key display label
  static String? getKeyDisplayLabel(
      String baseKey, int effectiveTransposeSteps) {
    final trimmedKey = baseKey.trim();
    if (trimmedKey.isEmpty) return null;

    if (effectiveTransposeSteps == 0) {
      return 'Key of $trimmedKey';
    }

    final transposed =
        ChordProParser.transposeChord(trimmedKey, effectiveTransposeSteps);
    return 'Key of $transposed (${formatSignedValue(effectiveTransposeSteps)})';
  }

  /// Clamp transpose value within allowed range
  static int clampTranspose(int value) {
    return value.clamp(
        SongViewerConstants.minTranspose, SongViewerConstants.maxTranspose);
  }

  /// Clamp capo value within allowed range
  static int clampCapo(int value) {
    return value.clamp(
        SongViewerConstants.minCapo, SongViewerConstants.maxCapo);
  }

  /// Clamp font size within allowed range
  static double clampFontSize(double value) {
    return value.clamp(
        SongViewerConstants.minFontSize, SongViewerConstants.maxFontSize);
  }

  /// Calculate effective key for a song considering transpose and capo
  static String calculateEffectiveKey(
      String baseKey, int transposeSteps, int capoOffset) {
    final trimmedKey = baseKey.trim();
    if (trimmedKey.isEmpty) return '';

    final totalTranspose = transposeSteps + capoOffset;
    if (totalTranspose == 0) return trimmedKey;

    return ChordProParser.transposeChord(trimmedKey, totalTranspose);
  }
}
