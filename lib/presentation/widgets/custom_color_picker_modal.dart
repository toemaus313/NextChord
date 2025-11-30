import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/appearance_provider.dart';
import 'templates/standard_modal_template.dart';

/// Custom Color Picker Modal - Responsive color picker using StandardModalTemplate
class CustomColorPickerModal extends StatefulWidget {
  final Color initialColor;

  const CustomColorPickerModal({
    Key? key,
    required this.initialColor,
  }) : super(key: key);

  /// Show the Custom Color Picker modal
  static Future<Color?> show(BuildContext context, Color initialColor) {
    return StandardModalTemplate.show<Color>(
      context: context,
      barrierDismissible: false,
      child: CustomColorPickerModal(initialColor: initialColor),
    );
  }

  @override
  State<CustomColorPickerModal> createState() => _CustomColorPickerModalState();
}

class _CustomColorPickerModalState extends State<CustomColorPickerModal> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppearanceProvider>(
      builder: (context, appearanceProvider, child) {
        return StandardModalTemplate.buildModalContainer(
          context: context,
          appearanceProvider: appearanceProvider,
          maxHeight: _getModalHeight(context),
          maxWidth: _getModalWidth(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StandardModalTemplate.buildHeader(
                context: context,
                title: 'Custom Color',
                onCancel: () => Navigator.of(context).pop(),
                onOk: () => Navigator.of(context).pop(_selectedColor),
              ),
              Expanded(
                child: Center(
                  child: _buildColorPicker(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getModalHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final orientation = mediaQuery.orientation;

    // Calculate available height accounting for dialog padding
    final availableHeight = screenSize.height - 48;

    // Determine if we're on a small screen (phone) or larger (tablet/desktop)
    final isSmallScreen = screenSize.width < 600;

    if (orientation == Orientation.landscape) {
      // In landscape, use more vertical space but constrain to reasonable limits (scaled down 15%)
      if (isSmallScreen) {
        // Phone landscape - use most available height (scaled down 15%)
        return availableHeight * 0.9 * 0.85;
      } else {
        // Tablet/Desktop landscape - compact height for small ColorPicker
        return 320.0; // Compact height for centered layout
      }
    } else {
      // Portrait mode
      if (isSmallScreen) {
        // Phone portrait - use a more compact portion of available height
        // so the modal does not become excessively tall
        return availableHeight * 0.55;
      } else {
        // Tablet/Desktop portrait - compact height for small ColorPicker
        return 360.0; // Compact height for centered layout
      }
    }
  }

  double _getModalWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final orientation = mediaQuery.orientation;

    // Calculate available screen width accounting for dialog padding
    final availableWidth = screenSize.width - 48;

    // Determine if we're on a small screen (phone) or larger (tablet/desktop)
    final isSmallScreen = screenSize.width < 600;

    if (orientation == Orientation.landscape) {
      // In landscape, we have more horizontal space
      if (isSmallScreen) {
        // Phone landscape - use most available width (scaled down 15%)
        return availableWidth * 0.95 * 0.85;
      } else {
        // Tablet/Desktop landscape - adequate width for ColorPicker
        return 500.0; // Wider modal for landscape orientation
      }
    } else {
      // Portrait mode
      if (isSmallScreen) {
        // Phone portrait - use most available width (scaled down 15%)
        return availableWidth * 0.9 * 0.85;
      } else {
        // Tablet/Desktop portrait - adequate width for ColorPicker
        return 500.0; // Wider modal for portrait orientation
      }
    }
  }

  Widget _buildColorPicker(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final orientation = mediaQuery.orientation;

    // Determine if we're on a small screen
    final isSmallScreen = screenSize.width < 600;

    // Give the horizontal color slider more room in portrait on both
    // phones and tablets, while keeping the existing behavior in
    // landscape.
    final double pickerWidth;
    if (orientation == Orientation.portrait) {
      pickerWidth = isSmallScreen ? 230.0 : 230.0;
    } else {
      pickerWidth = 150.0;
    }

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          // Make the picker unit narrower than the modal so it can
          // actually be centered as a block without overflowing.
          widthFactor: isSmallScreen ? 1.0 : 0.98,
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(12)),
            colorPickerWidth: pickerWidth,
            paletteType: PaletteType.hsvWithHue, // Different palette layout
            // Keep a consistent horizontal layout in both orientations so
            // the slider stays reasonably long and the overall height
            // remains compact.
            portraitOnly: false,
          ),
        ),
      ),
    );
  }
}
