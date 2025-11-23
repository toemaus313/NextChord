import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../sidebar_components/sidebar_header.dart';

/// Artists list view for the sidebar
class SidebarArtistsListView extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String) onArtistSelected;

  const SidebarArtistsListView({
    Key? key,
    required this.onBack,
    required this.onArtistSelected,
  }) : super(key: key);

  @override
  State<SidebarArtistsListView> createState() => _SidebarArtistsListViewState();
}

class _SidebarArtistsListViewState extends State<SidebarArtistsListView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        // Get unique artists
        final artists = <String>{};
        final artistSongCounts = <String, int>{};

        for (final song in provider.songs) {
          if (song.artist.isNotEmpty) {
            artists.add(song.artist);
            artistSongCounts[song.artist] =
                (artistSongCounts[song.artist] ?? 0) + 1;
          }
        }

        final sortedArtists = artists.toList()..sort();

        return Column(
          children: [
            SidebarHeader(
              title: 'Artists',
              icon: Icons.person_outline,
              onClose: widget.onBack,
            ),
            Expanded(
              child: sortedArtists.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 48,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No artists found',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add songs with artists to see them here',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sortedArtists.length,
                      itemBuilder: (context, index) {
                        final artist = sortedArtists[index];
                        final songCount = artistSongCounts[artist] ?? 0;

                        return ListTile(
                          dense: true,
                          title: Text(
                            artist,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '$songCount song${songCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
                            size: 16,
                          ),
                          onTap: () {
                            widget.onArtistSelected(artist);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
