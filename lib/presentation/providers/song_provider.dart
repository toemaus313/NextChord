import 'package:flutter/foundation.dart';
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

  // Getters
  List<Song> get songs => _filteredSongs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => _songs.isEmpty && !_isLoading;
  String get searchQuery => _searchQuery;

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

  /// Search songs by title or artist
  /// If query is empty, shows all songs
  void searchSongs(String query) {
    _searchQuery = query.trim();
    _applySearch();
    notifyListeners();
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
        return titleMatch || artistMatch;
      }).toList();
    }
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
}
