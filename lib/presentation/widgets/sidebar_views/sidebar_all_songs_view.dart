import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/global_sidebar_provider.dart';
import '../../providers/song_provider.dart';
import '../../screens/library_screen.dart';
import '../bottom_search_bar.dart';
import '../../../core/widgets/responsive_config.dart';
import '../../../core/utils/device_breakpoints.dart';

/// All songs view for the sidebar
class SidebarAllSongsView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onAddSong;

  const SidebarAllSongsView({
    Key? key,
    required this.onBack,
    required this.onAddSong,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(20),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All Songs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          DeviceBreakpoints.getResponsiveTextSize(context, 16),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white70,
                    size: 24, // Made bigger from 20
                  ),
                  onPressed: () {
                    context.read<SongProvider>().resetSelectionMode();
                    _searchController.clear();
                    context.read<SongProvider>().searchSongs('');
                    widget.onBack();
                  },
                  tooltip: 'Back to menu',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
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
          // Select Songs button
          Consumer<SongProvider>(
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    provider.toggleSelectionMode();
                  },
                  icon: Icon(
                      provider.selectionMode ? Icons.close : Icons.checklist,
                      size: 16),
                  label: Text(provider.selectionMode
                      ? 'Cancel Selection'
                      : 'Select Songs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: provider.selectionMode
                        ? Colors.red.withAlpha(20)
                        : Colors.white.withAlpha(20),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              );
            },
          ),
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
        ],
      ),
    );
  }
}
