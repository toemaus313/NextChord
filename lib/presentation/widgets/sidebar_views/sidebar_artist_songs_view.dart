import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/global_sidebar_provider.dart';
import '../sidebar_components/sidebar_header.dart';

/// Artist songs view for the sidebar
class SidebarArtistSongsView extends StatefulWidget {
  final String artist;
  final VoidCallback onBack;
  final bool showHeader;

  const SidebarArtistSongsView({
    Key? key,
    required this.artist,
    required this.onBack,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarArtistSongsView> createState() => _SidebarArtistSongsViewState();
}

class _SidebarArtistSongsViewState extends State<SidebarArtistSongsView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        // Get songs for this artist
        final artistSongs = provider.songs
            .where((song) => song.artist == widget.artist)
            .toList();

        return Column(
          children: [
            // Only show header if not on mobile (mobile has its own header)
            if (widget.showHeader)
              SidebarHeader(
                title: widget.artist,
                icon: Icons.person,
                onClose: widget.onBack,
              ),
            Expanded(
              child: artistSongs.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: artistSongs.length,
                      itemBuilder: (context, index) {
                        final song = artistSongs[index];

                        return ListTile(
                          dense: true,
                          title: Text(
                            song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: song.key.isNotEmpty
                              ? Text(
                                  'Key: ${song.key}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          onTap: () {
                            // Navigate to song with phone mode support
                            context
                                .read<GlobalSidebarProvider>()
                                .navigateToSongWithPhoneMode(song);
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
