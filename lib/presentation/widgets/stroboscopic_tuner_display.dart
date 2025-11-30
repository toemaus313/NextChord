import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio/guitar_tuner_service.dart';

/// A stroboscopic tuner display widget that shows visual feedback for guitar tuning
///
/// The stroboscopic effect is created by moving patterns that appear stationary
/// when the detected frequency matches the target frequency. When out of tune,
/// the patterns move left (flat) or right (sharp).
class StroboscopicTunerDisplay extends StatefulWidget {
  final TuningResult? tuningResult;
  final double width;
  final double height;
  final double deadZoneCents; // Cents within which pattern freezes

  const StroboscopicTunerDisplay({
    Key? key,
    required this.tuningResult,
    this.width = 300,
    this.height = 120,
    this.deadZoneCents = 5.0,
  }) : super(key: key);

  @override
  State<StroboscopicTunerDisplay> createState() =>
      _StroboscopicTunerDisplayState();
}

class _StroboscopicTunerDisplayState extends State<StroboscopicTunerDisplay>
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
    return Column(
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF050814), // Very dark blue-black
                const Color(0xFF0A0F1A), // Slightly lighter dark
              ],
            ),
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
                // Background strobe pattern
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(widget.width, widget.height),
                      painter: StroboscopicPatternPainter(
                        animationValue: _animation.value,
                        tuningResult: widget.tuningResult,
                        deadZoneCents: widget.deadZoneCents,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // Overlay information moved below the animation
        _buildOverlayInfo(),
      ],
    );
  }

  Widget _buildOverlayInfo() {
    final result = widget.tuningResult;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
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
          const SizedBox(height: 4),
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

/// Custom painter for the stroboscopic pattern
class StroboscopicPatternPainter extends CustomPainter {
  final double animationValue;
  final TuningResult? tuningResult;
  final double deadZoneCents;

  StroboscopicPatternPainter({
    required this.animationValue,
    this.tuningResult,
    this.deadZoneCents = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Calculate pattern movement based on cents offset
    double patternSpeed = 0.0;
    bool isInTune = false;

    if (tuningResult != null) {
      final centsOff = tuningResult!.centsOff;
      final absCents = centsOff.abs();

      if (absCents <= deadZoneCents) {
        // Freeze the pattern when in tune
        patternSpeed = 0.0;
        isInTune = true;
      } else {
        // Speed proportional to cents off with direction - faster overall
        const double minSpeed = 0.2; // Increased minimum speed
        const double maxSpeed =
            20.0; // Increased maximum speed for faster animation
        const double maxCents =
            250.0; // 100% speed at 250 cents (halfway between strings)

        final double normalized = (absCents.clamp(0.0, maxCents)) / maxCents;

        // Add smoothing near in-tune to prevent jumping
        double speedMultiplier = 1.0;
        if (absCents <= deadZoneCents * 2) {
          // Gradual ramp zone: reduce speed smoothly as we approach dead zone
          final double rampRange = deadZoneCents * 2;
          final double rampPosition = absCents / rampRange;
          speedMultiplier = rampPosition *
              rampPosition; // Quadratic easing for smooth transition
        }

        patternSpeed =
            (minSpeed + (maxSpeed - minSpeed) * normalized) * speedMultiplier;
        if (centsOff < 0)
          patternSpeed = -patternSpeed; // Negative for flat (left)
      }
    }

    // Draw single layer of regular vertical bars
    _drawStrobeLayer(canvas, size, paint, patternSpeed, isInTune);
  }

  void _drawStrobeLayer(
    Canvas canvas,
    Size size,
    Paint paint,
    double speed,
    bool isInTune,
  ) {
    // Color based on tuning state
    final patternColor = isInTune
        ? const Color(0xFF4CFF4C) // Bright saturated green when in tune
        : const Color(0xFFB7410E); // Rust color when out of tune

    paint.color = patternColor.withOpacity(0.8); // High opacity for visibility

    // Regular repeating pattern: 20x20 squares
    const double squareSize = 20.0;
    const double gapSize = 20.0; // Alternating pattern, so gap = square size
    const double tileWidth = squareSize + gapSize;

    // Vertical positioning: 10px padding top and bottom in 40px container
    const double verticalPadding = 10.0;
    const double squareY = verticalPadding; // 10px from top

    // Calculate phase offset for smooth animation
    final animatedOffset = animationValue * speed * tileWidth;
    final phaseOffset = animatedOffset % tileWidth;

    // Draw squares across the strip with tiling
    for (int i = -1;; i++) {
      final x = i * tileWidth + phaseOffset;
      if (x > size.width + squareSize) break; // Past the right edge
      if (x < 0 || x + squareSize > size.width)
        continue; // Only draw fully visible squares

      final squareRect = Rect.fromLTWH(x, squareY, squareSize, squareSize);
      canvas.drawRect(squareRect, paint);
    }
  }

  @override
  bool shouldRepaint(StroboscopicPatternPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        tuningResult != oldDelegate.tuningResult ||
        deadZoneCents != oldDelegate.deadZoneCents;
  }
}

/// A circular tuning indicator that shows how close to in-tune the string is
class CircularTuningIndicator extends StatelessWidget {
  final TuningResult? tuningResult;
  final double size;

  const CircularTuningIndicator({
    Key? key,
    required this.tuningResult,
    this.size = 100,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: CustomPaint(
        painter: CircularTuningPainter(tuningResult: tuningResult),
      ),
    );
  }
}

/// Custom painter for the circular tuning indicator
class CircularTuningPainter extends CustomPainter {
  final TuningResult? tuningResult;

  CircularTuningPainter({this.tuningResult});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw background circle
    paint.color = Colors.white24;
    canvas.drawCircle(center, radius, paint);

    if (tuningResult != null) {
      // Draw tuning arc
      final centsOff = tuningResult!.centsOff;
      final normalizedCents = (centsOff / 50.0).clamp(-1.0, 1.0);

      // Calculate arc parameters
      final startAngle = -pi / 2; // Top of circle
      final sweepAngle = normalizedCents * pi / 2; // Quarter circle max

      // Color based on tuning accuracy
      paint.color = _getArcColor(centsOff);
      paint.strokeWidth = 6;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      // Draw center dot
      paint.style = PaintingStyle.fill;
      paint.color = tuningResult!.isInTune ? Colors.green : Colors.orange;
      canvas.drawCircle(center, 8, paint);
    }
  }

  Color _getArcColor(double cents) {
    final absValue = cents.abs();
    if (absValue <= 10) return Colors.green;
    if (absValue <= 25) return Colors.yellow;
    return Colors.red;
  }

  @override
  bool shouldRepaint(CircularTuningPainter oldDelegate) {
    return tuningResult != oldDelegate.tuningResult;
  }
}
