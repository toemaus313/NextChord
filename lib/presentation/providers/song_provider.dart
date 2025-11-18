import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/repositories/song_repository.dart';
import '../../domain/entities/song.dart';

/// Provider for managing song state and operations
/// Uses ChangeNotifier for reactive state management with Provider package
class SongProvider extends ChangeNotifier {
  final SongRepository _repository;

  SongProvider(this._repository);

  // State
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _selectionMode = false;
  final Set<String> _selectedSongIds = {};
  Timer? _searchTimer;

  // Getters
  List<Song> get songs => _filteredSongs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => _songs.isEmpty && !_isLoading;
  String get searchQuery => _searchQuery;
  bool get selectionMode => _selectionMode;
  Set<String> get selectedSongIds => Set.unmodifiable(_selectedSongIds);
  List<Song> get selectedSongs => _songs.where((song) => _selectedSongIds.contains(song.id)).toList();
  bool get isAllSelected => _filteredSongs.isNotEmpty && _selectedSongIds.length == _filteredSongs.length;
  bool get hasSelectedSongs => _selectedSongIds.isNotEmpty;

  /// Load all songs from the repository
  Future<void> loadSongs() async {
    _isLoading = true;
    _errorMessage = null;
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
        final tagMatch = song.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
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
      final id = await _repository.insertSong(song);
      await loadSongs(); // Refresh the list
      return id;
    } catch (e) {
      _errorMessage = 'Failed to add song: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing song and refresh the list
  Future<void> updateSong(Song song) async {
    try {
      await _repository.updateSong(song);
      await loadSongs(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to update song: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a song and refresh the list
  Future<void> deleteSong(String id) async {
    try {
      await _repository.deleteSong(id);
      await loadSongs(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to delete song: $e';
      notifyListeners();
      rethrow;
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

  /// Load deleted songs
  Future<void> loadDeletedSongs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _songs = await _repository.getDeletedSongs();
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

  /// Restore a deleted song
  Future<void> restoreSong(String id) async {
    try {
      await _repository.restoreSong(id);
      await loadDeletedSongs(); // Refresh the deleted list
    } catch (e) {
      _errorMessage = 'Failed to restore song: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Permanently delete a song
  Future<void> permanentlyDeleteSong(String id) async {
    try {
      await _repository.permanentlyDeleteSong(id);
      await loadDeletedSongs(); // Refresh the deleted list
    } catch (e) {
      _errorMessage = 'Failed to permanently delete song: $e';
      notifyListeners();
      rethrow;
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
    for (final song in _filteredSongs) {
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
    for (final song in songsToDelete) {
      try {
        await _repository.deleteSong(song.id);
      } catch (e) {
        _errorMessage = 'Failed to delete song "${song.title}": $e';
        notifyListeners();
        rethrow;
      }
    }
    _selectedSongIds.clear();
    await loadSongs();
  }

  /// Get all unique tags from all songs plus default tags
  Set<String> get allTags {
    final defaultTags = {
      'Pop', 'Rock', 'Country', 'Latin', 'R&B', 'Blues',
      'Classical', 'Metal', 'Punk', 'Indie', 'Alternative', 'Jazz',
      'Acoustic', 'Electric', 'Piano', 'Guitar', 'Bass', 'Drums', 'Vocals', 'Instrumental'
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
    for (final song in songsToUpdate) {
      try {
        final updatedSong = song.copyWith(
          tags: {...song.tags, ...tags}.toList(),
        );
        await _repository.updateSong(updatedSong);
      } catch (e) {
        _errorMessage = 'Failed to update song "${song.title}": $e';
        notifyListeners();
        rethrow;
      }
    }
    await loadSongs();
  }

  /// Update tags for a specific song
  Future<void> updateSongTags(String songId, List<String> newTags) async {
    try {
      final song = _songs.firstWhere((s) => s.id == songId);
      final updatedSong = song.copyWith(tags: newTags);
      await _repository.updateSong(updatedSong);
      await loadSongs();
    } catch (e) {
      _errorMessage = 'Failed to update song tags: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update/replace tags for all selected songs
  Future<void> updateTagsForSelectedSongs(List<String> newTags) async {
    final songsToUpdate = selectedSongs;
    for (final song in songsToUpdate) {
      try {
        final updatedSong = song.copyWith(tags: newTags);
        await _repository.updateSong(updatedSong);
      } catch (e) {
        _errorMessage = 'Failed to update song "${song.title}": $e';
        notifyListeners();
        rethrow;
      }
    }
    await loadSongs();
  }

  /// Remove tags from all selected songs
  Future<void> removeTagsFromSelectedSongs(List<String> tags) async {
    final songsToUpdate = selectedSongs;
    for (final song in songsToUpdate) {
      try {
        final updatedSong = song.copyWith(
          tags: song.tags.where((tag) => !tags.contains(tag)).toList(),
        );
        await _repository.updateSong(updatedSong);
      } catch (e) {
        _errorMessage = 'Failed to update song "${song.title}": $e';
        notifyListeners();
        rethrow;
      }
    }
    await loadSongs();
  }

  /// Dispose of the provider and clean up resources
  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
