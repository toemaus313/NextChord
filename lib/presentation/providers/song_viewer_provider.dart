import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/database_change_service.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/setlist.dart';
import '../../services/song_adjustment_service.dart';
import '../../main.dart' as app_main;
import 'setlist_provider.dart';

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
  SetlistSongItem? _setlistContext;
  final SetlistProvider? _setlistProvider;

  // Flyout visibility states
  bool _showSettingsFlyout = false;
  bool _showTransposeFlyout = false;
  bool _showCapoFlyout = false;
  bool _showAutoscrollFlyout = false;

  late ViewerAdjustmentMetadata _viewerAdjustments;

  // Database change monitoring
  final DatabaseChangeService _dbChangeService = DatabaseChangeService();
  final SongRepository _songRepository;
  StreamSubscription<DbChangeEvent>? _dbChangeSubscription;
  bool _isUpdatingFromDatabase = false;

  SongViewerProvider({
    required Song song,
    required SongRepository songRepository,
    SetlistSongItem? setlistContext,
    SetlistProvider? setlistProvider,
  })  : _currentSong = song,
        _songRepository = songRepository,
        _setlistProvider = setlistProvider,
        _fontSize = SongViewerConstants.defaultFontSize,
        _transposeSteps = 0,
        _currentCapo = 0 {
    // Lazy inference: if setlistContext is not provided but we have a setlistProvider,
    // try to infer the context from the active setlist
    if (setlistContext != null) {
      _setlistContext = setlistContext;
    } else if (setlistProvider != null && setlistProvider.isSetlistActive) {
      // Try to get the current song item from the active setlist
      final currentSongItem = setlistProvider.getCurrentSongItem();
      // Only use it if it matches the current song
      if (currentSongItem != null && currentSongItem.songId == song.id) {
        _setlistContext = currentSongItem;
        app_main.myDebug(
          'SongViewerProvider: inferred setlistContext for song ${song.id} from SetlistProvider',
        );
      } else {
        _setlistContext = null;
      }
    } else {
      _setlistContext = null;
    }

    // Now set the actual values based on the inferred context
    _transposeSteps = _setlistContext?.transposeSteps ?? 0;
    _currentCapo = _setlistContext?.capo ?? song.capo;
    _initializeViewerAdjustments();

    // Set up stream subscription immediately to catch events during initial sync
    // Build-phase protection is handled within _handleDatabaseChange via postFrameCallback
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

    // Apply lazy inference when updating song as well
    SetlistSongItem? inferredContext;
    if (_setlistContext != null) {
      inferredContext = _setlistContext;
    } else if (_setlistProvider != null && _setlistProvider!.isSetlistActive) {
      // Try to get the current song item from the active setlist
      final currentSongItem = _setlistProvider!.getCurrentSongItem();
      // Only use it if it matches the current song
      if (currentSongItem != null && currentSongItem.songId == newSong.id) {
        inferredContext = currentSongItem;
        app_main.myDebug(
          'SongViewerProvider: inferred setlistContext for updated song ${newSong.id} from SetlistProvider',
        );
      }
    }

    _transposeSteps = inferredContext?.transposeSteps ?? 0;
    _currentCapo = inferredContext?.capo ?? newSong.capo;
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

    // Only react to song changes, and only if they affect the current song
    if (event.table == 'songs') {
      if (event.recordId == _currentSong.id) {
        // Defer refresh to avoid calling notifyListeners() during build phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshCurrentSongFromDatabase();
        });
      } else {}
    }
  }

  /// Refresh the current song from database without disrupting UI state
  Future<void> _refreshCurrentSongFromDatabase() async {
    if (_isUpdatingFromDatabase) return;

    try {
      _isUpdatingFromDatabase = true;

      // Fetch the updated song from database
      final updatedSong = await _songRepository.getSongById(_currentSong.id);

      if (updatedSong != null) {
        // Update only the song content, preserve all UI state (transpose, capo, font size, etc.)
        _currentSong = updatedSong;

        // Don't reset transpose/capo/font size/flyout states
        // Don't call _initializeViewerAdjustments() as it would reset state

        notifyListeners();
      } else {}
    } catch (e) {
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
      _persistAdjustments(transposeSteps: newValue);
    }
  }

  void updateCapo(int delta) {
    final newValue = SongAdjustmentService.clampCapo(_currentCapo + delta);
    if (newValue != _currentCapo) {
      _currentCapo = newValue;
      _viewerAdjustments = _viewerAdjustments.copyWith(capo: newValue);
      notifyListeners();
      _persistAdjustments(capo: newValue);
    }
  }

  void setTranspose(int value) {
    final clampedValue = SongAdjustmentService.clampTranspose(value);
    if (clampedValue != _transposeSteps) {
      _transposeSteps = clampedValue;
      _viewerAdjustments =
          _viewerAdjustments.copyWith(transposeSteps: clampedValue);
      notifyListeners();
      _persistAdjustments(transposeSteps: clampedValue);
    }
  }

  void setCapo(int value) {
    final clampedValue = SongAdjustmentService.clampCapo(value);
    if (clampedValue != _currentCapo) {
      _currentCapo = clampedValue;
      _viewerAdjustments = _viewerAdjustments.copyWith(capo: clampedValue);
      notifyListeners();
      _persistAdjustments(capo: clampedValue);
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

  Future<void> _persistAdjustments({int? transposeSteps, int? capo}) async {
    final targetTranspose = transposeSteps ?? _transposeSteps;
    final targetCapo = capo ?? _currentCapo;
    final setlistProvider = _setlistProvider;

    app_main.myDebug(
        'SongViewerProvider: _persistAdjustments called - song=${_currentSong.id}, targetCapo=$targetCapo, _setlistContext=${_setlistContext != null ? "present" : "null"}, isSetlistActive=${setlistProvider?.isSetlistActive ?? false}');

    // Prioritize using the inferred setlistContext if available
    if (_setlistContext != null && setlistProvider?.isSetlistActive == true) {
      await setlistProvider!.updateCurrentSongAdjustments(
        transposeSteps: targetTranspose,
        capo: targetCapo,
      );
      app_main.myDebug(
        'SongViewerProvider: saved setlist-only adjustments for song ${_currentSong.id} using inferred context (transpose=$targetTranspose, capo=$targetCapo)',
      );
      return;
    }

    // Fallback to checking getCurrentSongItem() if no inferred context
    if ((setlistProvider?.isSetlistActive ?? false) &&
        setlistProvider?.getCurrentSongItem() != null) {
      await setlistProvider!.updateCurrentSongAdjustments(
        transposeSteps: targetTranspose,
        capo: targetCapo,
      );
      app_main.myDebug(
        'SongViewerProvider: saved setlist-only adjustments for song ${_currentSong.id} using getCurrentSongItem() (transpose=$targetTranspose, capo=$targetCapo)',
      );
      return;
    }

    // Save to global song if no setlist context available
    app_main.myDebug(
        'SongViewerProvider: saving to global song - no setlist context available');
    final updatedSong = _currentSong.copyWith(
      capo: targetCapo,
      // Base song transpose is represented by storing the transposeSteps on the song body.
      // Add a 'viewer_transpose' metadata field to preserve UI adjustments outside setlists.
      notes: _mergeTransposeIntoNotes(_currentSong.notes, transposeSteps),
    );
    await _songRepository.updateSong(updatedSong);
    _currentSong = updatedSong;
    app_main.myDebug(
      'SongViewerProvider: saved global song adjustments for song ${_currentSong.id} (transpose=$targetTranspose, capo=$targetCapo)',
    );
  }

  String? _mergeTransposeIntoNotes(String? originalNotes, int? transposeSteps) {
    if (transposeSteps == null) {
      return originalNotes;
    }

    final marker = '[viewer_transpose:$transposeSteps]';
    final sanitized = originalNotes ?? '';
    final withoutExisting =
        sanitized.replaceAll(RegExp(r'\[viewer_transpose:[-0-9]+\]'), '');
    return withoutExisting.isEmpty
        ? marker
        : withoutExisting.trimRight() + '\n' + marker;
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
