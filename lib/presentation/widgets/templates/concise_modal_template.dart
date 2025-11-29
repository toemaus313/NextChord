import 'package:flutter/material.dart';
import 'package:nextchord/main.dart' as main;
import '../../../core/widgets/responsive_config.dart';
import '../../providers/appearance_provider.dart';

/// Mixin for modal content with consistent styling and spacing
mixin ConciseModalContentMixin<T extends StatefulWidget> on State<T> {
  /// Build content with consistent padding and styling
  Widget buildConciseContent({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16), // Only bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// Add consistent spacing between widget items
  List<Widget> addConciseSpacing(List<Widget> items) {
    final List<Widget> spacedItems = [];
    for (int i = 0; i < items.length; i++) {
      spacedItems.add(items[i]);
      if (i < items.length - 1) {
        spacedItems.add(const SizedBox(height: 8)); // Standard spacing
      }
    }
    return spacedItems;
  }
}

/// **Concise Modal Template** - Standard for all compact, efficient modals
///
/// **Design Principles:**
/// - Maximize information density while maintaining readability
/// - Reduce visual clutter with smaller elements and tighter spacing
/// - Maintain consistent interaction patterns across all modals
///
/// **Concise Modal Design Standard:**
/// - maxWidth: 480, maxHeight: 650 (matching MIDI Profiles modal)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white (12-14px), secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
/// - Row heights: 40px standard for layout
/// - Icons: 20px standard
abstract class ConciseModalTemplate extends StatefulWidget {
  const ConciseModalTemplate({Key? key}) : super(key: key);

  /// Show the modal with responsive behavior
  /// - Phone: Full-screen dialog with back navigation
  /// - Desktop/Tablet: Compact modal dialog
  static Future<T?> showConciseModal<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = false,
    AppearanceProvider? appearanceProvider,
  }) {
    main.myDebug(
        '[ConciseModalTemplate] showConciseModal: child=${child.runtimeType}, barrierDismissible=$barrierDismissible');
    final isPhone = ResponsiveConfig.isPhone(context);

    // Get gradient colors from appearance provider or use defaults
    final gradientStart =
        appearanceProvider?.gradientStart ?? const Color(0xFF0468cc);
    final gradientEnd = appearanceProvider?.gradientEnd ??
        const Color.fromARGB(150, 3, 73, 153);

    // Use a single dialog implementation for all form factors.
    // On phones, make the dialog effectively full-screen by removing insets
    // and expanding constraints to the available screen size.
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final insetPadding = isPhone ? EdgeInsets.zero : const EdgeInsets.all(24.0);

    // Desktop/Tablet: make the modal about 10% wider than the original 480px
    final maxWidth = isPhone ? screenSize.width : 528.0;
    final minWidth = isPhone ? screenSize.width : 350.0;
    final maxHeight = isPhone ? screenSize.height : 650.0;

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: insetPadding,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minWidth: minWidth,
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            borderRadius:
                BorderRadius.circular(22), // Matching MIDI Profiles modal
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51), // Standard opacity
                blurRadius: 20, // Matching MIDI Profiles modal
                offset: const Offset(0, 10), // Matching MIDI Profiles modal
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Cancel/Save buttons (matching MIDI Profiles structure)
              Container(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ],
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
      mainAxisSize:
          MainAxisSize.max, // Take full width to avoid unbounded constraints
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Cancel button - matching MIDI Profiles modal styling
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('Cancel'),
        ),
        // Title - matching MIDI Profiles modal
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.6, // Reduced by 15% from 16
            fontWeight: FontWeight.w600,
          ),
        ),
        // OK button - matching MIDI Profiles modal styling
        TextButton(
          onPressed: okEnabled ? onOk : null,
          style: TextButton.styleFrom(
            foregroundColor: okEnabled ? Colors.white : Colors.white24,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }

  /// Build a concise setting row with label and control
  static Widget buildConciseSettingRow({
    IconData? icon,
    required String label,
    required Widget control,
    String? description,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 6), // Standard vertical padding
      child: Row(
        children: [
          // Icon section (if provided)
          if (icon != null) ...[
            Icon(
              icon,
              color: Colors.white70,
              size: 20, // Standard icon size
            ),
            const SizedBox(width: 12), // Standard spacing
          ],
          // Label section - natural sizing without Expanded
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14, // Standard font size
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4), // Standard spacing
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withAlpha(179), // white70
                    fontSize: 12, // Standard font size
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          const SizedBox(width: 16), // Fixed spacing instead of Spacer
          // Control section - let control manage its own constraints
          control,
        ],
      ),
    );
  }

  /// Build a concise dropdown with consistent styling
  static Widget buildConciseDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    bool isExpanded = true,
  }) {
    return SizedBox(
      width: 160, // Fixed width to provide bounded constraints
      height: 40, // Standard height for consistency
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12), // Standard padding
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(32), // Slightly more opaque
          borderRadius: BorderRadius.circular(8), // Standard border radius
          border: Border.all(
            color: Colors.white.withAlpha(60), // white24
            width: 1,
          ),
        ),
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: hint != null
              ? Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white.withAlpha(179), // white70
                    fontSize: 12, // Standard font size
                  ),
                )
              : null,
          isExpanded: true,
          dropdownColor: const Color(0xFF0468cc),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12, // Standard font size
          ),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Colors.white70,
            size: 20, // Standard icon size
          ),
          underline: const SizedBox(), // Remove underline
        ),
      ),
    );
  }

  /// Build a concise setting column (vertical layout)
  static Widget buildConciseSettingColumn({
    IconData? icon,
    required String label,
    required List<Widget> children,
    String? description,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 6), // Standard vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: Colors.white70,
                  size: 20, // Standard icon size
                ),
                const SizedBox(width: 12), // Standard spacing
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14, // Standard font size
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4), // Standard spacing
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withAlpha(179), // white70
                fontSize: 12, // Standard font size
              ),
            ),
          ],
          const SizedBox(height: 8), // Standard spacing
          ...children,
        ],
      ),
    );
  }

  /// Build a concise text field with consistent styling
  static Widget buildConciseTextField({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
    String? errorText,
  }) {
    return Container(
      height: 40, // Standard height for consistency
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(32), // Slightly more opaque
        borderRadius: BorderRadius.circular(8), // Standard border radius
        border: Border.all(
          color: Colors.white.withAlpha(60), // white24
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12, // Standard font size
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          errorText: errorText,
          labelStyle: TextStyle(
            color: Colors.white.withAlpha(179), // white70
            fontSize: 12, // Standard font size
          ),
          hintStyle: TextStyle(
            color: Colors.white.withAlpha(153), // white60
            fontSize: 12, // Standard font size
          ),
          errorStyle: const TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10, // Standard vertical padding
          ),
        ),
      ),
    );
  }

  /// Build a concise button with consistent styling
  static Widget buildConciseButton({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool enabled = true,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isDestructive = false,
  }) {
    return SizedBox(
      height: 40, // Standard height for consistency
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: (enabled ? backgroundColor : Colors.transparent) ??
              (isDestructive
                  ? Colors.red.withAlpha(51) // red12
                  : Colors.white.withAlpha(32)), // Slightly more opaque
          foregroundColor: foregroundColor ??
              (isDestructive ? Colors.red.shade300 : Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(fontSize: 12), // Standard font size
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Standard border radius
            side: isDestructive
                ? BorderSide(color: Colors.red.withAlpha(102)) // red40
                : BorderSide(color: Colors.white.withAlpha(60)), // white24
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.max, // Use max to avoid unbounded constraints
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20), // Standard icon size
              const SizedBox(width: 8), // Standard spacing
            ],
            Text(label),
          ],
        ),
      ),
    );
  }

  /// Build a concise info box with consistent styling
  static Widget buildConciseInfoBox({
    required String text,
    IconData? icon,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // Standard padding
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16), // Slightly more opaque
        borderRadius: BorderRadius.circular(8), // Standard border radius
        border: Border.all(
          color: Colors.white.withAlpha(60), // white24
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: color ?? Colors.white70,
              size: 20, // Standard icon size
            ),
            const SizedBox(width: 12), // Standard spacing
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Standard font size
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Spacing constants for consistent layout
  static const double smallSpacing = 8.0; // Standard spacing
  static const double mediumSpacing = 12.0; // Standard spacing
  static const double largeSpacing = 16.0; // Standard spacing

  // Text styles for consistent typography
  static const TextStyle primaryTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14, // Standard font size
    fontWeight: FontWeight.w500,
  );

  static const TextStyle secondaryTextStyle = TextStyle(
    color: Colors.white70, // white70
    fontSize: 12, // Standard font size
  );

  @override
  State<ConciseModalTemplate> createState() => _ConciseModalTemplateState();
}

class _ConciseModalTemplateState extends State<ConciseModalTemplate> {
  @override
  Widget build(BuildContext context) {
    // This is an abstract template class - actual implementation
    // should be provided by concrete subclasses
    throw UnimplementedError(
      'ConciseModalTemplate is abstract and should not be instantiated directly',
    );
  }
}
