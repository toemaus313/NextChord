import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../screens/song_editor_screen_refactored.dart';
import '../sidebar_components/sidebar_header.dart';
import '../standard_wide_button.dart';
import '../../../core/widgets/responsive_config.dart';
import '../../../core/utils/device_breakpoints.dart';

/// Artists list view for the sidebar
class SidebarArtistsListView extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String) onArtistSelected;
  final bool showHeader;

  const SidebarArtistsListView({
    Key? key,
    required this.onBack,
    required this.onArtistSelected,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarArtistsListView> createState() => _SidebarArtistsListViewState();
}

class _SidebarArtistsListViewState extends State<SidebarArtistsListView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleAddSong(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SongEditorScreenRefactored(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await context.read<SongProvider>().loadSongs();
    }
  }

  List<String> _filterArtists(List<String> artists, String query) {
    if (query.isEmpty) return artists;
    return artists
        .where((artist) => artist.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = ResponsiveConfig.isPhone(context);

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

        final allArtists = artists.toList()..sort();
        final filteredArtists =
            _filterArtists(allArtists, _searchController.text);

        if (isPhone) {
          // Mobile layout with Stack for proper bottom positioning
          return Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Only show header if not on mobile (mobile has its own header)
                  if (widget.showHeader)
                    SidebarHeader(
                      title: 'Artists',
                      icon: Icons.person_outline,
                      onClose: widget.onBack,
                    ),
                  // Artists list with bottom padding for search bar + button
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          bottom: 120), // Space for search bar + button
                      child: filteredArtists.isEmpty
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
                              itemCount: filteredArtists.length,
                              itemBuilder: (context, index) {
                                final artist = filteredArtists[index];
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
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
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
                  ),
                ],
              ),

              // Transparent search bar overlay (just above button)
              Positioned(
                bottom: 60, // Above the button
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search artists',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white70,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
              ),

              // Fixed bottom Add Songs button
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: StandardWideButton(
                  label: 'Add Song',
                  icon: Icons.add,
                  onPressed: () => _handleAddSong(context),
                ),
              ),
            ],
          );
        }

        // Desktop/Tablet layout
        return Column(
          children: [
            // Only show header if not on mobile (mobile has its own header)
            if (widget.showHeader)
              SidebarHeader(
                title: 'Artists',
                icon: Icons.person_outline,
                onClose: widget.onBack,
              ),
            // Desktop search bar
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                    color: Colors.white,
                    fontSize:
                        DeviceBreakpoints.getResponsiveTextSize(context, 12)),
                decoration: InputDecoration(
                  hintText: 'Search artists',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize:
                          DeviceBreakpoints.getResponsiveTextSize(context, 12)),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white70, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.white70, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredArtists.isEmpty
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
                      itemCount: filteredArtists.length,
                      itemBuilder: (context, index) {
                        final artist = filteredArtists[index];
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: StandardWideButton(
                label: 'Add Song',
                icon: Icons.add,
                onPressed: () => _handleAddSong(context),
              ),
            ),
          ],
        );
      },
    );
  }
}
