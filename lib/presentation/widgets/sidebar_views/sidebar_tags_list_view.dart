import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../screens/song_editor_screen_refactored.dart';
import '../sidebar_components/sidebar_header.dart';
import '../standard_wide_button.dart';

/// Tags list view for the sidebar
class SidebarTagsListView extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String) onTagSelected;
  final bool showHeader;

  const SidebarTagsListView({
    Key? key,
    required this.onBack,
    required this.onTagSelected,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarTagsListView> createState() => _SidebarTagsListViewState();
}

class _SidebarTagsListViewState extends State<SidebarTagsListView> {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, provider, child) {
        // Get unique tags
        final tags = <String>{};
        final tagSongCounts = <String, int>{};

        for (final song in provider.songs) {
          for (final tag in song.tags) {
            if (tag.isNotEmpty) {
              tags.add(tag);
              tagSongCounts[tag] = (tagSongCounts[tag] ?? 0) + 1;
            }
          }
        }

        final sortedTags = tags.toList()..sort();

        return Column(
          children: [
            // Only show header if not on mobile (mobile has its own header)
            if (widget.showHeader)
              SidebarHeader(
                title: 'Tags',
                icon: Icons.tag,
                onClose: widget.onBack,
              ),
            Expanded(
              child: sortedTags.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tag,
                            size: 48,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No tags found',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add tags to songs to see them here',
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
                      itemCount: sortedTags.length,
                      itemBuilder: (context, index) {
                        final tag = sortedTags[index];
                        final songCount = tagSongCounts[tag] ?? 0;

                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.tag,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            tag,
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
                            widget.onTagSelected(tag);
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
