import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/song.dart';

/// Provider for managing global sidebar visibility and navigation state across the app
class GlobalSidebarProvider extends ChangeNotifier {
  bool _isSidebarVisible = true;
  AnimationController? _animationController;
  Song? _currentSong;

  bool get isSidebarVisible => _isSidebarVisible;
  Song? get currentSong => _currentSong;

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
    _currentSong = song;
    notifyListeners();
  }

  /// Clear the current song and return to welcome screen
  void clearCurrentSong() {
    _currentSong = null;
    notifyListeners();
  }
}
