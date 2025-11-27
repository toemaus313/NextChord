import 'package:flutter/material.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/song_viewer_provider.dart';
import 'adjustment_flyout.dart';

/// Transpose button widget with flyout controls
class TransposeButton extends StatelessWidget {
  final SongViewerProvider provider;
  final VoidCallback? onScopeToggle;

  const TransposeButton({
    Key? key,
    required this.provider,
    this.onScopeToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Theme.of(context);
    final isDarkMode = themeProvider.brightness == Brightness.dark;
    final accent = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    final icon = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '−',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 1),
        Icon(
          Icons.music_note,
          color: accent,
          size: 14,
        ),
        const SizedBox(width: 1),
        Text(
          '+',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ],
    );

    Widget? extraContent;
    if (onScopeToggle != null) {
      extraContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scope toggle button would go here if needed
        ],
      );
    }

    return AdjustmentFlyout(
      isDarkMode: isDarkMode,
      isOpen: provider.showTransposeFlyout,
      onToggle: () => provider.toggleFlyout(FlyoutType.transpose),
      icon: icon,
      displayValue: provider.formatSignedValue(provider.transposeSteps),
      semanticsLabel: provider.transposeStatusLabel,
      onIncrement: () => provider.updateTranspose(1),
      onDecrement: () => provider.updateTranspose(-1),
      canIncrement: provider.canIncrementTranspose(),
      canDecrement: provider.canDecrementTranspose(),
      extraContent: extraContent,
    );
  }
}
