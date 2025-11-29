import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/appearance_provider.dart';
import 'templates/standard_modal_template.dart';

/// Appearance Settings Modal - For customizing app color theme
class AppearanceSettingsModal extends StatefulWidget {
  const AppearanceSettingsModal({Key? key}) : super(key: key);

  /// Show the Appearance Settings modal
  static Future<void> show(BuildContext context) {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: false,
      child: const AppearanceSettingsModal(),
    );
  }

  @override
  State<AppearanceSettingsModal> createState() =>
      _AppearanceSettingsModalState();
}

class _AppearanceSettingsModalState extends State<AppearanceSettingsModal> {
  late final TextEditingController _hexController;
  String? _hexError;

  // Store original color for cancel functionality
  late Color _originalColor;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();

    // Initialize controller and store original values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appearanceProvider = context.read<AppearanceProvider>();
      final initialHex = appearanceProvider.hexColorString;
      _hexController.text = initialHex;

      // Store original color
      _originalColor = appearanceProvider.customColor;

      // Add listener to trigger rebuilds when text changes
      _hexController.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      setState(() {
        _hexError = _validateHexColor(initialHex);
      });
    });
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppearanceProvider>(
      builder: (context, appearanceProvider, child) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return StandardModalTemplate.buildModalContainer(
              context: context,
              appearanceProvider: appearanceProvider,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StandardModalTemplate.buildHeader(
                    context: context,
                    title: 'Appearance Settings',
                    onCancel: () => _cancelChanges(context, appearanceProvider),
                    onOk:
                        _hexError == null ? () => _saveChanges(context) : () {},
                    okEnabled: _hexError == null,
                  ),
                  StandardModalTemplate.buildContent(
                    children: [
                      _buildThemeModeSection(themeProvider),
                      const SizedBox(height: 16),
                      _buildColorPickerSection(appearanceProvider),
                      const SizedBox(height: 16),
                      _buildHexInputSection(appearanceProvider),
                      const SizedBox(height: 16),
                      _buildResetButton(appearanceProvider),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeModeSection(ThemeProvider themeProvider) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.brightness_6,
      label: 'Theme Mode',
      control: StandardModalTemplate.buildDropdown<ThemeModeType>(
        context: context,
        value: themeProvider.themeMode,
        items: ThemeModeType.values.map((mode) {
          return DropdownMenuItem<ThemeModeType>(
            value: mode,
            child: Text(
              _getThemeModeDisplayName(mode),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: (ThemeModeType? newMode) {
          if (newMode != null) {
            themeProvider.setThemeMode(newMode);
          }
        },
      ),
    );
  }

  String _getThemeModeDisplayName(ThemeModeType mode) {
    switch (mode) {
      case ThemeModeType.light:
        return 'Light';
      case ThemeModeType.dark:
        return 'Dark';
      case ThemeModeType.system:
        return 'System';
    }
  }

  Widget _buildColorPickerSection(AppearanceProvider appearanceProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color Picker',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildColorWheel(appearanceProvider),
      ],
    );
  }

  Widget _buildColorWheel(AppearanceProvider appearanceProvider) {
    // Simple color palette - 6x4 grid of preset colors + one custom slot
    final List<List<Color?>> colors = [
      // Row 1: Basic colors
      [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple],
      // Row 2: Blues and cyans
      [Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan],
      // Row 3: Greens and yellows
      [Colors.teal, Colors.green, Colors.lightGreen, Colors.lime],
      // Row 4: Oranges and others
      [Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange],
      // Row 5: Browns and grays
      [Colors.brown, Colors.grey, Colors.blueGrey, Colors.black],
      // Row 6: Whites and custom slot (bottom-right)
      [Colors.white, Colors.white70, Colors.white30, null],
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: colors
            .map((row) => Row(
                  children: row
                      .map((color) => Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                if (color != null) {
                                  // Preset color selected
                                  await appearanceProvider
                                      .setCustomColor(color);
                                  _hexController.text =
                                      appearanceProvider.hexColorString;
                                  setState(() {
                                    _hexError =
                                        _validateHexColor(_hexController.text);
                                  });
                                } else {
                                  // "Custom..." slot - open advanced color picker
                                  await _showCustomColorPicker(
                                      context, appearanceProvider);
                                }
                              },
                              child: Container(
                                height: 32,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: color ?? Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: color != null &&
                                            appearanceProvider.customColor ==
                                                color
                                        ? Colors.white
                                        : Colors.white24,
                                    width: color != null &&
                                            appearanceProvider.customColor ==
                                                color
                                        ? 2
                                        : 1,
                                  ),
                                ),
                                child: color == null
                                    ? const Center(
                                        child: Text(
                                          'Custom…',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _showCustomColorPicker(
      BuildContext context, AppearanceProvider appearanceProvider) async {
    Color tempColor = appearanceProvider.customColor;

    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Custom Color',
            style: TextStyle(color: Colors.white),
          ),
          // Constrain the picker height and make it scrollable so the bottom
          // never gets clipped, even on very short/landscape layouts.
          content: SizedBox(
            height: screenHeight * 0.8,
            child: SingleChildScrollView(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: ColorPicker(
                  pickerColor: tempColor,
                  onColorChanged: (color) {
                    tempColor = color;
                  },
                  enableAlpha: false,
                  labelTypes: const [],
                  pickerAreaBorderRadius:
                      const BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(tempColor),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (selectedColor != null) {
      await appearanceProvider.setCustomColor(selectedColor);
      _hexController.text = appearanceProvider.hexColorString;
      setState(() {
        _hexError = _validateHexColor(_hexController.text);
      });
    }
  }

  Widget _buildHexInputSection(AppearanceProvider appearanceProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StandardModalTemplate.buildSettingRow(
          icon: Icons.tag,
          label: 'Hex Color',
          control: StandardModalTemplate.buildTextField(
            controller: _hexController,
            hintText: '#0468CC',
            errorText: _hexError,
            onChanged: (value) {
              final error = _validateHexColor(value);
              setState(() {
                _hexError = error;
              });
              if (error == null) {
                appearanceProvider.setColorFromHex(value);
              }
            },
            onSubmitted: (value) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton(AppearanceProvider appearanceProvider) {
    return StandardModalTemplate.buildButton(
      label: 'Reset to Default',
      icon: Icons.refresh,
      onPressed: () {
        appearanceProvider.resetToDefault();
        _hexController.text = appearanceProvider.hexColorString;
        setState(() {
          _hexError = _validateHexColor(_hexController.text);
        });
      },
    );
  }

  String? _validateHexColor(String value) {
    if (value.isEmpty) return 'Color cannot be empty';

    final hexRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    if (!hexRegex.hasMatch(value)) {
      return 'Enter valid hex color (e.g., #0468CC)';
    }

    return null;
  }

  /// Cancel changes and restore original color
  void _cancelChanges(
      BuildContext context, AppearanceProvider appearanceProvider) {
    appearanceProvider.setCustomColor(_originalColor);
    final r = _originalColor.red;
    final g = _originalColor.green;
    final b = _originalColor.blue;
    _hexController.text =
        '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
    setState(() {
      _hexError = _validateHexColor(_hexController.text);
    });
    Navigator.of(context).pop();
  }

  /// Save changes and close modal
  void _saveChanges(BuildContext context) {
    Navigator.of(context).pop();
  }
}
