import 'package:flutter/foundation.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/setlist_repository.dart';

/// Provider for managing setlist state and operations
class SetlistProvider extends ChangeNotifier {
  final SetlistRepository _repository;

  SetlistProvider(this._repository);

  // State
  List<Setlist> _setlists = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Setlist> get setlists => _setlists;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => _setlists.isEmpty && !_isLoading;

  /// Load all setlists from the repository
  Future<void> loadSetlists() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _setlists = await _repository.getAllSetlists();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load setlists: $e';
      _setlists = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a single setlist by ID
  Future<Setlist?> getSetlistById(String id) async {
    try {
      return await _repository.getSetlistById(id);
    } catch (e) {
      _errorMessage = 'Failed to fetch setlist: $e';
      notifyListeners();
      return null;
    }
  }

  /// Add a new setlist
  Future<String> addSetlist(Setlist setlist) async {
    try {
      final id = await _repository.insertSetlist(setlist);
      await loadSetlists(); // Refresh the list
      return id;
    } catch (e) {
      _errorMessage = 'Failed to add setlist: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing setlist
  Future<void> updateSetlist(Setlist setlist) async {
    try {
      await _repository.updateSetlist(setlist);
      await loadSetlists(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to update setlist: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a setlist
  Future<void> deleteSetlist(String id) async {
    try {
      await _repository.deleteSetlist(id);
      await loadSetlists(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to delete setlist: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Clear any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh setlists (reload from repository)
  Future<void> refresh() async {
    await loadSetlists();
  }
}
