import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../providers/global_sidebar_provider.dart';
import '../sidebar_components/sidebar_header.dart';

/// Tag songs view for the sidebar
class SidebarTagSongsView extends StatefulWidget {
  final String tag;
  final VoidCallback onBack;
  final bool showHeader;

  const SidebarTagSongsView({
    Key? key,
    required this.tag,
    required this.onBack,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarTagSongsView> createState() => _SidebarTagSongsViewState();
}

class _SidebarTagSongsViewState extends State<SidebarTagSongsView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        // Get songs with this tag
        final tagSongs = provider.songs
            .where((song) => song.tags.contains(widget.tag))
            .toList();

        return Column(
          children: [
            // Only show header if not on mobile (mobile has its own header)
            if (widget.showHeader)
              SidebarHeader(
                title: '#${widget.tag}',
                icon: Icons.tag,
                onClose: widget.onBack,
              ),
            Expanded(
              child: tagSongs.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: tagSongs.length,
                      itemBuilder: (context, index) {
                        final song = tagSongs[index];

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              song.title.isNotEmpty
                                  ? song.title[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: song.artist.isNotEmpty
                              ? Text(
                                  song.artist,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          onTap: () {
                            // Navigate to song
                            Provider.of<GlobalSidebarProvider>(context,
                                    listen: false)
                                .navigateToSong(song);
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
