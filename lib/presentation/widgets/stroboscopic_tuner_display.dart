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

  const StroboscopicTunerDisplay({
    Key? key,
    required this.tuningResult,
    this.width = 300,
    this.height = 120,
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
            // Background strobe pattern
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.width, widget.height),
                  painter: StroboscopicPatternPainter(
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

/// Custom painter for the stroboscopic pattern
class StroboscopicPatternPainter extends CustomPainter {
  final double animationValue;
  final TuningResult? tuningResult;

  StroboscopicPatternPainter({
    required this.animationValue,
    this.tuningResult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Calculate pattern movement based on tuning
    double patternOffset = 0.0;
    double patternSpeed = 1.0;

    if (tuningResult != null) {
      // Convert cents to pattern movement
      // When in tune, pattern appears stationary
      // When flat, pattern moves left; when sharp, pattern moves right
      final centsOff = tuningResult!.centsOff;
      patternSpeed = (centsOff.abs() / 50.0).clamp(0.1, 2.0);
      patternOffset = centsOff / 100.0; // Scale cents to reasonable offset
    }

    // Draw multiple layers of strobe patterns
    _drawStrobeLayer(canvas, size, paint, 0, patternOffset, patternSpeed);
    _drawStrobeLayer(
        canvas, size, paint, 1, patternOffset * 0.7, patternSpeed * 0.8);
    _drawStrobeLayer(
        canvas, size, paint, 2, patternOffset * 0.5, patternSpeed * 0.6);
  }

  void _drawStrobeLayer(
    Canvas canvas,
    Size size,
    Paint paint,
    int layer,
    double offset,
    double speed,
  ) {
    // Different colors for each layer
    final colors = [
      Colors.white.withValues(alpha: 0.3),
      Colors.blue.withValues(alpha: 0.2),
      Colors.cyan.withValues(alpha: 0.15),
    ];

    paint.color = colors[layer % colors.length];

    // Pattern parameters
    final stripeWidth = 8.0 + (layer * 2);
    final stripeSpacing = stripeWidth * 2;
    final totalWidth = size.width + stripeSpacing * 2;

    // Calculate animated position
    final animatedOffset =
        (animationValue * speed * stripeSpacing) + (offset * stripeSpacing);
    final startX = -stripeSpacing + (animatedOffset % stripeSpacing);

    // Draw diagonal stripes
    for (double x = startX; x < totalWidth; x += stripeSpacing) {
      final path = Path();

      // Create diagonal stripe
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height * 0.3, size.height);
      path.lineTo(x + size.height * 0.3, size.height);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(StroboscopicPatternPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        tuningResult != oldDelegate.tuningResult;
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
