import 'package:flutter/material.dart';

/// Header widget for sidebar sections - matches mobile design with left-side back button
class SidebarHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onClose;

  const SidebarHeader({
    Key? key,
    required this.title,
    required this.icon,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60, // Match mobile header height
      padding: EdgeInsets.symmetric(
        horizontal: onClose != null ? 16 : 16, // Consistent padding
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(20),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withAlpha(12),
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Back button on the left (matching mobile design)
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white70,
                size: 24, // Match mobile size
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 0),

          const SizedBox(width: 12),

          // Icon
          Icon(
            icon,
            color: Colors.white70,
            size: 20,
          ),

          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20, // Slightly larger on desktop/tablet
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          // Spacer on the right (matching mobile design)
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
