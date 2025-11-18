import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import 'global_sidebar.dart';

/// Wrapper widget that contains the main app content and global sidebar overlay
class AppWrapper extends StatelessWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content
        const HomeScreen(),
        
        // Global sidebar overlay
        const GlobalSidebar(),
      ],
    );
  }
}
