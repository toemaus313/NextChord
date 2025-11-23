import 'package:flutter/material.dart';

/// Controller for managing global sidebar navigation state
class GlobalSidebarController extends ChangeNotifier {
  String _currentView = 'menu';
  String? _selectedArtist;
  String? _selectedTag;
  String? _selectedSetlistId;

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

  /// Navigate to a specific view
  void navigateToView(String view,
      {String? artist, String? tag, String? setlistId}) {
    _currentView = view;
    _selectedArtist = artist;
    _selectedTag = tag;
    _selectedSetlistId = setlistId;
    notifyListeners();
  }

  /// Navigate back to menu
  void navigateToMenu() {
    _currentView = 'menu';
    _selectedArtist = null;
    _selectedTag = null;
    _selectedSetlistId = null;
    notifyListeners();
  }

  /// Navigate back to menu while preserving Songs expansion state
  void navigateToMenuKeepSongsExpanded() {
    _currentView = 'menu';
    _selectedArtist = null;
    _selectedTag = null;
    _selectedSetlistId = null;
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
