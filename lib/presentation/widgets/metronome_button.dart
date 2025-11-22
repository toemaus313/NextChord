import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/metronome_provider.dart';

/// Metronome button widget with visual feedback
class MetronomeButton extends StatelessWidget {
  const MetronomeButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Theme.of(context);
    final isDarkMode = themeProvider.brightness == Brightness.dark;

    return Consumer<MetronomeProvider>(
      builder: (context, metronome, _) {
        final isActive = metronome.isRunning;
        final accent = isDarkMode
            ? SongViewerConstants.darkModeAccent
            : SongViewerConstants.lightModeAccent;
        final backgroundColor = isActive
            ? accent.withValues(alpha: 0.15)
            : isDarkMode
                ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.9);

        return Container(
          width: SongViewerConstants.buttonSize,
          height: SongViewerConstants.buttonSize,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? accent
                  : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400),
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: _buildFloatingShadows(isDarkMode),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: metronome.toggle,
              customBorder: const CircleBorder(),
              child: Center(
                child: CustomPaint(
                  size: const Size(16, 16),
                  painter: MetronomeIconPainter(
                    color: accent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<BoxShadow> _buildFloatingShadows(bool isDarkMode) {
    return isDarkMode
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];
  }
}

/// Custom painter for metronome icon (triangle with tick marks)
class MetronomeIconPainter extends CustomPainter {
  final Color color;

  const MetronomeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw triangle outline (metronome body)
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final trianglePath = Path();
    trianglePath.moveTo(size.width * 0.5, size.height * 0.15);
    trianglePath.lineTo(size.width * 0.25, size.height * 0.8);
    trianglePath.lineTo(size.width * 0.75, size.height * 0.8);
    trianglePath.close();
    canvas.drawPath(trianglePath, paint);

    // Draw pendulum
    final pendulumPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Pendulum arm
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.25),
      Offset(size.width * 0.5, size.height * 0.65),
      pendulumPaint,
    );

    // Pendulum weight (small triangle)
    final weightPath = Path();
    weightPath.moveTo(size.width * 0.45, size.height * 0.65);
    weightPath.lineTo(size.width * 0.55, size.height * 0.65);
    weightPath.lineTo(size.width * 0.5, size.height * 0.72);
    weightPath.close();

    final weightPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(weightPath, weightPaint);

    // Draw tick marks
    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Left tick marks
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.4),
      Offset(size.width * 0.22, size.height * 0.4),
      tickPaint,
    );

    // Right tick marks
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.4),
      Offset(size.width * 0.85, size.height * 0.4),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
