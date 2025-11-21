import 'package:flutter/material.dart';
import '../../core/constants/song_viewer_constants.dart';

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

        return Text(
          snapshot.data!,
          style: TextStyle(
            fontSize: 14,
            color: textColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
