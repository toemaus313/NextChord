import '../data/repositories/song_repository.dart';
import '../domain/entities/song.dart';
import '../domain/entities/setlist.dart';
import '../presentation/providers/setlist_provider.dart';
import '../presentation/providers/global_sidebar_provider.dart';
import 'song_adjustment_service.dart';

/// Service for handling setlist navigation in the song viewer
class SetlistNavigationService {
  final SongRepository _songRepository;
  final SetlistProvider _setlistProvider;
  final GlobalSidebarProvider _globalSidebarProvider;

  SetlistNavigationService({
    required SongRepository songRepository,
    required SetlistProvider setlistProvider,
    required GlobalSidebarProvider globalSidebarProvider,
  })  : _songRepository = songRepository,
        _setlistProvider = setlistProvider,
        _globalSidebarProvider = globalSidebarProvider;

  /// Navigate to the next song in the setlist
  Future<Song?> navigateToNextSong() async {
    if (!_setlistProvider.isSetlistActive) {
      return null;
    }

    final nextSongItem = _setlistProvider.getNextSongItem();
    if (nextSongItem == null) {
      return null;
    }

    try {
      // Update setlist provider index first
      _setlistProvider
          .updateCurrentSongIndex(_setlistProvider.currentSongIndex + 1);

      // Get the next song from repository
      final nextSong = await _songRepository.getSongById(nextSongItem.songId);
      if (nextSong == null) {
        return null;
      }

      // Update global sidebar with new song and context
      _globalSidebarProvider.navigateToSongInSetlist(
          nextSong, _setlistProvider.currentSongIndex, nextSongItem);

      return nextSong;
    } catch (e) {
      return null;
    }
  }

  /// Navigate to the previous song in the setlist
  Future<Song?> navigateToPreviousSong() async {
    if (!_setlistProvider.isSetlistActive) {
      return null;
    }

    final prevSongItem = _setlistProvider.getPreviousSongItem();
    if (prevSongItem == null) {
      return null;
    }

    try {
      // Update setlist provider index first
      _setlistProvider
          .updateCurrentSongIndex(_setlistProvider.currentSongIndex - 1);

      // Get the previous song from repository
      final prevSong = await _songRepository.getSongById(prevSongItem.songId);
      if (prevSong == null) {
        return null;
      }

      // Update global sidebar with new song and context
      _globalSidebarProvider.navigateToSongInSetlist(
          prevSong, _setlistProvider.currentSongIndex, prevSongItem);

      return prevSong;
    } catch (e) {
      return null;
    }
  }

  /// Get the next song display text for the header
  Future<String?> getNextSongDisplayText() async {
    if (!_setlistProvider.isSetlistActive) {
      return null;
    }

    final nextSongItem = _setlistProvider.getNextSongItem();
    if (nextSongItem == null) {
      return null;
    }

    try {
      final nextSong = await _songRepository.getSongById(nextSongItem.songId);
      if (nextSong == null) {
        return null;
      }

      // Calculate the effective key considering transpose/capo
      final effectiveKey = _calculateEffectiveKey(nextSong, nextSongItem);

      // Format: "Next: <title> - <artist>      Key of <key> | Capo <capo#>"
      final artistText =
          nextSong.artist.isNotEmpty ? ' - ${nextSong.artist}' : '';
      final keyText = effectiveKey.isNotEmpty ? 'Key of $effectiveKey' : '';
      final capoText =
          nextSongItem.capo > 0 ? ' | Capo ${nextSongItem.capo}' : '';

      final displayText =
          'Next: ${nextSong.title}$artistText      $keyText$capoText';

      return displayText;
    } catch (e) {
      return null;
    }
  }

  /// Calculate effective key for a setlist song item
  String _calculateEffectiveKey(Song song, SetlistSongItem songItem) {
    final baseKey = song.key.trim();
    if (baseKey.isEmpty) return '';

    final transposeSteps = songItem.transposeSteps;
    final capoOffset = songItem.capo - song.capo;

    return SongAdjustmentService.calculateEffectiveKey(
        baseKey, transposeSteps, capoOffset);
  }

  /// Check if setlist navigation is available
  bool get canNavigate => _setlistProvider.isSetlistActive;

  /// Check if next song is available
  bool get hasNextSong => _setlistProvider.getNextSongItem() != null;

  /// Check if previous song is available
  bool get hasPreviousSong => _setlistProvider.getPreviousSongItem() != null;
}
