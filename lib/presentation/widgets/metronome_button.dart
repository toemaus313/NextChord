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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw triangle - adjusted to use more of the available space
    final trianglePath = Path();
    trianglePath.moveTo(
        size.width * 0.5, size.height * 0.1); // Moved from 0.2 to 0.1
    trianglePath.lineTo(
        size.width * 0.3, size.height * 0.85); // Moved from 0.8 to 0.85
    trianglePath.lineTo(
        size.width * 0.7, size.height * 0.85); // Moved from 0.8 to 0.85
    trianglePath.close();
    canvas.drawPath(trianglePath, paint);

    // Draw tick marks
    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Left tick
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.35), // Adjusted from 0.4
      Offset(size.width * 0.35, size.height * 0.35), // Adjusted from 0.4
      tickPaint,
    );

    // Right tick
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.35), // Adjusted from 0.4
      Offset(size.width * 0.8, size.height * 0.35), // Adjusted from 0.4
      tickPaint,
    );

    // Center vertical tick
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.7),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
