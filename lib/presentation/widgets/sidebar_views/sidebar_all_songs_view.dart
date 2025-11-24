import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/global_sidebar_provider.dart';
import '../../providers/song_provider.dart';
import '../../screens/library_screen.dart';
import '../bottom_search_bar.dart';
import '../sidebar_components/sidebar_header.dart';
import '../standard_wide_button.dart';
import '../../../core/widgets/responsive_config.dart';
import '../../../core/utils/device_breakpoints.dart';
import '../../screens/song_editor_screen_refactored.dart';

/// All songs view for the sidebar
class SidebarAllSongsView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onAddSong;
  final bool showHeader;

  const SidebarAllSongsView({
    Key? key,
    required this.onBack,
    required this.onAddSong,
    this.showHeader = true,
  }) : super(key: key);

  @override
  State<SidebarAllSongsView> createState() => _SidebarAllSongsViewState();
}

class _SidebarAllSongsViewState extends State<SidebarAllSongsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = ResponsiveConfig.isPhone(context);

    if (isPhone) {
      // Mobile layout with Stack for proper bottom positioning
      return Stack(
        children: [
          // Main content
          Column(
            children: [
              // Select Songs button just below Global Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer<SongProvider>(
                  builder: (context, provider, child) {
                    return StandardWideButton(
                      label: provider.selectionMode
                          ? 'Cancel Selection'
                          : 'Select Songs',
                      icon: provider.selectionMode
                          ? Icons.close
                          : Icons.checklist,
                      onPressed: () {
                        provider.toggleSelectionMode();
                      },
                    );
                  },
                ),
              ),
              // Song list with bottom padding for search bar + button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 120), // Space for search bar + button
                  child: LibraryScreen(
                    inSidebar: true,
                    onSongSelected: (song) {
                      context
                          .read<GlobalSidebarProvider>()
                          .navigateToSongWithPhoneMode(song);
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
                  hintText: 'Song, tag or artist',
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
              label: 'Add Song',
              icon: Icons.add,
              onPressed: () async {
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

    // Desktop/Tablet layout (unchanged)
    return ResponsiveSearchWrapper(
      searchHintText: 'Song, tag or artist',
      searchController: _searchController,
      onSearchChanged: (value) {
        context.read<SongProvider>().searchSongs(value);
      },
      onSearchClear: () {
        _searchController.clear();
        context.read<SongProvider>().searchSongs('');
      },
      showSearchBar: isPhone,
      child: Column(
        children: [
          // Only show header if not on mobile (mobile has its own header)
          if (widget.showHeader)
            SidebarHeader(
              title: 'All Songs',
              icon: Icons.music_note,
              onClose: () {
                context.read<SongProvider>().resetSelectionMode();
                _searchController.clear();
                context.read<SongProvider>().searchSongs('');
                widget.onBack();
              },
            ),
          // Only show desktop search bar on desktop/tablet
          if (!isPhone) ...[
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
                  hintText: 'Song, tag or artist',
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
                            context.read<SongProvider>().searchSongs('');
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
                  context.read<SongProvider>().searchSongs(value);
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Select Songs button at the top (matching mobile layout)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<SongProvider>(
              builder: (context, provider, child) {
                return StandardWideButton(
                  label: provider.selectionMode
                      ? 'Cancel Selection'
                      : 'Select Songs',
                  icon: provider.selectionMode ? Icons.close : Icons.checklist,
                  onPressed: () {
                    provider.toggleSelectionMode();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LibraryScreen(
              inSidebar: true,
              onSongSelected: (song) {
                context
                    .read<GlobalSidebarProvider>()
                    .navigateToSongWithPhoneMode(song);
              },
            ),
          ),
          // Add Songs button at the bottom (matching mobile layout)
          Padding(
            padding: const EdgeInsets.all(16),
            child: StandardWideButton(
              label: 'Add Song',
              icon: Icons.add,
              onPressed: () async {
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
      ),
    );
  }
}
