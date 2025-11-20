import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/song.dart';

/// Provider for managing global sidebar visibility and navigation state across the app
class GlobalSidebarProvider extends ChangeNotifier {
  bool _isSidebarVisible = true;
  AnimationController? _animationController;
  Song? _currentSong;
  String? _activeSetlistId;
  int _currentSongIndex = -1; // Index of current song in active setlist
  SetlistSongItem?
      _currentSetlistSongItem; // Current song item with setlist context

  bool get isSidebarVisible => _isSidebarVisible;
  Song? get currentSong => _currentSong;
  String? get activeSetlistId => _activeSetlistId;
  int get currentSongIndex => _currentSongIndex;
  SetlistSongItem? get currentSetlistSongItem => _currentSetlistSongItem;
  bool get isSetlistActive => _activeSetlistId != null;

  /// Initialize the animation controller
  void initializeAnimation(AnimationController controller) {
    _animationController = controller;
  }

  /// Toggle sidebar visibility
  void toggleSidebar() {
    if (_isSidebarVisible) {
      hideSidebar();
    } else {
      showSidebar();
    }
  }

  /// Show the sidebar with animation
  void showSidebar() {
    if (!_isSidebarVisible && _animationController != null) {
      _isSidebarVisible = true;
      _animationController!.forward();
      notifyListeners();
    }
  }

  /// Hide the sidebar with animation
  void hideSidebar() {
    if (_isSidebarVisible && _animationController != null) {
      _isSidebarVisible = false;
      _animationController!.reverse();
      notifyListeners();
    }
  }

  /// Navigate to a song (show it in the main content area)
  void navigateToSong(Song song) {
    debugPrint(
        '🎵 GlobalSidebarProvider: navigateToSong called - clearing setlist state');
    _currentSong = song;
    // Clear active setlist when navigating to a song outside of setlist context
    _activeSetlistId = null;
    _currentSongIndex = -1;
    _currentSetlistSongItem = null;
    notifyListeners();
  }

  /// Clear the current song and return to welcome screen
  void clearCurrentSong() {
    _currentSong = null;
    _currentSongIndex = -1;
    _currentSetlistSongItem = null;
    notifyListeners();
  }

  /// Set the active setlist and current song index
  void setActiveSetlist(String setlistId, int songIndex) {
    _activeSetlistId = setlistId;
    _currentSongIndex = songIndex;
    notifyListeners();
  }

  /// Update the current song index within the active setlist
  void updateCurrentSongIndex(int newIndex) {
    _currentSongIndex = newIndex;
    notifyListeners();
  }

  /// Clear the active setlist (when user exits setlist view)
  void clearActiveSetlist() {
    debugPrint('🎵 GlobalSidebarProvider: clearActiveSetlist called');
    _activeSetlistId = null;
    _currentSongIndex = -1;
    _currentSetlistSongItem = null;
    notifyListeners();
  }

  /// Navigate to a song within an active setlist context
  void navigateToSongInSetlist(Song song, int songIndex,
      [SetlistSongItem? setlistSongItem]) {
    debugPrint('🎵 GlobalSidebarProvider: navigateToSongInSetlist called');
    _currentSong = song;
    _currentSongIndex = songIndex;
    _currentSetlistSongItem = setlistSongItem;
    notifyListeners();
  }
}
