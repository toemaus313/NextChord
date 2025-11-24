import 'package:flutter/material.dart';

/// Consistent mobile sidebar header with fixed height and positioning
class MobileSidebarHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;

  const MobileSidebarHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actions,
    this.leading,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60, // Fixed height for consistent positioning
      padding: EdgeInsets.symmetric(
        horizontal:
            onBack != null ? 16 : 4, // Minimal padding when no back button
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
      ),
      child: Row(
        children: [
          // Leading widget or back button
          if (leading != null)
            leading!
          else if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white70,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(
                width:
                    0), // No spacer when no back button (true left alignment)

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
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),

          // Actions
          if (actions != null) ...[
            const SizedBox(width: 8),
            ...actions!,
          ] else
            const SizedBox(width: 40), // Spacer when no actions
        ],
      ),
    );
  }
}
