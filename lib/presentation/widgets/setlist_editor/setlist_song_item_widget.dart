import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/setlist.dart';
import '../../../domain/entities/song.dart';
import '../../providers/global_sidebar_provider.dart';

/// Individual song item widget for setlist display
///
/// Handles song rendering with drag handle, key/capo display,
/// context menus, and navigation interactions.
class SetlistSongItemWidget extends StatelessWidget {
  final SetlistSongItem item;
  final Song? song;
  final int index;
  final VoidCallback onSecondaryTap;
  final VoidCallback onLongPress;
  final String Function(String, int) transposeKey;

  const SetlistSongItemWidget({
    Key? key,
    required this.item,
    required this.song,
    required this.index,
    required this.onSecondaryTap,
    required this.onLongPress,
    required this.transposeKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = song?.title ?? 'Unknown song';
    final artist = song?.artist ?? '';

    // Calculate effective key and capo
    String displayKey = song?.key ?? '';
    int capo = song?.capo ?? 0;

    if (song != null) {
      if (item.transposeSteps != 0) {
        // Apply transpose to key
        displayKey = transposeKey(displayKey, item.transposeSteps);
      }
      if (item.capo != (song?.capo ?? 0)) {
        capo = item.capo;
      }
    }

    return GestureDetector(
      key: ValueKey('song_${item.songId}_$index'),
      onTap: () {
        if (song != null) {
          context.read<GlobalSidebarProvider>().navigateToSongInSetlist(
                song!,
                index,
                item,
              );
        }
      },
      onSecondaryTap: onSecondaryTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Icon(
                Icons.drag_indicator,
                color: Colors.white54,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist.isNotEmpty)
                    Text(
                      artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Key and capo info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayKey,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (capo > 0)
                  Text(
                    'CAPO $capo',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
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
}
