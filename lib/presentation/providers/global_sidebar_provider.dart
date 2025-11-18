import 'package:flutter/material.dart';

/// Provider for managing global sidebar visibility across the app
class GlobalSidebarProvider extends ChangeNotifier {
  bool _isSidebarVisible = false;
  AnimationController? _animationController;

  bool get isSidebarVisible => _isSidebarVisible;

  /// Initialize the animation controller
  void initializeAnimation(AnimationController controller) {
    _animationController = controller;
    print('Animation controller initialized in provider');
  }

  /// Toggle sidebar visibility
  void toggleSidebar() {
    print('toggleSidebar called, _isSidebarVisible: $_isSidebarVisible');
    if (_isSidebarVisible) {
      hideSidebar();
    } else {
      showSidebar();
    }
  }

  /// Show the sidebar with animation
  void showSidebar() {
    print('showSidebar called, _isSidebarVisible: $_isSidebarVisible');
    if (!_isSidebarVisible && _animationController != null) {
      _isSidebarVisible = true;
      print('Setting _isSidebarVisible to true, starting animation');
      _animationController!.forward();
      notifyListeners();
    } else if (_animationController == null) {
      print('Animation controller is null - cannot show sidebar');
    }
  }

  /// Hide the sidebar with animation
  void hideSidebar() {
    print('hideSidebar called, _isSidebarVisible: $_isSidebarVisible');
    if (_isSidebarVisible && _animationController != null) {
      _isSidebarVisible = false;
      print('Setting _isSidebarVisible to false, reversing animation');
      _animationController!.reverse();
      notifyListeners();
    }
  }
}
