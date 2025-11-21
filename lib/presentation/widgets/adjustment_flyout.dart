import 'package:flutter/material.dart';
import '../../core/constants/song_viewer_constants.dart';

/// Reusable flyout widget for adjustments (transpose, capo, autoscroll)
class AdjustmentFlyout extends StatelessWidget {
  final bool isDarkMode;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget icon;
  final String displayValue;
  final String? semanticsLabel;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool canIncrement;
  final bool canDecrement;
  final Widget? extraContent;
  final bool isActive;

  const AdjustmentFlyout({
    Key? key,
    required this.isDarkMode,
    required this.isOpen,
    required this.onToggle,
    required this.icon,
    required this.displayValue,
    this.semanticsLabel,
    required this.onIncrement,
    required this.onDecrement,
    this.canIncrement = true,
    this.canDecrement = true,
    this.extraContent,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode
        ? const Color(0xFF0A0A0A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accent = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    return SizedBox(
      width: SongViewerConstants.flyoutWidth,
      height: SongViewerConstants.flyoutHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // Flyout content panel
          Positioned(
            right: 52,
            child: AnimatedOpacity(
              duration: SongViewerConstants.flyoutAnimationDuration,
              opacity: isOpen ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isOpen,
                child: Container(
                  width: SongViewerConstants.flyoutExtendedWidth,
                  height: SongViewerConstants.flyoutHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.0),
                    boxShadow: _buildFloatingShadows(isDarkMode),
                  ),
                  child: Row(
                    children: [
                      _buildInlineAdjustmentControl(
                        label: '- ',
                        onPressed: onDecrement,
                        enabled: canDecrement,
                        accentColor: accent,
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            // Absorb taps on the display value to prevent propagation
                          },
                          child: Center(
                            child: Semantics(
                              label: semanticsLabel ?? displayValue,
                              child: Text(
                                displayValue,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildInlineAdjustmentControl(
                        label: ' +',
                        onPressed: onIncrement,
                        enabled: canIncrement,
                        accentColor: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Extra content (if provided)
          if (extraContent != null)
            Positioned(
              right: 52,
              top: 48,
              child: AnimatedOpacity(
                duration: SongViewerConstants.flyoutAnimationDuration,
                opacity: isOpen ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !isOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Absorb taps to prevent propagation to parent
                    },
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1.0),
                        boxShadow: _buildFloatingShadows(isDarkMode),
                      ),
                      child: extraContent,
                    ),
                  ),
                ),
              ),
            ),
          // Toggle button
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: onToggle,
              child: Container(
                width: SongViewerConstants.buttonSize,
                height: SongViewerConstants.buttonSize,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.blue.withValues(alpha: 0.8)
                      : (isDarkMode
                          ? const Color(0xFF0A0A0A).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? Colors.blue : borderColor,
                    width: 1.0,
                  ),
                  boxShadow: _buildFloatingShadows(isDarkMode),
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineAdjustmentControl({
    required String label,
    required VoidCallback onPressed,
    required bool enabled,
    required Color accentColor,
  }) {
    final color = enabled ? accentColor : accentColor.withValues(alpha: 0.35);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: SizedBox(
        width: 32,
        height: SongViewerConstants.flyoutHeight,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
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
