import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/autoscroll_provider.dart';
import '../providers/song_viewer_provider.dart';
import 'adjustment_flyout.dart';

/// Autoscroll button widget with flyout controls
class AutoscrollButton extends StatelessWidget {
  final AutoscrollProvider autoscrollProvider;
  final SongViewerProvider viewerProvider;
  final void Function(int durationSeconds)? onDurationChanged;

  const AutoscrollButton({
    Key? key,
    required this.autoscrollProvider,
    required this.viewerProvider,
    this.onDurationChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Theme.of(context);
    final isDarkMode = themeProvider.brightness == Brightness.dark;
    final accent = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    return Consumer<AutoscrollProvider>(
      builder: (context, autoscroll, child) {
        return AdjustmentFlyout(
          isDarkMode: isDarkMode,
          isOpen: viewerProvider.showAutoscrollFlyout,
          onToggle: () => _handleToggle(autoscroll),
          icon: Icon(
            autoscroll.isActive ? Icons.pause : Icons.play_arrow,
            color: autoscroll.isActive ? Colors.white : accent,
            size: 18,
          ),
          displayValue: autoscroll.durationDisplay,
          semanticsLabel: 'Autoscroll duration ${autoscroll.durationDisplay}',
          onIncrement: () {
            autoscroll
                .adjustDuration(SongViewerConstants.autoscrollAdjustmentStep);
            onDurationChanged?.call(autoscroll.durationSeconds);
          },
          onDecrement: () {
            autoscroll
                .adjustDuration(-SongViewerConstants.autoscrollAdjustmentStep);
            onDurationChanged?.call(autoscroll.durationSeconds);
          },
          canIncrement: autoscroll.durationSeconds <
              SongViewerConstants.maxAutoscrollDuration,
          canDecrement: autoscroll.durationSeconds >
              SongViewerConstants.minAutoscrollDuration,
          isActive: autoscroll.isActive,
        );
      },
    );
  }

  void _handleToggle(AutoscrollProvider autoscroll) {
    final wasActive = autoscroll.isActive;
    final wasFlyoutOpen = viewerProvider.showAutoscrollFlyout;

    autoscroll.toggle();

    // Open flyout when autoscroll starts
    // Close flyout when stopping from open state
    // Keep flyout closed when stopping from closed state
    if (autoscroll.isActive) {
      viewerProvider.openFlyout(FlyoutType.autoscroll);
    } else if (wasActive && !wasFlyoutOpen) {
      // Was active with flyout closed, now stopping - keep flyout closed
      // Do nothing
    } else {
      // Normal toggle behavior
      viewerProvider.toggleFlyout(FlyoutType.autoscroll);
    }
  }
}
