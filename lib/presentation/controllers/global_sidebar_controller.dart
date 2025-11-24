import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../providers/setlist_provider.dart';
import '../providers/song_provider.dart';

/// Controller for managing global sidebar navigation state
class GlobalSidebarController extends ChangeNotifier {
  String _currentView = 'menu';
  String? _selectedArtist;
  String? _selectedTag;
  String? _selectedSetlistId;
  SetlistProvider? _setlistProvider;
  SongProvider? _songProvider;

  // Expansion states
  bool _isSongsExpanded = false;
  bool _isSetlistsExpanded = false;
  bool _isToolsExpanded = false;
  bool _isSettingsExpanded = false;

  // Getters
  String get currentView => _currentView;
  String? get selectedArtist => _selectedArtist;
  String? get selectedTag => _selectedTag;
  String? get selectedSetlistId => _selectedSetlistId;

  bool get isSongsExpanded => _isSongsExpanded;
  bool get isSetlistsExpanded => _isSetlistsExpanded;
  bool get isToolsExpanded => _isToolsExpanded;
  bool get isSettingsExpanded => _isSettingsExpanded;

  /// Initialize with provider references
  void initialize(SetlistProvider setlistProvider, SongProvider songProvider) {
    _setlistProvider = setlistProvider;
    _songProvider = songProvider;
  }

  /// Navigate to a specific view
  void navigateToView(String view,
      {String? artist, String? tag, String? setlistId}) async {

    // Clear active setlist when navigating away from setlist view
    if (_currentView == 'setlistView' && view != 'setlistView') {
      _setlistProvider?.clearActiveSetlist();
    }

    _currentView = view;
    _selectedArtist = artist;
    _selectedTag = tag;
    _selectedSetlistId = setlistId;

    // Activate setlist when navigating to setlist view (without overriding song index)
    // The song index will be properly set by GlobalSidebarProvider.navigateToSongInSetlist
    if (view == 'setlistView' && setlistId != null) {
      // Set to 0 initially - will be updated when user clicks a song
      await _setlistProvider?.setActiveSetlist(setlistId, 0);
    }

    // Load deleted songs when navigating to deleted songs view
    if (view == 'deletedSongs') {
      await _songProvider?.loadDeletedSongs();
    }

    notifyListeners();
  }

  /// Navigate back to menu
  void navigateToMenu() {
    _currentView = 'menu';
    _selectedArtist = null;
    _selectedTag = null;
    _selectedSetlistId = null;
    _setlistProvider?.clearActiveSetlist();
    notifyListeners();
  }

  /// Navigate back to menu while preserving Songs expansion state
  void navigateToMenuKeepSongsExpanded() {
    _currentView = 'menu';
    _selectedArtist = null;
    _selectedTag = null;
    _selectedSetlistId = null;
    _setlistProvider?.clearActiveSetlist();
    // Keep Songs section expanded
    _isSongsExpanded = true;
    notifyListeners();
  }

  /// Toggle expansion states
  void toggleSongsExpanded() {
    _isSongsExpanded = !_isSongsExpanded;
    notifyListeners();
  }

  void toggleSetlistsExpanded() {
    _isSetlistsExpanded = !_isSetlistsExpanded;
    notifyListeners();
  }

  void toggleToolsExpanded() {
    _isToolsExpanded = !_isToolsExpanded;
    notifyListeners();
  }

  void toggleSettingsExpanded() {
    _isSettingsExpanded = !_isSettingsExpanded;
    notifyListeners();
  }

  /// Collapse all sections
  void collapseAll() {
    _isSongsExpanded = false;
    _isSetlistsExpanded = false;
    _isToolsExpanded = false;
    _isSettingsExpanded = false;
    notifyListeners();
  }

  /// Clear setlist state when navigating away
  void clearSetlistState() {
    _selectedSetlistId = null;
    notifyListeners();
  }

  /// Check if currently in a setlist view
  bool get isInSetlistView =>
      _currentView == 'setlistView' && _selectedSetlistId != null;
}
