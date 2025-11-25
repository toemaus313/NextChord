import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/song_viewer_constants.dart';
import '../../providers/global_sidebar_provider.dart';
import '../../providers/autoscroll_provider.dart';
import '../../providers/song_viewer_provider.dart';
import '../transpose_button.dart';
import '../capo_button.dart';
import '../autoscroll_button.dart';
import '../metronome_button.dart';

/// Floating UI overlay for the song viewer screen
///
/// Contains sidebar toggle, action buttons, and adjustment controls
/// positioned around the main content area.
class SongViewerFloatingUI extends StatelessWidget {
  final bool isPhone;
  final bool isDarkMode;
  final Color textColor;
  final VoidCallback onDeleteSong;
  final VoidCallback onEditSong;
  final SongViewerProvider viewerProvider;

  const SongViewerFloatingUI({
    Key? key,
    required this.isPhone,
    required this.isDarkMode,
    required this.textColor,
    required this.onDeleteSong,
    required this.onEditSong,
    required this.viewerProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sidebar toggle button - only show on desktop/tablet
        if (!isPhone)
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: Icon(Icons.menu, color: textColor, size: 28),
              onPressed: () =>
                  context.read<GlobalSidebarProvider>().toggleSidebar(),
              tooltip: 'Toggle sidebar',
            ),
          ),
        // Top right buttons - only show on desktop/tablet
        if (!isPhone)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Share button
                IconButton(
                  icon: Icon(
                    Icons.share,
                    color: isDarkMode
                        ? SongViewerConstants.darkModeAccent
                        : SongViewerConstants.lightModeAccent,
                    size: 28,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Share functionality coming soon!')),
                    );
                  },
                  tooltip: 'Share song',
                ),
                const SizedBox(width: 8),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                  onPressed: onDeleteSong,
                  tooltip: 'Delete song',
                ),
                const SizedBox(width: 8),
                // Edit button
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: isDarkMode
                        ? SongViewerConstants.darkModeAccent
                        : SongViewerConstants.lightModeAccent,
                    size: 28,
                  ),
                  onPressed: onEditSong,
                  tooltip: 'Edit song',
                ),
              ],
            ),
          ),
        // Bottom right adjustment buttons
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSettingsFlyoutButton(context),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              TransposeButton(provider: viewerProvider),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              CapoButton(provider: viewerProvider),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              AutoscrollButton(
                autoscrollProvider: context.read<AutoscrollProvider>(),
                viewerProvider: viewerProvider,
              ),
              const SizedBox(height: SongViewerConstants.buttonSpacing),
              const MetronomeButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsFlyoutButton(BuildContext context) {
    final backgroundColor = isDarkMode
        ? const Color(0xFF0A0A0A).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    final accent = isDarkMode
        ? SongViewerConstants.darkModeAccent
        : SongViewerConstants.lightModeAccent;

    return IconButton(
      onPressed: () {
        viewerProvider.toggleFlyout(FlyoutType.settings);
      },
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: _buildFloatingShadows(),
        ),
        child: Center(
          child: Icon(
            Icons.settings,
            color: accent,
            size: 22,
          ),
        ),
      ),
      tooltip: 'Settings',
    );
  }

  List<BoxShadow> _buildFloatingShadows() {
    return isDarkMode
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ];
  }
}
