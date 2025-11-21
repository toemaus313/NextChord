import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/metronome_provider.dart';

/// Overlay widget for metronome flash and beat count display
class MetronomeFlashOverlay extends StatelessWidget {
  const MetronomeFlashOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<MetronomeProvider, (bool, bool, int)>(
      selector: (_, provider) => (
        provider.flashActive,
        provider.isCountingIn,
        provider.currentCountInBeat
      ),
      builder: (context, values, _) {
        final isFlashing = values.$1;
        final isCountingIn = values.$2;
        final currentBeat = values.$3;

        return IgnorePointer(
          ignoring: true,
          child: Stack(
            children: [
              // Flash border (shows during normal flashing and count-in)
              AnimatedOpacity(
                duration: SongViewerConstants.metronomeFlashDuration,
                opacity: isFlashing ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: SongViewerConstants.sidebarTopColor
                          .withValues(alpha: 0.5),
                      width: 12,
                    ),
                  ),
                ),
              ),
              // Beat number display (shows only during count-in)
              if (isCountingIn && currentBeat > 0)
                Positioned.fill(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: SongViewerConstants.metronomeFlashDuration,
                      opacity: isFlashing ? 1.0 : 0.3,
                      child: Text(
                        currentBeat.toString(),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.35,
                          fontWeight: FontWeight.bold,
                          color: SongViewerConstants.sidebarTopColor
                              .withValues(alpha: 0.8),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
