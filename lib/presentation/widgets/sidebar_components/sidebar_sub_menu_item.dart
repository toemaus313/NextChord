import 'package:flutter/material.dart';

/// Reusable sub-menu item widget for sidebar
class SidebarSubMenuItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  const SidebarSubMenuItem({
    Key? key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final verticalPadding = isIOS ? 12.0 : 8.0;
    final fontSize = isIOS ? 13.0 : 12.0;

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
                  fontSize: fontSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (count != null)
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
