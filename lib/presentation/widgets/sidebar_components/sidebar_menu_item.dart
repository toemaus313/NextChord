import 'package:flutter/material.dart';

/// Reusable menu item widget for sidebar
class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final List<Widget>? children;
  final bool isExpanded;
  final bool isPhoneMode;

  const SidebarMenuItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.children,
    this.isExpanded = false,
    this.isPhoneMode = false,
  }) : super(key: key);

  /// Helper method for responsive text sizing (1.8x scaling on phones)
  double _getResponsiveTextSize(double baseSize) {
    return isPhoneMode ? baseSize * 1.8 : baseSize;
  }

  /// Helper method for responsive icon sizing (1.3x scaling on phones)
  double _getResponsiveIconSize(double baseSize) {
    return isPhoneMode ? baseSize * 1.3 : baseSize;
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final verticalPadding = isIOS ? 18.0 : 14.0;
    final baseIconSize = isIOS ? 18.0 : 16.0;
    final responsiveIconSize = _getResponsiveIconSize(baseIconSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding:
                EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: responsiveIconSize,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getResponsiveTextSize(13.0),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (children != null)
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                    size: responsiveIconSize * 0.9,
                  ),
              ],
            ),
          ),
        ),
        if (children != null && isExpanded) ...children!,
      ],
    );
  }
}
