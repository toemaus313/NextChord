import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/appearance_provider.dart';
import 'templates/standard_modal_template.dart';

/// Modal for adding a divider to a setlist with text and color selection
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class AddDividerModal extends StatefulWidget {
  final String? initialLabel;
  final String? initialColor;
  final bool isEdit;

  const AddDividerModal({
    Key? key,
    this.initialLabel,
    this.initialColor,
    this.isEdit = false,
  }) : super(key: key);

  /// Show the Add Divider modal and return the divider data if confirmed
  static Future<Map<String, String>?> show(
    BuildContext context, {
    String? initialLabel,
    String? initialColor,
    bool isEdit = false,
  }) {
    return StandardModalTemplate.show<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      child: AddDividerModal(
        initialLabel: initialLabel,
        initialColor: initialColor,
        isEdit: isEdit,
      ),
    );
  }

  @override
  State<AddDividerModal> createState() => _AddDividerModalState();
}

class _AddDividerModalState extends State<AddDividerModal> {
  late final TextEditingController _textController;
  String _selectedColor = 'blue';
  
  // Available color options
  static const Map<String, Color> _colorOptions = {
    'blue': Color(0xFF2196F3),
    'red': Color(0xFFF44336),
    'green': Color(0xFF4CAF50),
    'orange': Color(0xFFFF9800),
    'purple': Color(0xFF9C27B0),
    'teal': Color(0xFF009688),
    'yellow': Color(0xFFFFEB3B),
    'pink': Color(0xFFE91E63),
  };

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialLabel ?? '');
    _selectedColor = widget.initialColor ?? 'blue';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppearanceProvider>(
      builder: (context, appearanceProvider, child) {
        return StandardModalTemplate.buildModalContainer(
          context: context,
          appearanceProvider: appearanceProvider,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StandardModalTemplate.buildHeader(
                context: context,
                title: widget.isEdit ? 'Edit Divider' : 'Add Divider',
                onCancel: () => Navigator.of(context).pop(),
                onOk: _textController.text.trim().isEmpty
                    ? () {}
                    : () {
                        Navigator.of(context).pop({
                          'label': _textController.text.trim(),
                          'color': _selectedColor,
                        });
                      },
                okEnabled: _textController.text.trim().isNotEmpty,
                okLabel: widget.isEdit ? 'Save' : 'Add',
              ),
              StandardModalTemplate.buildContent(
                children: [
                  _buildTextInput(),
                  const SizedBox(height: 16),
                  _buildColorPicker(),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextInput() {
    return StandardModalTemplate.buildTextField(
      controller: _textController,
      hintText: 'e.g., "Encore", "Intermission", "Set Break"',
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLOR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colorOptions.entries.map((entry) {
              final colorName = entry.key;
              final color = entry.value;
              final isSelected = _selectedColor == colorName;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorName;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
