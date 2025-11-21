import 'package:flutter/material.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/song_viewer_provider.dart';
import 'adjustment_flyout.dart';

/// Custom painter for capo icon (fretboard with horizontal lines)
class CapoIconPainter extends CustomPainter {
  final Color color;

  CapoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines (strings) - 4 strings
    final stringSpacing = size.width / 5;
    for (int i = 1; i <= 4; i++) {
      final x = stringSpacing * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines (frets) - 3 frets
    final fretSpacing = size.height / 4;
    for (int i = 1; i <= 3; i++) {
      final y = fretSpacing * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw capo bar at top (thicker horizontal line)
    final capoPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(stringSpacing, 1),
      Offset(size.width - stringSpacing, 1),
      capoPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Capo button widget with flyout controls
class CapoButton extends StatelessWidget {
  final SongViewerProvider provider;
  final VoidCallback? onScopeToggle;

  const CapoButton({
    Key? key,
    required this.provider,
    this.onScopeToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Theme.of(context);
    final isDarkMode = themeProvider.brightness == Brightness.dark;
    final iconColor = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    return AdjustmentFlyout(
      isDarkMode: isDarkMode,
      isOpen: provider.showCapoFlyout,
      onToggle: () => provider.toggleFlyout(FlyoutType.capo),
      icon: CustomPaint(
        size: const Size(18, 18),
        painter: CapoIconPainter(color: iconColor),
      ),
      displayValue: '${provider.currentCapo}',
      semanticsLabel: provider.capoStatusLabel,
      onIncrement: () => provider.updateCapo(1),
      onDecrement: () => provider.updateCapo(-1),
      canIncrement: provider.canIncrementCapo(),
      canDecrement: provider.canDecrementCapo(),
      extraContent: onScopeToggle != null ? _buildScopeToggle() : null,
    );
  }

  Widget _buildScopeToggle() {
    // This would contain the scope toggle UI if needed
    // For now, returning empty widget as it was removed in the original
    return const SizedBox.shrink();
  }
}
