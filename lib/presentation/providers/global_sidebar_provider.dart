import 'package:flutter/material.dart';
import 'dart:async';
import '../../domain/entities/song.dart';
import '../../domain/entities/setlist.dart';
import '../../core/services/database_change_service.dart';

/// Provider for managing global sidebar visibility and navigation state across the app
/// Now includes reactive database change monitoring for automatic count updates
class GlobalSidebarProvider extends ChangeNotifier {
  bool _isSidebarVisible = true;
  AnimationController? _animationController;
  Song? _currentSong;
  String? _activeSetlistId;
  int _currentSongIndex = -1; // Index of current song in active setlist
  SetlistSongItem?
      _currentSetlistSongItem; // Current song item with setlist context

  // Phone navigation properties
  bool _isPhoneMode = false;
  VoidCallback? _onNavigateToContent;

  // Database change monitoring
  final DatabaseChangeService _dbChangeService = DatabaseChangeService();
  StreamSubscription<DbChangeEvent>? _dbChangeSubscription;
  bool _isUpdatingFromDatabase = false;

  bool get isSidebarVisible => _isSidebarVisible;
  Song? get currentSong => _currentSong;
  String? get activeSetlistId => _activeSetlistId;
  int get currentSongIndex => _currentSongIndex;
  SetlistSongItem? get currentSetlistSongItem => _currentSetlistSongItem;
  bool get isSetlistActive => _activeSetlistId != null;

  // Initialize reactive monitoring
  GlobalSidebarProvider() {
    // Listen to database change events for count updates
    _dbChangeSubscription =
        _dbChangeService.changeStream.listen(_handleDatabaseChange);
  }

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
    _activeSetlistId = null;
    _currentSongIndex = -1;
    _currentSetlistSongItem = null;
    notifyListeners();
  }

  /// Navigate to a song within an active setlist context
  void navigateToSongInSetlist(Song song, int songIndex,
      [SetlistSongItem? setlistSongItem]) {
    _currentSong = song;
    _currentSongIndex = songIndex;
    _currentSetlistSongItem = setlistSongItem;
    notifyListeners();
  }

  /// Set phone mode and navigation callback for responsive layout
  void setPhoneMode(bool isPhone, {VoidCallback? onNavigateToContent}) {
    _isPhoneMode = isPhone;
    _onNavigateToContent = onNavigateToContent;
  }

  /// Navigate to content screen (used in phone mode)
  void navigateToContent(Widget content) {
    if (_isPhoneMode && _onNavigateToContent != null) {
      _onNavigateToContent!();
    }
  }

  /// Navigate to a song with phone mode support
  void navigateToSongWithPhoneMode(Song song) {
    _currentSong = song;
    // Clear active setlist when navigating to a song outside of setlist context
    _activeSetlistId = null;
    _currentSongIndex = -1;
    _currentSetlistSongItem = null;

    if (_isPhoneMode && _onNavigateToContent != null) {
      // In phone mode, trigger navigation callback instead of just state change
      _onNavigateToContent!();
    }

    notifyListeners();
  }

  /// Handle database change events for automatic sidebar updates
  void _handleDatabaseChange(DbChangeEvent event) {
    if (_isUpdatingFromDatabase) {
      // Skip events that we triggered ourselves
      return;
    }

    debugPrint('📱 GlobalSidebarProvider received DB change: ${event.table}');

    // Update sidebar counts and navigation state
    if (event.table == 'songs_count' ||
        event.table == 'setlists_count' ||
        event.table == 'deleted_songs_count') {
      // Defer notify to avoid calling notifyListeners() during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📱 Sidebar counts updated, notifying listeners');
        notifyListeners();
      });
    }
  }

  /// Dispose of the provider and clean up resources
  @override
  void dispose() {
    _dbChangeSubscription?.cancel();
    super.dispose();
  }
}
