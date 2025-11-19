import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import 'global_sidebar.dart';

/// Wrapper widget that contains the main app content and global sidebar in split-pane layout
class AppWrapper extends StatelessWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Global sidebar (animated width)
        const GlobalSidebar(),
        
        // Main app content (takes remaining space)
        Expanded(
          child: const HomeScreen(),
        ),
      ],
    );
  }
}
