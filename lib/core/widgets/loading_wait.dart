import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Reusable loading overlay widget that displays the NextChord logo
/// with an animated circle around it. Blocks all user input until dismissed.
///
/// Usage:
/// ```dart
/// // Show loading
/// LoadingWait.show(context);
///
/// // Do async work...
/// await someAsyncOperation();
///
/// // Hide loading
/// LoadingWait.hide(context);
/// ```
class LoadingWait extends StatefulWidget {
  const LoadingWait({super.key});

  /// Show the loading overlay
  static Future<void> show(BuildContext context) async {
    // Schedule for next frame to ensure context is ready
    await Future.delayed(Duration.zero);
    if (context.mounted) {
      // Don't await - let dialog show asynchronously
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => const LoadingWait(),
      );
    }
  }

  /// Hide the loading overlay
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  State<LoadingWait> createState() => _LoadingWaitState();
}

class _LoadingWaitState extends State<LoadingWait>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button from dismissing
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated circle
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(180, 180),
                      painter: _CirclePainter(
                        progress: _controller.value,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
                // Logo in center
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Image.asset(
                    'assets/images/NextChord-Logo-transparent.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for animated circle around logo
class _CirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  _CirclePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw partial circle that rotates
    const sweepAngle = math.pi * 1.5; // 270 degrees
    final startAngle = progress * math.pi * 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
