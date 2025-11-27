import 'package:flutter/material.dart';

/// Reusable sub-menu item widget for sidebar
class SidebarSubMenuItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final bool isPhoneMode;

  const SidebarSubMenuItem({
    Key? key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.isPhoneMode = false,
  }) : super(key: key);

  /// Helper method for responsive text sizing (1.8x scaling on phones)
  double _getResponsiveTextSize(double baseSize) {
    // On phones, keep strong scaling; on desktop/tablet, make text ~15% larger
    return isPhoneMode ? baseSize * 1.8 : baseSize * 1.5;
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final verticalPadding = isIOS ? 12.0 : 8.0;
    final baseFontSize = isIOS ? 13.0 : 12.0;
    final responsiveFontSize = _getResponsiveTextSize(baseFontSize);
    final responsiveCountSize = _getResponsiveTextSize(10.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: 44,
          right: 16,
          top: verticalPadding,
          bottom: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsiveFontSize,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (count != null)
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: responsiveCountSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
