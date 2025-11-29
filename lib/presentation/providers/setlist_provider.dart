import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../../domain/entities/setlist.dart';
import '../../data/repositories/setlist_repository.dart';

/// Provider for managing setlist state and operations
/// Now includes reactive database change monitoring for automatic UI updates
class SetlistProvider extends ChangeNotifier {
  final SetlistRepository _repository;

  SetlistProvider(this._repository) {
    // TEMPORARILY DISABLED: Defer stream subscription to avoid build-phase issues
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _dbChangeSubscription =
    //       _dbChangeService.changeStream.listen(_handleDatabaseChange);
    // });
  }

  // State
  List<Setlist> _setlists = [];
  bool _isLoading = false;
  String? _errorMessage;
  Setlist? _activeSetlist;
  int _currentSongIndex = -1;

  // Database change monitoring
  bool _isUpdatingFromDatabase = false;

  // Getters
  List<Setlist> get setlists => _setlists;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => _setlists.isEmpty && !_isLoading;
  Setlist? get activeSetlist => _activeSetlist;
  int get currentSongIndex => _currentSongIndex;
  bool get isSetlistActive => _activeSetlist != null && _currentSongIndex >= 0;
  SetlistRepository get repository => _repository;

  /// Load all setlists from the repository
  Future<void> loadSetlists() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final setlists = await _repository.getAllSetlists();
      _setlists = setlists;
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
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      final id = await _repository.insertSetlist(setlist);
      await loadSetlists(); // Refresh the list

      return id;
    } catch (e) {
      _errorMessage = 'Failed to add setlist: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Update an existing setlist
  Future<void> updateSetlist(Setlist setlist) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      await _repository.updateSetlist(setlist);
      await loadSetlists(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to update setlist: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  /// Delete a setlist
  Future<void> deleteSetlist(String id) async {
    try {
      _isUpdatingFromDatabase = true; // Prevent feedback loop
      await _repository.deleteSetlist(id);
      await loadSetlists(); // Refresh the list
    } catch (e) {
      _errorMessage = 'Failed to delete setlist: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isUpdatingFromDatabase = false;
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

  /// Set the active setlist and current song index
  Future<void> setActiveSetlist(String setlistId, int songIndex) async {
    try {
      final setlist = await _repository.getSetlistById(setlistId);
      if (setlist != null) {
        _activeSetlist = setlist;
        _currentSongIndex = songIndex;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to set active setlist: $e';
      notifyListeners();
    }
  }

  /// Update the current song index within the active setlist
  void updateCurrentSongIndex(int newIndex) {
    if (_activeSetlist != null &&
        newIndex >= 0 &&
        newIndex < _getSongItemsInSetlist().length) {
      _currentSongIndex = newIndex;
      notifyListeners();
    }
  }

  /// Clear the active setlist
  void clearActiveSetlist() {
    _activeSetlist = null;
    _currentSongIndex = -1;
    notifyListeners();
  }

  /// Get the current song item in the active setlist
  SetlistSongItem? getCurrentSongItem() {
    if (!isSetlistActive) return null;

    final songItems = _getSongItemsInSetlist();
    if (_currentSongIndex < songItems.length) {
      return songItems[_currentSongIndex];
    }
    return null;
  }

  /// Get the next song item in the setlist, or null if at the end
  SetlistSongItem? getNextSongItem() {
    if (!isSetlistActive) return null;

    final songItems = _getSongItemsInSetlist();
    final nextIndex = _currentSongIndex + 1;
    if (nextIndex < songItems.length) {
      return songItems[nextIndex];
    }
    return null;
  }

  /// Get the previous song item in the setlist, or null if at the start
  SetlistSongItem? getPreviousSongItem() {
    if (!isSetlistActive) return null;

    final songItems = _getSongItemsInSetlist();
    final prevIndex = _currentSongIndex - 1;
    if (prevIndex >= 0 && prevIndex < songItems.length) {
      return songItems[prevIndex];
    }
    return null;
  }

  /// Update transpose/capo settings for the current song in the setlist
  Future<void> updateCurrentSongAdjustments({
    int? transposeSteps,
    int? capo,
  }) async {
    if (!isSetlistActive || _activeSetlist == null) {
      return;
    }

    final currentSongItem = getCurrentSongItem();
    if (currentSongItem == null) {
      return;
    }

    final updatedItem = currentSongItem.copyWith(
      transposeSteps: transposeSteps,
      capo: capo,
    );

    // Update the item in the active setlist
    final updatedActiveItems = List<SetlistItem>.from(_activeSetlist!.items);
    final activeItemIndex = updatedActiveItems.indexWhere(
      (item) =>
          item is SetlistSongItem && item.songId == currentSongItem.songId,
    );

    if (activeItemIndex != -1) {
      updatedActiveItems[activeItemIndex] = updatedItem;
      final updatedActiveSetlist =
          _activeSetlist!.copyWith(items: updatedActiveItems);

      try {
        _isUpdatingFromDatabase = true; // Prevent feedback loop
        await _repository.updateSetlist(updatedActiveSetlist);
        _activeSetlist = updatedActiveSetlist;

        // Also update the item in the main setlists list for sidebar display
        final mainSetlistIndex = _setlists.indexWhere(
          (setlist) => setlist.id == _activeSetlist!.id,
        );

        if (mainSetlistIndex != -1) {
          final updatedMainItems =
              List<SetlistItem>.from(_setlists[mainSetlistIndex].items);
          final mainItemIndex = updatedMainItems.indexWhere(
            (item) =>
                item is SetlistSongItem &&
                item.songId == currentSongItem.songId,
          );

          if (mainItemIndex != -1) {
            updatedMainItems[mainItemIndex] = updatedItem;
            _setlists[mainSetlistIndex] =
                _setlists[mainSetlistIndex].copyWith(items: updatedMainItems);
          }
        }

        notifyListeners();
      } catch (e) {
        _errorMessage = 'Failed to update song adjustments: $e';
        notifyListeners();
      } finally {
        _isUpdatingFromDatabase = false;
      }
    }
  }

  /// Get only the song items from the active setlist (filters out dividers)
  List<SetlistSongItem> _getSongItemsInSetlist() {
    if (_activeSetlist == null) return [];

    return _activeSetlist!.items.whereType<SetlistSongItem>().toList();
  }

  /// Dispose of the provider and clean up resources
  @override
  void dispose() {
    super.dispose();
  }
}
