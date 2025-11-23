import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/song_viewer_constants.dart';
import '../providers/setlist_provider.dart';

/// Header widget for the song viewer displaying song title and next song info
class SongViewerHeader extends StatelessWidget {
  final String songTitle;
  final Future<String?> nextSongDisplayTextFuture;

  const SongViewerHeader({
    Key? key,
    required this.songTitle,
    required this.nextSongDisplayTextFuture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Theme.of(context);
    final isDarkMode = themeProvider.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // Watch SetlistProvider to trigger rebuild when setlist state changes
    context.watch<SetlistProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SongViewerConstants.headerPadding,
        vertical: 12,
      ),
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              songTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            _buildNextSongDisplay(textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSongDisplay(Color textColor) {
    return FutureBuilder<String?>(
      future: nextSongDisplayTextFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final displayText = snapshot.data!;

        // Check if there's a capo section to color orange
        final capoIndex = displayText.indexOf(' | Capo ');
        if (capoIndex == -1) {
          // No capo, use regular text
          return Text(
            displayText,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          );
        }

        // Split text for capo coloring
        final beforeCapo = displayText.substring(0, capoIndex);
        final capoText = displayText.substring(capoIndex);

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: beforeCapo,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: capoText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
