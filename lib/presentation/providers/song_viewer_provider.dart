import 'package:flutter/material.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/song.dart';
import '../../services/song_adjustment_service.dart';

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

  SongViewerProvider({
    required Song song,
    SetlistSongItem? setlistContext,
  })  : _currentSong = song,
        _setlistContext = setlistContext,
        _fontSize = SongViewerConstants.defaultFontSize,
        _transposeSteps = setlistContext?.transposeSteps ?? 0,
        _currentCapo = setlistContext?.capo ?? song.capo {
    _initializeViewerAdjustments();
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
    Logger.methodEntry(
        'SongViewerProvider', 'updateSong', {'songTitle': newSong.title});

    _currentSong = newSong;
    _transposeSteps = _setlistContext?.transposeSteps ?? 0;
    _currentCapo = _setlistContext?.capo ?? newSong.capo;
    _initializeViewerAdjustments();

    Logger.methodExit('SongViewerProvider', 'updateSong');
    notifyListeners();
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
    Logger.methodEntry(
        'SongViewerProvider', 'toggleFlyout', {'type': type.toString()});

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

    Logger.methodExit('SongViewerProvider', 'toggleFlyout');
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
}
