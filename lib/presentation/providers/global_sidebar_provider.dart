import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Provider for managing global sidebar visibility across the app
class GlobalSidebarProvider extends ChangeNotifier {
  bool _isSidebarVisible = true;
  AnimationController? _animationController;

  bool get isSidebarVisible => _isSidebarVisible;

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
}
