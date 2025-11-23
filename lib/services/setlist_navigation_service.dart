import '../core/utils/logger.dart';
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
    Logger.methodEntry('SetlistNavigationService', 'navigateToNextSong');

    if (!_setlistProvider.isSetlistActive) {
      Logger.navigation('No active setlist - cannot navigate');
      Logger.methodExit('SetlistNavigationService', 'navigateToNextSong', null);
      return null;
    }

    final nextSongItem = _setlistProvider.getNextSongItem();
    if (nextSongItem == null) {
      Logger.navigation('No next song item found');
      Logger.methodExit('SetlistNavigationService', 'navigateToNextSong', null);
      return null;
    }

    try {
      // Update setlist provider index first
      _setlistProvider
          .updateCurrentSongIndex(_setlistProvider.currentSongIndex + 1);

      // Get the next song from repository
      final nextSong = await _songRepository.getSongById(nextSongItem.songId);
      if (nextSong == null) {
        Logger.navigation(
            'Next song not found in repository: ${nextSongItem.songId}');
        Logger.methodExit(
            'SetlistNavigationService', 'navigateToNextSong', null);
        return null;
      }

      // Update global sidebar with new song and context
      _globalSidebarProvider.navigateToSongInSetlist(
          nextSong, _setlistProvider.currentSongIndex, nextSongItem);

      Logger.navigation(
          'Successfully navigated to next song: ${nextSong.title}');
      Logger.methodExit(
          'SetlistNavigationService', 'navigateToNextSong', nextSong);
      return nextSong;
    } catch (e) {
      Logger.error('Error navigating to next song', e);
      Logger.methodExit('SetlistNavigationService', 'navigateToNextSong', null);
      return null;
    }
  }

  /// Navigate to the previous song in the setlist
  Future<Song?> navigateToPreviousSong() async {
    Logger.methodEntry('SetlistNavigationService', 'navigateToPreviousSong');

    if (!_setlistProvider.isSetlistActive) {
      Logger.navigation('No active setlist - cannot navigate');
      Logger.methodExit(
          'SetlistNavigationService', 'navigateToPreviousSong', null);
      return null;
    }

    final prevSongItem = _setlistProvider.getPreviousSongItem();
    if (prevSongItem == null) {
      Logger.navigation('No previous song item found');
      Logger.methodExit(
          'SetlistNavigationService', 'navigateToPreviousSong', null);
      return null;
    }

    try {
      // Update setlist provider index first
      _setlistProvider
          .updateCurrentSongIndex(_setlistProvider.currentSongIndex - 1);

      // Get the previous song from repository
      final prevSong = await _songRepository.getSongById(prevSongItem.songId);
      if (prevSong == null) {
        Logger.navigation(
            'Previous song not found in repository: ${prevSongItem.songId}');
        Logger.methodExit(
            'SetlistNavigationService', 'navigateToPreviousSong', null);
        return null;
      }

      // Update global sidebar with new song and context
      _globalSidebarProvider.navigateToSongInSetlist(
          prevSong, _setlistProvider.currentSongIndex, prevSongItem);

      Logger.navigation(
          'Successfully navigated to previous song: ${prevSong.title}');
      Logger.methodExit(
          'SetlistNavigationService', 'navigateToPreviousSong', prevSong);
      return prevSong;
    } catch (e) {
      Logger.error('Error navigating to previous song', e);
      Logger.methodExit(
          'SetlistNavigationService', 'navigateToPreviousSong', null);
      return null;
    }
  }

  /// Get the next song display text for the header
  Future<String?> getNextSongDisplayText() async {
    Logger.methodEntry('SetlistNavigationService', 'getNextSongDisplayText');

    if (!_setlistProvider.isSetlistActive) {
      Logger.methodExit(
          'SetlistNavigationService', 'getNextSongDisplayText', null);
      return null;
    }

    final nextSongItem = _setlistProvider.getNextSongItem();
    if (nextSongItem == null) {
      Logger.methodExit(
          'SetlistNavigationService', 'getNextSongDisplayText', null);
      return null;
    }

    try {
      final nextSong = await _songRepository.getSongById(nextSongItem.songId);
      if (nextSong == null) {
        Logger.methodExit(
            'SetlistNavigationService', 'getNextSongDisplayText', null);
        return null;
      }

      // Calculate the effective key considering transpose/capo
      final effectiveKey = _calculateEffectiveKey(nextSong, nextSongItem);

      final displayText = effectiveKey.isNotEmpty
          ? 'Next: ${nextSong.title} ($effectiveKey)'
          : 'Next: ${nextSong.title}';

      Logger.methodExit(
          'SetlistNavigationService', 'getNextSongDisplayText', displayText);
      return displayText;
    } catch (e) {
      Logger.error('Error getting next song display text', e);
      Logger.methodExit(
          'SetlistNavigationService', 'getNextSongDisplayText', null);
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
