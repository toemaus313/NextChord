import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Provider for managing global sidebar visibility across the app
class GlobalSidebarProvider extends ChangeNotifier {
  bool _isSidebarVisible = false;
  AnimationController? _animationController;

  bool get isSidebarVisible => _isSidebarVisible;

  /// Initialize the animation controller
  void initializeAnimation(AnimationController controller) {
    _animationController = controller;
    debugPrint('Animation controller initialized in provider');
  }

  /// Toggle sidebar visibility
  void toggleSidebar() {
    debugPrint('toggleSidebar called, _isSidebarVisible: $_isSidebarVisible');
    if (_isSidebarVisible) {
      hideSidebar();
    } else {
      showSidebar();
    }
  }

  /// Show the sidebar with animation
  void showSidebar() {
    debugPrint('showSidebar called, _isSidebarVisible: $_isSidebarVisible');
    if (!_isSidebarVisible && _animationController != null) {
      _isSidebarVisible = true;
      debugPrint('Setting _isSidebarVisible to true, starting animation');
      _animationController!.forward();
      notifyListeners();
    } else if (_animationController == null) {
      debugPrint('Animation controller is null - cannot show sidebar');
    }
  }

  /// Hide the sidebar with animation
  void hideSidebar() {
    debugPrint('hideSidebar called, _isSidebarVisible: $_isSidebarVisible');
    if (_isSidebarVisible && _animationController != null) {
      _isSidebarVisible = false;
      debugPrint('Setting _isSidebarVisible to false, reversing animation');
      _animationController!.reverse();
      notifyListeners();
    }
  }
}
