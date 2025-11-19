import 'package:flutter/material.dart';
import '../providers/song_provider.dart';

/// Compact "Select All" bar used in sidebar song lists
class SidebarSelectAllBar extends StatelessWidget {
  const SidebarSelectAllBar({
    super.key,
    required this.provider,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.backgroundColor,
    this.dividerColor,
    this.textColor,
    this.secondaryTextColor,
    this.checkboxScale = 0.78,
  });

  final SongProvider provider;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? dividerColor;
  final Color? textColor;
  final Color? secondaryTextColor;
  final double checkboxScale;

  @override
  Widget build(BuildContext context) {
    final baseTextColor = textColor ?? Colors.white;
    final secondaryColor = secondaryTextColor ?? Colors.white.withValues(alpha: 0.7);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: dividerColor ?? Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: checkboxScale,
            child: Checkbox(
              value: provider.isAllSelected,
              onChanged: (_) {
                provider.toggleSelectAll();
              },
              fillColor: WidgetStateProperty.all(Colors.white),
              checkColor: Colors.black,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            provider.isAllSelected ? 'Deselect All' : 'Select All',
            style: TextStyle(
              color: baseTextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${provider.selectedSongIds.length} of ${provider.songs.length}',
            style: TextStyle(
              color: secondaryColor,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
