import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/song_viewer_constants.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/setlist.dart';
import '../../services/song_adjustment_service.dart';
import '../../core/services/database_change_service.dart';

/// Enum for different flyout types
enum FlyoutType {
  settings,
  transpose,
  capo,
  autoscroll,
}

/// Lightweight metadata describing how chords should be adjusted in the viewer
class ViewerAdjustmentMetadata {
  final int transposeSteps;
  final int capo;
  final bool appliesToSetlist;

  const ViewerAdjustmentMetadata({
    required this.transposeSteps,
    required this.capo,
    required this.appliesToSetlist,
  });

  ViewerAdjustmentMetadata copyWith({
    int? transposeSteps,
    int? capo,
    bool? appliesToSetlist,
  }) {
    return ViewerAdjustmentMetadata(
      transposeSteps: transposeSteps ?? this.transposeSteps,
      capo: capo ?? this.capo,
      appliesToSetlist: appliesToSetlist ?? this.appliesToSetlist,
    );
  }
}

/// State management provider for the Song Viewer screen
/// Now includes reactive database change monitoring for automatic song updates
class SongViewerProvider extends ChangeNotifier {
  Song _currentSong;
  double _fontSize;
  int _transposeSteps;
  int _currentCapo;
  final SetlistSongItem? _setlistContext;

  // Flyout visibility states
  bool _showSettingsFlyout = false;
  bool _showTransposeFlyout = false;
  bool _showCapoFlyout = false;
  bool _showAutoscrollFlyout = false;

  late ViewerAdjustmentMetadata _viewerAdjustments;

  // Database change monitoring
  final DatabaseChangeService _dbChangeService = DatabaseChangeService();
  StreamSubscription<DbChangeEvent>? _dbChangeSubscription;
  bool _isUpdatingFromDatabase = false;

  SongViewerProvider({
    required Song song,
    SetlistSongItem? setlistContext,
  })  : _currentSong = song,
        _setlistContext = setlistContext,
        _fontSize = SongViewerConstants.defaultFontSize,
        _transposeSteps = setlistContext?.transposeSteps ?? 0,
        _currentCapo = setlistContext?.capo ?? song.capo {
    _initializeViewerAdjustments();

    // Listen to database change events for automatic song updates
    _dbChangeSubscription =
        _dbChangeService.changeStream.listen(_handleDatabaseChange);
  }

  // Getters
  Song get currentSong => _currentSong;
  double get fontSize => _fontSize;
  int get transposeSteps => _transposeSteps;
  int get currentCapo => _currentCapo;
  SetlistSongItem? get setlistContext => _setlistContext;
  bool get hasSetlistContext => _setlistContext != null;

  bool get showSettingsFlyout => _showSettingsFlyout;
  bool get showTransposeFlyout => _showTransposeFlyout;
  bool get showCapoFlyout => _showCapoFlyout;
  bool get showAutoscrollFlyout => _showAutoscrollFlyout;

  ViewerAdjustmentMetadata get viewerAdjustments => _viewerAdjustments;

  // Computed properties
  int get capoOffsetFromSong => _currentSong.capo - _currentCapo;
  int get effectiveTransposeSteps => _transposeSteps + capoOffsetFromSong;

  String get transposeStatusLabel =>
      SongAdjustmentService.formatTransposeLabel(effectiveTransposeSteps);
  String get capoStatusLabel =>
      SongAdjustmentService.formatCapoLabel(_currentCapo, _currentSong.capo);

  String? get keyDisplayLabel => SongAdjustmentService.getKeyDisplayLabel(
      _currentSong.key, effectiveTransposeSteps);

  // Update methods
  void updateSong(Song newSong) {
    _currentSong = newSong;
    _transposeSteps = _setlistContext?.transposeSteps ?? 0;
    _currentCapo = _setlistContext?.capo ?? newSong.capo;
    _initializeViewerAdjustments();

    notifyListeners();
  }

  /// Update only song content without changing UI state (transpose, capo, font size, etc.)
  /// Used for reactive database updates to preserve user experience
  void updateSongContentOnly(Song newSong) {
    if (_isUpdatingFromDatabase) {
      // Skip events that we triggered ourselves
      return;
    }

    debugPrint(
        '🎵 SongViewerProvider updating song content only: ${newSong.title}');

    // Only update the song data, preserve all UI state
    _currentSong = newSong;

    // Don't reset transpose/capo/font size/flyout states
    // Don't call _initializeViewerAdjustments() as it would reset state

    notifyListeners();
  }

  /// Handle database change events for automatic song updates
  void _handleDatabaseChange(DbChangeEvent event) {
    if (_isUpdatingFromDatabase) {
      // Skip events that we triggered ourselves
      return;
    }

    debugPrint('🎵 SongViewerProvider received DB change: ${event.table}');

    // Only react to song changes, and only if they affect the current song
    if (event.table == 'songs' && event.recordId == _currentSong.id) {
      // Defer refresh to avoid calling notifyListeners() during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshCurrentSongFromDatabase();
      });
    }
  }

  /// Refresh the current song from database without disrupting UI state
  Future<void> _refreshCurrentSongFromDatabase() async {
    if (_isUpdatingFromDatabase) return;

    debugPrint('🎵 SongViewerProvider refreshing current song from database');

    try {
      _isUpdatingFromDatabase = true;

      // This would need to be implemented to fetch the updated song
      // For now, we'll emit a notification that the song should be refreshed
      // The actual song fetching will be handled by the parent widget
      // that has access to the song repository

      // We could add a callback mechanism for the parent to handle this
      debugPrint(
          '🎵 Song content change detected for current song: ${_currentSong.title}');

      // For now, just notify listeners that something changed
      // The UI layer can handle the actual song refresh
      notifyListeners();
    } catch (e) {
      debugPrint('🎵 Error refreshing current song from database: $e');
    } finally {
      _isUpdatingFromDatabase = false;
    }
  }

  void updateFontSize(double newFontSize) {
    final clampedSize = SongAdjustmentService.clampFontSize(newFontSize);
    if (clampedSize != _fontSize) {
      _fontSize = clampedSize;
      notifyListeners();
    }
  }

  void updateTranspose(int delta) {
    final newValue =
        SongAdjustmentService.clampTranspose(_transposeSteps + delta);
    if (newValue != _transposeSteps) {
      _transposeSteps = newValue;
      _viewerAdjustments =
          _viewerAdjustments.copyWith(transposeSteps: newValue);
      notifyListeners();
    }
  }

  void updateCapo(int delta) {
    final newValue = SongAdjustmentService.clampCapo(_currentCapo + delta);
    if (newValue != _currentCapo) {
      _currentCapo = newValue;
      _viewerAdjustments = _viewerAdjustments.copyWith(capo: newValue);
      notifyListeners();
    }
  }

  void setTranspose(int value) {
    final clampedValue = SongAdjustmentService.clampTranspose(value);
    if (clampedValue != _transposeSteps) {
      _transposeSteps = clampedValue;
      _viewerAdjustments =
          _viewerAdjustments.copyWith(transposeSteps: clampedValue);
      notifyListeners();
    }
  }

  void setCapo(int value) {
    final clampedValue = SongAdjustmentService.clampCapo(value);
    if (clampedValue != _currentCapo) {
      _currentCapo = clampedValue;
      _viewerAdjustments = _viewerAdjustments.copyWith(capo: clampedValue);
      notifyListeners();
    }
  }

  // Flyout management
  void toggleFlyout(FlyoutType type) {
    // Close all flyouts first
    _closeAllFlyouts();

    // Toggle the requested flyout
    switch (type) {
      case FlyoutType.settings:
        _showSettingsFlyout = !_showSettingsFlyout;
        break;
      case FlyoutType.transpose:
        _showTransposeFlyout = !_showTransposeFlyout;
        break;
      case FlyoutType.capo:
        _showCapoFlyout = !_showCapoFlyout;
        break;
      case FlyoutType.autoscroll:
        _showAutoscrollFlyout = !_showAutoscrollFlyout;
        break;
    }
    notifyListeners();
  }

  void openFlyout(FlyoutType type) {
    _closeAllFlyouts();

    switch (type) {
      case FlyoutType.settings:
        _showSettingsFlyout = true;
        break;
      case FlyoutType.transpose:
        _showTransposeFlyout = true;
        break;
      case FlyoutType.capo:
        _showCapoFlyout = true;
        break;
      case FlyoutType.autoscroll:
        _showAutoscrollFlyout = true;
        break;
    }

    notifyListeners();
  }

  void closeFlyout(FlyoutType type) {
    switch (type) {
      case FlyoutType.settings:
        _showSettingsFlyout = false;
        break;
      case FlyoutType.transpose:
        _showTransposeFlyout = false;
        break;
      case FlyoutType.capo:
        _showCapoFlyout = false;
        break;
      case FlyoutType.autoscroll:
        _showAutoscrollFlyout = false;
        break;
    }

    notifyListeners();
  }

  void closeAllFlyouts() {
    _closeAllFlyouts();
    notifyListeners();
  }

  void _closeAllFlyouts() {
    _showSettingsFlyout = false;
    _showTransposeFlyout = false;
    _showCapoFlyout = false;
    _showAutoscrollFlyout = false;
  }

  void _initializeViewerAdjustments() {
    _viewerAdjustments = ViewerAdjustmentMetadata(
      transposeSteps: _transposeSteps,
      capo: _currentCapo,
      appliesToSetlist: _setlistContext != null,
    );
  }

  // Utility methods
  bool canIncrementTranspose() =>
      _transposeSteps < SongViewerConstants.maxTranspose;
  bool canDecrementTranspose() =>
      _transposeSteps > SongViewerConstants.minTranspose;
  bool canIncrementCapo() => _currentCapo < SongViewerConstants.maxCapo;
  bool canDecrementCapo() => _currentCapo > SongViewerConstants.minCapo;

  String formatSignedValue(int value) =>
      SongAdjustmentService.formatSignedValue(value);

  /// Dispose of the provider and clean up resources
  @override
  void dispose() {
    _dbChangeSubscription?.cancel();
    super.dispose();
  }
}
