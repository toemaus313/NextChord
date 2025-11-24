import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../../data/repositories/song_repository.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/midi_mapping.dart';
import '../../core/services/database_change_service.dart';

/// Enum to track what type of song list is currently loaded
enum SongListType { all, deleted, filtered }

/// Provider for managing song state and operations
/// Uses ChangeNotifier for reactive state management with Provider package
/// Now includes reactive database change monitoring for automatic UI updates
class SongProvider extends ChangeNotifier {
  final SongRepository _repository;
  final DatabaseChangeService _dbChangeService = DatabaseChangeService();

  SongProvider(this._repository) {
    // TEMPORARILY DISABLED: Defer stream subscription to avoid build-phase issues
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _dbChangeSubscription =
    //       _dbChangeService.changeStream.listen(_handleDatabaseChange);
    // });
    debugPrint(
        '🎵 SongProvider: Database change monitoring temporarily disabled for debugging');
  }

  // Public getter for repository access
  SongRepository get repository => _repository;

  // State
  List<Song> _songs = [];
  List<Song> _deletedSongs = []; // Separate list for deleted songs
  List<Song> _filteredSongs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _selectionMode = false;
  final Set<String> _selectedSongIds = {};
  Timer? _searchTimer;
  SongListType _currentListType = SongListType.all;

  // Database change monitoring
  StreamSubscription<DbChangeEvent>? _dbChangeSubscription;
  bool _isUpdatingFromDatabase = false;

  // Getters
  List<Song> get songs => _filteredSongs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => _songs.isEmpty && !_isLoading;
  String get searchQuery => _searchQuery;
  bool get selectionMode => _selectionMode;
  SongListType get currentListType => _currentListType;
  Set<String> get selectedSongIds => Set.unmodifiable(_selectedSongIds);
  List<Song> get selectedSongs {
    if (_currentListType == SongListType.deleted) {
      return _deletedSongs
          .where((song) => _selectedSongIds.contains(song.id))
          .toList();
    } else {
      return _songs
          .where((song) => _selectedSongIds.contains(song.id))
          .toList();
    }
  }

  bool get isAllSelected {
    final currentList = _currentListType == SongListType.deleted
        ? _deletedSongs
        : _filteredSongs;
    return currentList.isNotEmpty &&
        _selectedSongIds.length == currentList.length;
  }

  bool get hasSelectedSongs => _selectedSongIds.isNotEmpty;

  /// Get deleted songs for the sidebar view
  List<Song> get deletedSongs => _deletedSongs;

  /// Clear selection (alias for deselectAll)
  void clearSelection() => deselectAll();

  /// Select specific song
  void selectSong(Song song) => toggleSongSelection(song.id);

  /// Deselect specific song
  void deselectSong(Song song) {
    if (_selectedSongIds.contains(song.id)) {
      _selectedSongIds.remove(song.id);
      notifyListeners();
    }
  }

  /// Select all deleted songs
  void selectAllSongs(List<Song> songs) {
    _selectedSongIds.clear();
    for (final song in songs) {
      _selectedSongIds.add(song.id);
    }
    notifyListeners();
  }

  /// Bulk restore deleted songs
  Future<void> bulkRestoreSongs() async {
    final songsToRestore = selectedSongs;
    for (final song in songsToRestore) {
      await restoreSong(song.id);
    }
    resetSelectionMode();
  }

  /// Bulk permanently delete songs
  Future<void> bulkPermanentlyDeleteSongs() async {
    final songsToDelete = selectedSongs;
    for (final song in songsToDelete) {
      await permanentlyDeleteSong(song.id);
    }
    resetSelectionMode();
  }

  /// Load all songs from the repository
  Future<void> loadSongs() async {
    debugPrint(
        '🎵 SongProvider.loadSongs() called - checking if in build phase');
    _isLoading = true;
    _errorMessage = null;
    debugPrint('🎵 About to call notifyListeners() in loadSongs()');
    notifyListeners();
    debugPrint('🎵 notifyListeners() completed in loadSongs()');
    _currentListType = SongListType.all;
    notifyListeners();

    try {
      _songs = await _repository.getAllSongs();
      _applySearch();
      _errorMessage = null;
    } on SongRepositoryException catch (e) {
      _errorMessage = e.message;
      _songs = [];
      _filteredSongs = [];
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      _songs = [];
      _filteredSongs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handle database change events for automatic updates
  void _handleDatabaseChange(DbChangeEvent event) {
    if (_isUpdatingFromDatabase) {
      // Skip events that we triggered ourselves
      return;
    }

    debugPrint('🎵 SongProvider received DB change: ${event.table}');

    // Only refresh if we're currently showing songs or deleted songs
    if (event.table == 'songs' ||
        event.table == 'songs_count' ||
        event.table == 'deleted_songs_count') {
      // Defer refresh to avoid calling notifyListeners() during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshFromDatabaseChange();
      });
    }
  }

  /// Refresh data from database change event without disrupting UI state
  Future<void> _refreshFromDatabaseChange() async {
    if (_isLoading) return; // Don't refresh if already loading

    debugPrint('🎵 SongProvider refreshing from database change');

    try {
      _isUpdatingFromDatabase = true;

      // Preserve current list type and refresh accordingly
      switch (_currentListType) {
        case SongListType.all:
          await _refreshSongsList();
          break;
        case SongListType.deleted:
          await _refreshDeletedSongsList();
          break;
        case SongListType.filtered:
          await _refreshSongsList();
          break;
      }
    } catch (e) {
      debugPrint('🎵 Error refreshing from database change: $e');
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Refresh songs list without changing loading state
  Future<void> _refreshSongsList() async {
    try {
      final newSongs = await _repository.getAllSongs();
      _songs = newSongs;
      _applySearch(); // Reapply current search/filter
      notifyListeners();
    } catch (e) {
      debugPrint('🎵 Error refreshing songs list: $e');
    }
  }

  /// Refresh deleted songs list without changing loading state
  Future<void> _refreshDeletedSongsList() async {
    try {
      final newDeletedSongs = await _repository.getDeletedSongs();
      _deletedSongs = newDeletedSongs;
      notifyListeners();
    } catch (e) {
      debugPrint('🎵 Error refreshing deleted songs list: $e');
    }
  }

  /// Search songs by title or artist with debouncing
  /// If query is empty, shows all songs
  void searchSongs(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = query.trim();
      _applySearch();
      notifyListeners();
    });
  }

  /// Apply current search query to filter songs
  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredSongs = List.from(_songs);
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      _filteredSongs = _songs.where((song) {
        final titleMatch = song.title.toLowerCase().contains(lowerQuery);
        final artistMatch = song.artist.toLowerCase().contains(lowerQuery);
        final tagMatch =
            song.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        return titleMatch || artistMatch || tagMatch;
      }).toList();
    }
  }

  /// Clear search query and show all songs
  void clearSearch() {
    _searchQuery = '';
    _filteredSongs = List.from(_songs);
    // Preserve selections when clearing search
    notifyListeners();
  }

  /// Filter songs by artist
  void filterByArtist(String artist) {
    _filteredSongs = _songs.where((song) => song.artist == artist).toList();
    notifyListeners();
  }

  /// Filter songs by tag
  void filterByTag(String tag) {
    _filteredSongs = _songs.where((song) => song.tags.contains(tag)).toList();
    notifyListeners();
  }

  /// Clear any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh songs (reload from repository)
  Future<void> refresh() async {
    await loadSongs();
  }

  /// Add a new song and refresh the list
  Future<String> addSong(Song song) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      final id = await _repository.insertSong(song);
      await loadSongs(); // Refresh the list

      return id;
    } catch (e) {
      _errorMessage = 'Failed to add song: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Update an existing song and refresh the list
  Future<void> updateSong(Song song) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      await _repository.updateSong(song);
      await loadSongs(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to update song: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Delete a song and refresh the list
  Future<void> deleteSong(String id, {VoidCallback? onDeleted}) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      await _repository.deleteSong(id);
      await loadSongs(); // Refresh the list
      onDeleted?.call(); // Notify that song was deleted
    } catch (e) {
      _errorMessage = 'Failed to delete song: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Get a single song by ID
  Future<Song?> getSongById(String id) async {
    try {
      return await _repository.getSongById(id);
    } catch (e) {
      _errorMessage = 'Failed to fetch song: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get deleted songs count without affecting current songs state
  Future<int> getDeletedSongsCount() async {
    try {
      final deletedSongs = await _repository.getDeletedSongs();
      debugPrint(
          '🎵 getDeletedSongsCount: Found ${deletedSongs.length} deleted songs');
      return deletedSongs.length;
    } catch (e) {
      debugPrint('🎵 getDeletedSongsCount error: $e');
      return 0;
    }
  }

  /// Load deleted songs
  Future<void> loadDeletedSongs() async {
    try {
      _deletedSongs = await _repository.getDeletedSongs();
      debugPrint(
          '🎵 loadDeletedSongs: Loaded ${_deletedSongs.length} deleted songs');
      _currentListType = SongListType.deleted;
      notifyListeners();
    } catch (e) {
      debugPrint('🎵 loadDeletedSongs error: $e');
      _errorMessage = 'Failed to load deleted songs: $e';
      notifyListeners();
    }
  }

  /// Restore a deleted song
  Future<void> restoreSong(String id) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      await _repository.restoreSong(id);
      await loadDeletedSongs(); // Refresh the deleted list
      await loadSongs(); // Refresh the main songs list so restored song appears
    } catch (e) {
      _errorMessage = 'Failed to restore song: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Permanently delete a song
  Future<void> permanentlyDeleteSong(String id) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      await _repository.permanentlyDeleteSong(id);
      await loadDeletedSongs(); // Refresh the deleted list
    } catch (e) {
      _errorMessage = 'Failed to permanently delete song: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Toggle selection mode on/off
  void toggleSelectionMode() {
    _selectionMode = !_selectionMode;
    if (!_selectionMode) {
      _selectedSongIds.clear();
    }
    notifyListeners();
  }

  /// Force selection mode off and clear selections
  void resetSelectionMode() {
    if (_selectionMode || _selectedSongIds.isNotEmpty) {
      _selectionMode = false;
      _selectedSongIds.clear();
      notifyListeners();
    }
  }

  /// Toggle selection of a specific song
  void toggleSongSelection(String songId) {
    if (_selectedSongIds.contains(songId)) {
      _selectedSongIds.remove(songId);
    } else {
      _selectedSongIds.add(songId);
    }
    notifyListeners();
  }

  /// Select all songs in the current filtered list
  void selectAll() {
    _selectedSongIds.clear();
    final currentList = _currentListType == SongListType.deleted
        ? _deletedSongs
        : _filteredSongs;
    for (final song in currentList) {
      _selectedSongIds.add(song.id);
    }
    notifyListeners();
  }

  /// Deselect all songs
  void deselectAll() {
    _selectedSongIds.clear();
    notifyListeners();
  }

  /// Toggle select all/deselect all
  void toggleSelectAll() {
    if (isAllSelected) {
      deselectAll();
    } else {
      selectAll();
    }
  }

  /// Delete all selected songs
  Future<void> deleteSelectedSongs() async {
    final songsToDelete = selectedSongs;
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      for (final song in songsToDelete) {
        await _repository.deleteSong(song.id);
      }
      _selectedSongIds.clear();
      await loadSongs();
    } catch (e) {
      _errorMessage =
          'Failed to delete song "${songsToDelete.first.title}": $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Get all unique tags from all songs plus default tags
  Set<String> get allTags {
    final defaultTags = {
      'Pop',
      'Rock',
      'Country',
      'Latin',
      'R&B',
      'Blues',
      'Classical',
      'Metal',
      'Punk',
      'Indie',
      'Alternative',
      'Jazz',
      'Acoustic',
      'Electric',
      'Piano',
      'Guitar',
      'Bass',
      'Drums',
      'Vocals',
      'Instrumental'
    };
    final allTags = <String>{};
    allTags.addAll(defaultTags);
    for (final song in _songs) {
      allTags.addAll(song.tags);
    }
    return allTags;
  }

  /// Add tags to all selected songs
  Future<void> addTagsToSelectedSongs(List<String> tags) async {
    final songsToUpdate = selectedSongs;
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      for (final song in songsToUpdate) {
        final updatedTags = Set<String>.from(song.tags)..addAll(tags);
        final updatedSong = song.copyWith(
          tags: updatedTags.toList(),
        );
        await _repository.updateSong(updatedSong);
      }
      await loadSongs();
    } catch (e) {
      _errorMessage =
          'Failed to update song "${songsToUpdate.first.title}": $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Update tags for a specific song
  Future<void> updateSongTags(String songId, List<String> newTags) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      final song = _songs.firstWhere((s) => s.id == songId);
      final updatedSong = song.copyWith(tags: newTags);
      await _repository.updateSong(updatedSong);
      await loadSongs();
    } catch (e) {
      _errorMessage = 'Failed to update song tags: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Update/replace tags for all selected songs
  Future<void> updateTagsForSelectedSongs(List<String> newTags) async {
    final songsToUpdate = selectedSongs;
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      for (final song in songsToUpdate) {
        final updatedSong = song.copyWith(tags: newTags);
        await _repository.updateSong(updatedSong);
      }
      await loadSongs();
    } catch (e) {
      _errorMessage =
          'Failed to update song "${songsToUpdate.first.title}": $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Remove tags from all selected songs
  Future<void> removeTagsFromSelectedSongs(List<String> tags) async {
    final songsToUpdate = selectedSongs;
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      for (final song in songsToUpdate) {
        final updatedSong = song.copyWith(
          tags: song.tags.where((tag) => !tags.contains(tag)).toList(),
        );
        await _repository.updateSong(updatedSong);
      }
      await loadSongs();
    } catch (e) {
      _errorMessage =
          'Failed to update song "${songsToUpdate.first.title}": $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Save or update a MIDI mapping for a song
  Future<void> saveMidiMapping(MidiMapping midiMapping) async {
    try {
      await _repository.saveMidiMapping(midiMapping);
    } catch (e) {
      _errorMessage = 'Failed to save MIDI mapping: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Dispose of the provider and clean up resources
  @override
  void dispose() {
    _searchTimer?.cancel();
    _dbChangeSubscription?.cancel();
    super.dispose();
  }
}
