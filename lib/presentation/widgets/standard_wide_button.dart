import 'package:flutter/material.dart';

/// Standard wide button widget for consistent button styling across the app
/// Based on the Edit Setlist button design from sidebar views
class StandardWideButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;

  const StandardWideButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.icon,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(20),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 36),
        disabledBackgroundColor: Colors.white.withAlpha(10),
        disabledForegroundColor: Colors.white.withAlpha(50),
      ),
    );
  }
}
