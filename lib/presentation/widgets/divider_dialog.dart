import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/setlist.dart';

/// Dialog for creating and editing setlist dividers with color selection
class DividerDialog extends StatefulWidget {
  final SetlistDividerItem? existingDivider;

  const DividerDialog({Key? key, this.existingDivider}) : super(key: key);

  static Future<SetlistDividerItem?> show(BuildContext context,
      {SetlistDividerItem? existingDivider}) {
    final mode = existingDivider == null ? 'create' : 'edit';
    return showDialog<SetlistDividerItem>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: DividerDialog(existingDivider: existingDivider),
      ),
    );
  }

  @override
  State<DividerDialog> createState() => _DividerDialogState();
}

class _DividerDialogState extends State<DividerDialog> {
  final _textController = TextEditingController();
  Color _selectedColor = Colors.white;
  bool _isSaving = false;

  // Predefined color palette
  static const List<Color> _colorPalette = [
    Colors.white,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.grey,
    Colors.brown,
    Colors.indigo,
    Colors.teal,
    Colors.amber,
    Colors.lime,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingDivider != null) {
      _textController.text = widget.existingDivider!.label;
      // Convert hex string back to Color
      final colorValue = int.parse(
          widget.existingDivider!.color.replaceFirst('#', ''),
          radix: 16);
      _selectedColor = Color(colorValue);
    } else {
      _textController.text = 'Text';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          _saveDivider();
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0468cc), Color.fromARGB(150, 3, 73, 153)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildTextField(),
                const SizedBox(height: 16),
                _buildColorPalette(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const Spacer(),
        const Text(
          'Divider',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _isSaving ? null : _saveDivider,
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
          child: const Text(
            'Save',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField() {
    return TextFormField(
      controller: _textController,
      style: TextStyle(color: _selectedColor, fontSize: 14),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: 'Text',
        hintStyle: TextStyle(
            color: _selectedColor.withValues(alpha: 0.7), fontSize: 14),
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Text is required';
        }
        return null;
      },
    );
  }

  Widget _buildColorPalette() {
    return Container(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _colorPalette.map((color) {
          // Compare color values to handle MaterialColor vs Color equality
          final isSelected = _selectedColor.value == color.value;
          return GestureDetector(
            onTap: () {
              // Convert MaterialColor to plain Color to avoid equality issues
              final plainColor = Color(color.value);
              setState(() => _selectedColor = plainColor);
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _saveDivider() async {
    if (_textController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final divider = SetlistDividerItem(
        id: const Uuid().v4(),
        label: _textController.text.trim(),
        order: 0, // Will be set by the calling code
        color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
      );

      if (mounted) {
        Navigator.of(context).pop(divider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save divider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
