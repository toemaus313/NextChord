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

  /// Helper: get only the song items from the active setlist
  List<SetlistSongItem> _getSongItemsInActiveSetlist() {
    final activeSetlist = _setlistProvider.activeSetlist;
    if (activeSetlist == null) return [];

    return activeSetlist.items.whereType<SetlistSongItem>().toList();
  }

  /// Helper: find the index of the song that is currently loaded in the viewer
  /// within the active setlist's song-only list.
  ///
  /// Priority:
  /// 1) Use GlobalSidebarProvider.currentSetlistSongItem when available.
  /// 2) Fallback to GlobalSidebarProvider.currentSong.id.
  int _getCurrentSongIndexInSetlist(List<SetlistSongItem> songItems) {
    final currentSetlistItem = _globalSidebarProvider.currentSetlistSongItem;
    if (currentSetlistItem != null) {
      final index = songItems
          .indexWhere((item) => item.songId == currentSetlistItem.songId);
      if (index != -1) {
        return index;
      }
    }

    final currentSongId = _globalSidebarProvider.currentSong?.id;
    if (currentSongId != null) {
      final index =
          songItems.indexWhere((item) => item.songId == currentSongId);
      if (index != -1) {
        return index;
      }
    }

    return -1;
  }

  /// Navigate to the next song in the setlist
  Future<Song?> navigateToNextSong() async {
    if (!_setlistProvider.isSetlistActive) {
      return null;
    }

    final songItems = _getSongItemsInActiveSetlist();
    if (songItems.isEmpty) {
      return null;
    }

    final currentIndex = _getCurrentSongIndexInSetlist(songItems);
    if (currentIndex == -1) {
      return null;
    }

    final nextIndex = currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= songItems.length) {
      return null;
    }

    final nextSongItem = songItems[nextIndex];

    try {
      // Update setlist provider index based on song-only index
      _setlistProvider.updateCurrentSongIndex(nextIndex);

      // Get the next song from repository
      final nextSong = await _songRepository.getSongById(nextSongItem.songId);
      if (nextSong == null) {
        return null;
      }

      // Update global sidebar with new song and context
      _globalSidebarProvider.navigateToSongInSetlist(
          nextSong, nextIndex, nextSongItem);

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

    final songItems = _getSongItemsInActiveSetlist();
    if (songItems.isEmpty) {
      return null;
    }

    final currentIndex = _getCurrentSongIndexInSetlist(songItems);
    if (currentIndex == -1) {
      return null;
    }

    final prevIndex = currentIndex - 1;
    if (prevIndex < 0 || prevIndex >= songItems.length) {
      return null;
    }

    final prevSongItem = songItems[prevIndex];

    try {
      // Update setlist provider index based on song-only index
      _setlistProvider.updateCurrentSongIndex(prevIndex);

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

    final songItems = _getSongItemsInActiveSetlist();
    if (songItems.isEmpty) {
      return null;
    }

    final currentIndex = _getCurrentSongIndexInSetlist(songItems);
    if (currentIndex == -1) {
      return null;
    }

    final nextIndex = currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= songItems.length) {
      return null;
    }

    final nextSongItem = songItems[nextIndex];

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
  bool get hasNextSong {
    if (!_setlistProvider.isSetlistActive) {
      return false;
    }

    final songItems = _getSongItemsInActiveSetlist();
    if (songItems.isEmpty) {
      return false;
    }

    final currentIndex = _getCurrentSongIndexInSetlist(songItems);
    if (currentIndex == -1) {
      return false;
    }

    return currentIndex + 1 < songItems.length;
  }

  /// Check if previous song is available
  bool get hasPreviousSong {
    if (!_setlistProvider.isSetlistActive) {
      return false;
    }

    final songItems = _getSongItemsInActiveSetlist();
    if (songItems.isEmpty) {
      return false;
    }

    final currentIndex = _getCurrentSongIndexInSetlist(songItems);
    if (currentIndex == -1) {
      return false;
    }

    return currentIndex - 1 >= 0;
  }
}
