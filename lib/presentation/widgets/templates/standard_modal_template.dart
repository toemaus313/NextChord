import 'package:flutter/material.dart';

/// **Standard Modal Template** - Based on MIDI Profiles Modal Design
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class StandardModalTemplate {
  /// Show a standard modal dialog matching MIDI Profiles design
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  /// Build the modal container with standard styling
  static Widget buildModalContainer({
    required BuildContext context,
    required Widget child,
    double? maxHeight,
  }) {
    // Calculate available screen height with padding
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 48; // Account for dialog padding
    final effectiveMaxHeight =
        maxHeight ?? (availableHeight < 650 ? availableHeight : 650.0);

    return Container(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: effectiveMaxHeight,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0468cc),
            Color.fromARGB(150, 3, 73, 153),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Build the standard header with Cancel/OK buttons and title
  static Widget buildHeader({
    required BuildContext context,
    required String title,
    required VoidCallback onCancel,
    required VoidCallback onOk,
    bool okEnabled = true,
    String cancelLabel = 'Cancel',
    String okLabel = 'OK',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Cancel button (upper left)
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            child: Text(cancelLabel, style: const TextStyle(fontSize: 14)),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.6, // Reduced by 15% from 16
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // OK button (upper right) to balance layout and center title
          TextButton(
            onPressed: okEnabled ? onOk : null,
            style: TextButton.styleFrom(
              foregroundColor: okEnabled ? Colors.white : Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            child: Text(okLabel, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// Build the content area with standard padding
  static Widget buildContent({
    required List<Widget> children,
  }) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  /// Standard spacing between sections
  static Widget spacing({double height = 8}) => SizedBox(height: height);

  /// Build a standard setting row with icon, label, and control
  static Widget buildSettingRow({
    IconData? icon,
    required String label,
    required Widget control,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        control,
      ],
    );
  }

  /// Build a standard dropdown
  static Widget buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        dropdownColor: const Color(0xFF0468cc),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        icon:
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
        underline: const SizedBox(),
      ),
    );
  }

  /// Build a standard text field
  static Widget buildTextField({
    required TextEditingController controller,
    String? hintText,
    String? errorText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          errorText: errorText,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Build a standard button
  static Widget buildButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive
              ? Colors.red.withAlpha(100)
              : Colors.white.withAlpha(20),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white24),
          ),
        ),
      ),
    );
  }

  /// Build a standard info box
  static Widget buildInfoBox({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
