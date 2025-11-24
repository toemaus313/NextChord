import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../providers/global_sidebar_provider.dart';
import '../screens/home_screen.dart';
import 'global_sidebar.dart';
import '../../core/widgets/responsive_config.dart';

/// Wrapper widget that contains the main app content and global sidebar in responsive layout
/// - Desktop/Tablet: Split-pane layout with sidebar + content side-by-side
/// - Phone: Navigator-based layout with sidebar as home screen and content as detail views
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
    return ResponsiveConfigProvider(
      child: Builder(
        builder: (context) {
          final isPhone = ResponsiveConfig.isPhone(context);

          if (isPhone) {
            // Phone: Navigator-based layout with sidebar as home screen
            return const _PhoneLayout();
          } else {
            // Desktop/Tablet: Split-pane layout (existing behavior)
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
        },
      ),
    );
  }
}

/// Phone layout using Navigator with sidebar as home screen
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const _PhoneSidebarScreen(),
          settings: settings,
        );
      },
    );
  }
}

/// Phone sidebar screen - serves as the home screen on phones
class _PhoneSidebarScreen extends StatefulWidget {
  const _PhoneSidebarScreen({Key? key}) : super(key: key);

  @override
  State<_PhoneSidebarScreen> createState() => _PhoneSidebarScreenState();
}

class _PhoneSidebarScreenState extends State<_PhoneSidebarScreen> {
  @override
  void initState() {
    super.initState();
    // Set up phone navigation callback in GlobalSidebarProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GlobalSidebarProvider>().setPhoneMode(
          true,
          onNavigateToContent: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const _PhoneContentScreen(
                  content: HomeScreen(),
                ),
              ),
            );
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle Android back button - exit app when on sidebar screen
        return false;
      },
      child: const Scaffold(
        body: GlobalSidebar(),
      ),
    );
  }
}

/// Phone content screen with global back button
class _PhoneContentScreen extends StatelessWidget {
  final Widget content;

  const _PhoneContentScreen({
    Key? key,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0468cc),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(''),
      ),
      body: content,
    );
  }
}
