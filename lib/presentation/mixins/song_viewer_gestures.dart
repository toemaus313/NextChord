import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/song_viewer_provider.dart';

/// Mixin for handling song viewer gestures
mixin SongViewerGestures<T extends StatefulWidget> on State<T> {
  late SongViewerProvider _songViewerProvider;
  final ScrollController _scrollController = ScrollController();

  /// Initialize the gesture mixin with required dependencies
  void initializeGestures(SongViewerProvider songViewerProvider) {
    _songViewerProvider = songViewerProvider;
  }

  /// Get the scroll controller
  ScrollController get scrollController => _scrollController;

  /// Handle horizontal swipe gestures for setlist navigation
  void handleHorizontalSwipeEnd(
      DragEndDetails details, Function(bool) onNavigate) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < SongViewerConstants.swipeVelocityThreshold) {
      return;
    }

    final isNext = velocity < 0; // Swipe left -> Next, Swipe right -> Previous

    onNavigate(isNext);
  }

  /// Handle keyboard navigation for setlist songs
  void handleKeyboardNavigation(bool isNext, Function(bool) onNavigate) {
    onNavigate(isNext);
  }

  /// Handle pinch to zoom gesture
  void handlePinchToZoom(ScaleUpdateDetails details, double baseFontSize) {
    final newFontSize = baseFontSize * details.scale;
    _songViewerProvider.updateFontSize(newFontSize);
  }

  /// Handle scroll wheel zoom with Ctrl key
  void handleScrollWheelZoom(PointerScrollEvent event) {
    if (HardwareKeyboard.instance.isControlPressed) {
      final delta = event.scrollDelta.dy;
      // Scroll down = negative delta = increase font size
      // Scroll up = positive delta = decrease font size
      final fontSizeChange = -delta * SongViewerConstants.scrollZoomSensitivity;
      final newFontSize = _songViewerProvider.fontSize + fontSizeChange;
      _songViewerProvider.updateFontSize(newFontSize);
    }
  }

  /// Reset scroll position to top
  void resetScrollPosition() {
    _scrollController.animateTo(
      0,
      duration: SongViewerConstants.scrollAnimationDuration,
      curve: Curves.easeOut,
    );
  }

  /// Handle tap to close all flyouts
  void handleTapToCloseFlyouts() {
    _songViewerProvider.closeAllFlyouts();
  }

  /// Handle scale start for pinch gesture
  double handleScaleStart() {
    return _songViewerProvider.fontSize;
  }

  /// Check if a gesture should be handled based on current state
  bool shouldHandleGesture() {
    // Don't handle gestures if certain flyouts are open
    // Note: We allow horizontal swipe gestures even when autoscroll flyout is open
    // to enable song navigation during autoscroll
    return !_songViewerProvider.showTransposeFlyout &&
        !_songViewerProvider.showCapoFlyout;
  }

  /// Check if horizontal swipe gestures should be handled (more permissive)
  bool shouldHandleHorizontalSwipe() {
    // Allow horizontal swipe even when autoscroll flyout is open
    // Block only for transpose and capo flyouts which interfere with navigation
    return !_songViewerProvider.showTransposeFlyout &&
        !_songViewerProvider.showCapoFlyout;
  }

  /// Dispose of resources
  void disposeGestures() {
    _scrollController.dispose();
  }
}
