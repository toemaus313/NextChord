import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio/guitar_tuner_service.dart';

/// A semicircle tuner display with moving dots that indicate tuning status
///
/// - Dots move clockwise when flat (need to tune up)
/// - Dots move counterclockwise when sharp (need to tune down)
/// - Dots stop moving when in tune
/// - Speed increases with how far off pitch the note is
class SemicircleTunerDisplay extends StatefulWidget {
  final TuningResult? tuningResult;
  final double width;
  final double height;

  const SemicircleTunerDisplay({
    Key? key,
    required this.tuningResult,
    this.width = 400,
    this.height = 120,
  }) : super(key: key);

  @override
  State<SemicircleTunerDisplay> createState() => _SemicircleTunerDisplayState();
}

class _SemicircleTunerDisplayState extends State<SemicircleTunerDisplay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white24,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Semicircle with moving dots
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.width, widget.height),
                  painter: SemicircleDotsPainter(
                    animationValue: _animation.value,
                    tuningResult: widget.tuningResult,
                  ),
                );
              },
            ),
            // Overlay information
            _buildOverlayInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayInfo() {
    final result = widget.tuningResult;

    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: String name and frequency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  result?.closestString?.name ?? '--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  result != null
                      ? '${result.detectedFrequency.toStringAsFixed(1)} Hz'
                      : '-- Hz',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            // Bottom row: Tuning status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getTuningStatusText(result),
                  style: TextStyle(
                    color: _getTuningStatusColor(result),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (result != null)
                  Text(
                    '${result.centsOff > 0 ? '+' : ''}${result.centsOff.toStringAsFixed(0)}¢',
                    style: TextStyle(
                      color: _getCentsColor(result.centsOff),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTuningStatusText(TuningResult? result) {
    if (result == null) return 'Listening...';
    if (result.isInTune) return 'IN TUNE';
    if (result.centsOff > 0) return 'SHARP';
    return 'FLAT';
  }

  Color _getTuningStatusColor(TuningResult? result) {
    if (result == null) return Colors.white70;
    if (result.isInTune) return Colors.green;
    return Colors.orange;
  }

  Color _getCentsColor(double cents) {
    final absValue = cents.abs();
    if (absValue <= 10) return Colors.green;
    if (absValue <= 25) return Colors.yellow;
    return Colors.red;
  }
}

/// Custom painter for the semicircle with moving dots
class SemicircleDotsPainter extends CustomPainter {
  final double animationValue;
  final TuningResult? tuningResult;

  SemicircleDotsPainter({
    required this.animationValue,
    this.tuningResult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = min(size.width / 2 - 40, size.height - 40);

    // Draw semicircle track
    _drawSemicircleTrack(canvas, center, radius);

    // Draw moving dots
    _drawMovingDots(canvas, center, radius);

    // Draw center indicator
    _drawCenterIndicator(canvas, center);
  }

  void _drawSemicircleTrack(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw semicircle track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Start at left (180 degrees)
      pi, // Draw semicircle (180 degrees)
      false,
      paint,
    );

    // Draw tick marks
    _drawTickMarks(canvas, center, radius);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw tick marks at key positions
    final tickPositions = [
      pi * 0.75, // -45 degrees (sharp)
      pi * 0.875, // -22.5 degrees
      pi, // 0 degrees (center/in tune)
      pi * 1.125, // +22.5 degrees
      pi * 1.25, // +45 degrees (flat)
    ];

    for (final angle in tickPositions) {
      final startRadius = radius - 5;
      final endRadius = radius + 5;

      final startX = center.dx + cos(angle) * startRadius;
      final startY = center.dy + sin(angle) * startRadius;
      final endX = center.dx + cos(angle) * endRadius;
      final endY = center.dy + sin(angle) * endRadius;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }
  }

  void _drawMovingDots(Canvas canvas, Offset center, double radius) {
    if (tuningResult == null) {
      // No tuning data, show static dots
      _drawStaticDots(canvas, center, radius);
      return;
    }

    // Calculate movement based on tuning
    final centsOff = tuningResult!.centsOff;
    final isInTune = tuningResult!.isInTune;

    // When in tune, dots don't move
    if (isInTune) {
      _drawStaticDots(canvas, center, radius);
      return;
    }

    // Calculate speed and direction
    final speed =
        (centsOff.abs() / 50.0).clamp(0.2, 2.0); // Speed based on how far off
    final direction =
        centsOff > 0 ? -1.0 : 1.0; // Sharp = counterclockwise, Flat = clockwise

    // Calculate animated offset
    final animatedOffset = animationValue * speed * direction * pi * 0.5;

    // Draw dots at various positions around the semicircle
    final dotCount = 12;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final baseAngle =
          pi + (i / (dotCount - 1)) * pi; // Spread across semicircle
      final angle = baseAngle + animatedOffset;

      // Calculate dot position
      final dotX = center.dx + cos(angle) * radius;
      final dotY = center.dy + sin(angle) * radius;

      // Color dots based on tuning status
      final opacity = (0.3 + 0.7 * (1 - (i % 3) * 0.2)).clamp(0.0, 1.0);
      paint.color = _getDotColor(centsOff).withOpacity(opacity);

      // Draw dot
      canvas.drawCircle(Offset(dotX, dotY), 4, paint);
    }
  }

  void _drawStaticDots(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw a few static dots when in tune or no signal
    final dotPositions = [
      pi * 0.85,
      pi,
      pi * 1.15,
    ];

    for (final angle in dotPositions) {
      final dotX = center.dx + cos(angle) * radius;
      final dotY = center.dy + sin(angle) * radius;
      canvas.drawCircle(Offset(dotX, dotY), 4, paint);
    }
  }

  void _drawCenterIndicator(Canvas canvas, Offset center) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (tuningResult?.isInTune == true) {
      // Green dot when in tune
      paint.color = Colors.green;
      canvas.drawCircle(center, 8, paint);
    } else if (tuningResult != null) {
      // Orange dot when out of tune
      paint.color = Colors.orange;
      canvas.drawCircle(center, 6, paint);
    } else {
      // Gray dot when no signal
      paint.color = Colors.white54;
      canvas.drawCircle(center, 4, paint);
    }
  }

  Color _getDotColor(double cents) {
    final absValue = cents.abs();
    if (absValue <= 10) return Colors.green;
    if (absValue <= 25) return Colors.yellow;
    return Colors.red;
  }

  @override
  bool shouldRepaint(SemicircleDotsPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        tuningResult != oldDelegate.tuningResult;
  }
}
