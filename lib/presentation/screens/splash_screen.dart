import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/appearance_provider.dart';
import '../widgets/app_wrapper.dart';

/// Splash screen with centered logo and text that animates down after 2 seconds
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _showMainApp = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Define slide animation (from center to current position)
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero, // Start at center
      end: const Offset(0, 0.171), // Move down by ~17.1% of screen height (another 1px higher)
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));

    // Define fade animation for menu appearance
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start the animation sequence after 2 seconds
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // Wait 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // Start slide animation
    _slideController.forward();
    
    // Start fade animation for main app after slide begins
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    // Show main app after animations complete
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _showMainApp = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearanceProvider = context.watch<AppearanceProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Calculate responsive logo size - IDENTICAL to mobile sidebar branding
    final logoWidth = (screenWidth * 0.6).clamp(250.0, 360.0);
    final titleFontSize = (screenWidth * 0.06).clamp(60.0, 70.0);

    if (_showMainApp) {
      return const AppWrapper();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              appearanceProvider.gradientStart,
              appearanceProvider.gradientEnd,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Main app content (faded in during transition)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: const AppWrapper(),
                );
              },
            ),
            
            // Splash screen content (slides down)
            if (!_showMainApp)
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Image.asset(
                            'assets/images/NextChord-Logo-transparent.png',
                            width: logoWidth,
                            fit: BoxFit.contain,
                            semanticLabel: 'NextChord logo',
                          ),
                          const SizedBox(height: 0),
                          // Title text
                          Text(
                            'NextChord',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
