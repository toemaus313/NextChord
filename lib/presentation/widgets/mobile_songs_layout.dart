import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../screens/song_editor_screen_refactored.dart';
import 'standard_wide_button.dart';

/// Reusable mobile layout for song lists with search and add buttons
/// Used by All Songs, Artists, and Tags views to maintain consistency
class MobileSongsLayout extends StatefulWidget {
  final Widget child;
  final String searchHint;
  final VoidCallback? onAddSong;

  const MobileSongsLayout({
    Key? key,
    required this.child,
    this.searchHint = 'Song, tag or artist',
    this.onAddSong,
  }) : super(key: key);

  @override
  State<MobileSongsLayout> createState() => _MobileSongsLayoutState();
}

class _MobileSongsLayoutState extends State<MobileSongsLayout> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Column(
          children: [
            // Song list with bottom padding for search bar + button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom: 120), // Space for search bar + button
                child: widget.child,
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
                hintText: widget.searchHint,
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
                          context.read<SongProvider>().searchSongs('');
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
                context.read<SongProvider>().searchSongs(value);
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
            label: '+ Add Songs',
            icon: Icons.add,
            onPressed: widget.onAddSong ??
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SongEditorScreenRefactored(),
                    ),
                  );
                  if (result == true && context.mounted) {
                    context.read<SongProvider>().loadSongs();
                  }
                },
          ),
        ),
      ],
    );
  }
}
