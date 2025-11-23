import 'package:flutter/material.dart';

/// **Concise Modal Template** - Standard for all compact, efficient modals
///
/// **Design Principles:**
/// - Maximize information density while maintaining readability
/// - Reduce visual clutter with smaller elements and tighter spacing
/// - Maintain consistent interaction patterns across all modals
///
/// **Concise Modal Design Standard:**
/// - maxWidth: 420, maxHeight: 500 (30% smaller than standard)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 18, Shadow: blurRadius 15, offset (0, 8)
/// - Text: Primary white (12-14px), secondary white60, borders white20
/// - Buttons: 30% narrower, 20% taller, padding (15, 14), fontSize 12
/// - Spacing: 4px between sections, 10px padding (reduced)
/// - Row heights: 36px standard for compact layout
/// - Icons: 16px standard (reduced from 20px)
abstract class ConciseModalTemplate extends StatefulWidget {
  const ConciseModalTemplate({Key? key}) : super(key: key);

  /// Show the modal with consistent styling
  static Future<T?> showConciseModal<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420, // Reduced from 480
            minWidth: 280, // Reduced from 320
            maxHeight: 500, // Reduced from 650
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0468cc), Color.fromARGB(150, 3, 73, 153)],
              ),
              borderRadius: BorderRadius.circular(18), // Reduced from 22
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80), // Reduced opacity
                  blurRadius: 15, // Reduced from 20
                  offset: const Offset(0, 8), // Reduced from (0, 10)
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(
                12, 10, 12, 10), // Reduced from 18,16,18,14
            child: child,
          ),
        ),
      ),
    );
  }

  /// Build the modal header with consistent styling
  static Widget buildConciseHeader({
    required BuildContext context,
    required String title,
    required VoidCallback onCancel,
    required VoidCallback onOk,
    bool okEnabled = true,
  }) {
    return Row(
      children: [
        // Cancel button - 30% narrower, 20% taller
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 15, vertical: 14), // Changed from 21,11
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('Cancel',
              style: TextStyle(fontSize: 12)), // Reduced from 14
        ),
        const Spacer(),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14, // Reduced from 16
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // OK button - 30% narrower, 20% taller
        TextButton(
          onPressed: okEnabled ? onOk : null,
          style: TextButton.styleFrom(
            foregroundColor: okEnabled ? Colors.white : Colors.white54,
            padding: const EdgeInsets.symmetric(
                horizontal: 15, vertical: 14), // Changed from 21,11
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: okEnabled ? Colors.white24 : Colors.white12,
              ),
            ),
          ),
          child: const Text('OK',
              style: TextStyle(fontSize: 12)), // Reduced from 14
        ),
      ],
    );
  }

  /// Build a concise setting row with consistent styling
  static Widget buildConciseSettingRow({
    required IconData icon,
    required String label,
    required Widget control,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced from 12
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        crossAxisAlignment: alignment,
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 16, // Reduced from 20
          ),
          const SizedBox(width: 8), // Reduced from 12
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Reduced from 14
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          control,
        ],
      ),
    );
  }

  /// Build a concise setting column for multi-line content
  static Widget buildConciseSettingColumn({
    required IconData icon,
    required String label,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced from 12
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white70,
                size: 16, // Reduced from 20
              ),
              const SizedBox(width: 8), // Reduced from 12
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12, // Reduced from 14
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4), // Reduced from 8
          ...children,
        ],
      ),
    );
  }

  /// Build a concise dropdown with consistent styling
  static Widget buildConciseDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool isExpanded = false,
  }) {
    return Container(
      // Reduce container height to make dropdown appear smaller
      height: 32, // Fixed height to make dropdown more compact
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(4), // Further reduced from 6
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: isExpanded,
          // Further reduced padding: from (4, 1) to (2, 0)
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
          dropdownColor: const Color(0xFF0468cc),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12), // Increased from 10 for better readability
          items: items,
          onChanged: onChanged,
          // Keep itemHeight at null to use default (48px) to meet kMinInteractiveDimension
          // but reduce visual density through tighter container styling
          menuMaxHeight: 180, // Further reduced from 200
          // Further reduce dropdown icon
          iconSize: 14, // Further reduced from 16
          // Reduce dropdown menu item styling
          selectedItemBuilder: (BuildContext context) {
            return items.map((DropdownMenuItem<T> item) {
              return Container(
                // Custom selected item styling to appear smaller
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minHeight: 32),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12, // Increased from 10 for better readability
                  ),
                  child: item.child,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  /// Build a concise text field with consistent styling
  static Widget buildConciseTextField({
    required TextEditingController controller,
    String? hintText,
    String? errorText,
    ValueChanged<String>? onChanged,
    void Function(String)? onSubmitted,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      style:
          const TextStyle(color: Colors.white, fontSize: 12), // Reduced from 14
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5), // Reduced from 0.6
          fontSize: 10, // Reduced from 12
        ),
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), // Reduced from 8
          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), // Reduced from 8
          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), // Reduced from 8
          borderSide: const BorderSide(color: Color(0xFF0468cc)),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6), // Reduced from 12,8
        errorText: errorText,
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }

  /// Build a concise button with consistent styling
  static Widget buildConciseButton({
    required String label,
    required Function()? onPressed,
    IconData? icon,
    bool enabled = true,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon != null
            ? Icon(icon, size: 12)
            : const SizedBox.shrink(), // Reduced from 14
        label: Text(
          label,
          style: TextStyle(fontSize: 12), // Reduced from 14
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? (backgroundColor ?? Colors.white.withAlpha(20))
              : Colors.white.withAlpha(10),
          foregroundColor:
              enabled ? (foregroundColor ?? Colors.white) : Colors.white54,
          padding: const EdgeInsets.symmetric(vertical: 6), // Reduced from 8
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6), // Reduced from 8
            side: BorderSide(
              color: enabled ? Colors.white24 : Colors.white12,
            ),
          ),
        ),
      ),
    );
  }

  /// Build a concise info/status box
  static Widget buildConciseInfoBox({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced from 12
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16), // Reduced from 20
          const SizedBox(width: 8), // Reduced from 12
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10, // Reduced from 12
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Standard spacing constants for concise modals
  static const double smallSpacing = 4.0; // Reduced from 8
  static const double mediumSpacing = 6.0; // Reduced from 12
  static const double largeSpacing = 10.0; // Reduced from 16

  /// Standard text styles for concise modals
  static const TextStyle primaryTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 12, // Reduced from 14
    fontWeight: FontWeight.w500,
  );

  static const TextStyle secondaryTextStyle = TextStyle(
    color: Colors.white70,
    fontSize: 10, // Reduced from 12
    fontWeight: FontWeight.w400,
  );

  static const TextStyle hintTextStyle = TextStyle(
    color: Colors.white38,
    fontSize: 10, // Reduced from 12
  );

  /// Standard icon size for concise modals
  static const double iconSize = 16.0; // Reduced from 20

  /// Standard container decoration for concise modals
  static BoxDecoration containerDecoration = BoxDecoration(
    color: Colors.white.withAlpha(10),
    borderRadius: BorderRadius.circular(12), // Reduced from 16
    border: Border.all(color: Colors.white.withAlpha(30)),
  );
}

/// Mixin for concise modal content widgets
mixin ConciseModalContentMixin {
  /// Build the main content area with consistent spacing
  Widget buildConciseContent({
    required List<Widget> children,
    bool scrollable = true,
  }) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: ConciseModalTemplate.smallSpacing),
          content,
          const SizedBox(height: ConciseModalTemplate.smallSpacing),
        ],
      ),
    );
  }

  /// Add consistent spacing between sections
  List<Widget> addConciseSpacing(List<Widget> children) {
    final spacedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren
            .add(const SizedBox(height: ConciseModalTemplate.mediumSpacing));
      }
    }
    return spacedChildren;
  }
}
