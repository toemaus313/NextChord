import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../screens/home_screen.dart';
import 'global_sidebar.dart';

/// Wrapper widget that contains the main app content and global sidebar in split-pane layout
class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    // Connect MetronomeProvider with MetronomeSettingsProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final metronomeProvider = context.read<MetronomeProvider>();
      final settingsProvider = context.read<MetronomeSettingsProvider>();
      metronomeProvider.setSettingsProvider(settingsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // Global sidebar (animated width)
        GlobalSidebar(),

        // Main app content (takes remaining space)
        Expanded(
          child: HomeScreen(),
        ),
      ],
    );
  }
}
