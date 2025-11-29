import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nextchord/main.dart' as main;
import '../../domain/entities/song.dart';
import '../../domain/entities/midi_mapping.dart';
import '../../domain/entities/midi_profile.dart';
import '../../services/midi/midi_service.dart';

/// Modal-style dialog for editing MIDI sends for a song
///
/// Follows the TagEditDialog design pattern with:
/// - Gradient styling matching app modal design standard
/// - Text-based MIDI message input (e.g., "PC:10, CC7:100, CC10:64")
/// - Tab-to-complete and enter-to-save functionality
/// - Suggestions for common MIDI controllers
class MidiSendsModal extends StatefulWidget {
  final Song song;
  final MidiMapping? initialMapping;
  final Function(MidiMapping) onMappingUpdated;

  const MidiSendsModal({
    Key? key,
    required this.song,
    this.initialMapping,
    required this.onMappingUpdated,
  }) : super(key: key);

  /// Show the MIDI Sends modal
  static Future<void> show(
    BuildContext context, {
    required Song song,
    MidiMapping? initialMapping,
    required Function(MidiMapping) onMappingUpdated,
  }) {
    final hasInitial = initialMapping != null;
    main.myDebug(
        '[MidiSendsModal] show: songId=${song.id}, title=${song.title}, hasInitialMapping=$hasInitial');
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: MidiSendsModal(
          song: song,
          initialMapping: initialMapping,
          onMappingUpdated: onMappingUpdated,
        ),
      ),
    );
  }

  @override
  State<MidiSendsModal> createState() => _MidiSendsModalState();
}

class _MidiSendsModalState extends State<MidiSendsModal> {
  TextEditingController? _codeController;
  TextEditingController? _commentController;
  late final FocusNode _okButtonFocusNode;
  late final FocusNode _codeFocusNode;
  late final FocusNode _commentFocusNode;
  int? _programChange;
  List<MidiCC> _controlChanges = [];
  bool _timing = false;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _commentController = TextEditingController();
    _okButtonFocusNode = FocusNode();
    _codeFocusNode = FocusNode();
    _commentFocusNode = FocusNode();
    _initializeFromInitialMapping();

    // Auto-focus the code field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNode.requestFocus();
    });
  }

  void _initializeFromInitialMapping() {
    if (widget.initialMapping != null) {
      _programChange = widget.initialMapping!.programChangeNumber;
      _controlChanges = List.from(widget.initialMapping!.controlChanges);
      _timing = widget.initialMapping!.timing;
      _notes = widget.initialMapping!.notes;

      // Keep text fields blank for new entry
      // _codeController!.text = _formatMappingAsCode();
      // _commentController!.text = _notes ?? '';
    }
  }

  @override
  void dispose() {
    _codeController?.dispose();
    _commentController?.dispose();
    _okButtonFocusNode.dispose();
    _codeFocusNode.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// Validate MIDI command format and return error message if invalid
  String? _validateMidiFormat(String codeText) {
    final messages = codeText
        .split(',')
        .map((msg) => msg.trim())
        .where((msg) => msg.isNotEmpty);

    for (final message in messages) {
      final lowerMessage = message.toLowerCase();

      // Check timing command
      if (lowerMessage == 'timing') {
        continue; // Valid timing command
      }

      // Check PC command format: PC<number>
      else if (lowerMessage.startsWith('pc')) {
        if (!RegExp(r'^pc\d+$', caseSensitive: false).hasMatch(message)) {
          return 'Invalid PC command "$message". Expected format: PC0-127';
        }
        final pcValue = int.tryParse(message.substring(2));
        if (pcValue == null || pcValue < 0 || pcValue > 127) {
          return 'Invalid PC value in "$message". Expected format: PC0-127';
        }
      }

      // Check CC command format: CC<number>:<value>
      else if (lowerMessage.startsWith('cc')) {
        final ccMatch = RegExp(r'^cc(\d+):(\d+)$', caseSensitive: false)
            .firstMatch(message);
        if (ccMatch == null) {
          return 'Invalid CC command "$message". Expected format: CC0-127:0-127';
        }

        final controller = int.tryParse(ccMatch.group(1)!);
        final value = int.tryParse(ccMatch.group(2)!);

        if (controller == null || controller < 0 || controller > 127) {
          return 'Invalid CC controller in "$message". Expected format: CC0-127:0-127';
        }
        if (value == null || value < 0 || value > 127) {
          return 'Invalid CC value in "$message". Expected format: CC0-127:0-127';
        }
      }

      // Unknown command
      else {
        if (lowerMessage.contains('timing')) {
          return 'Invalid timing command "$message". Expected format: timing';
        } else if (lowerMessage.contains('pc')) {
          return 'Invalid PC command "$message". Expected format: PC0-127';
        } else if (lowerMessage.contains('cc')) {
          return 'Invalid CC command "$message". Expected format: CC0-127:0-127';
        } else {
          return 'Unknown command "$message". Use PC, CC, or timing';
        }
      }
    }

    return null; // All commands valid
  }

  /// Add current command to the MIDI sends list
  void _addCurrentCommand(StateSetter setState) {
    final codeText = _codeController?.text.trim() ?? '';
    final commentText = _commentController?.text.trim() ?? '';

    if (codeText.isEmpty) {
      // Focus code field if empty
      _codeFocusNode.requestFocus();
      return;
    }

    // Validate format first
    final validationError = _validateMidiFormat(codeText);
    if (validationError != null) {
      // Show validation error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Parse the current code
      final newControlChanges = List<MidiCC>.from(_controlChanges);
      bool newTiming = _timing;

      // Split by comma and process each MIDI message
      final messages = codeText
          .split(',')
          .map((msg) => msg.trim())
          .where((msg) => msg.isNotEmpty);

      for (final message in messages) {
        // Parse timing command
        if (message.toLowerCase().startsWith('timing')) {
          newTiming = true;
        }
        // Parse Program Change: "PC10"
        else if (message.toUpperCase().startsWith('PC') &&
            !message.contains(':')) {
          final pcValue = int.tryParse(message.substring(2).trim());
          if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
            // Store PC as a CC-like object to support multiple commands
            newControlChanges.add(MidiCC(
              controller: -1, // Use -1 to indicate PC command
              value: pcValue,
              label: commentText.isNotEmpty ? commentText : null,
            ));
          }
        }
        // Parse Program Change with colon: "PC:10" (legacy support)
        else if (message.toUpperCase().startsWith('PC:')) {
          final pcValue = int.tryParse(message.substring(3).trim());
          if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
            // Store PC as a CC-like object to support multiple commands
            newControlChanges.add(MidiCC(
              controller: -1, // Use -1 to indicate PC command
              value: pcValue,
              label: commentText.isNotEmpty ? commentText : null,
            ));
          }
        }
        // Parse Control Change: "CC7:100"
        else if (message.toUpperCase().startsWith('CC')) {
          final colonIndex = message.indexOf(':');
          if (colonIndex > 2) {
            final controller = int.tryParse(message.substring(2, colonIndex));
            final value =
                int.tryParse(message.substring(colonIndex + 1).trim());

            if (controller != null &&
                controller >= 0 &&
                controller <= 119 &&
                value != null &&
                value >= 0 &&
                value <= 127) {
              newControlChanges.add(MidiCC(
                controller: controller,
                value: value,
                label: commentText.isNotEmpty ? commentText : null,
              ));
            }
          }
        }
      }

      // Update state with new values
      setState(() {
        _timing = newTiming;
        _programChange = null; // Clear single PC since we're using list now
        _controlChanges = newControlChanges;
        // Clear input fields for next command
        _codeController?.clear();
        _commentController?.clear();
      });

      // Keep focus on code field for next entry
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _codeFocusNode.requestFocus();
        }
      });
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid MIDI format: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Delete a control change command at the specified index
  void _deleteControlChange(int index, StateSetter setState) {
    setState(() {
      _controlChanges.removeAt(index);
    });
  }

  /// Delete the timing command
  void _deleteTimingCommand(StateSetter setState) {
    setState(() {
      _timing = false;
    });
  }

  /// Save and close the dialog
  void _saveAndClose(StateSetter setState) {
    // Process any remaining code in the input field
    if ((_codeController?.text.trim() ?? '').isNotEmpty) {
      _addCurrentCommand(setState);
    }

    // Update notes from comment field
    _notes = (_commentController?.text.trim() ?? '').isEmpty
        ? null
        : _commentController?.text.trim();

    // Create the updated mapping
    final updatedMapping = MidiMapping(
      id: widget.initialMapping?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      songId: widget.song.id,
      programChangeNumber: _programChange,
      controlChanges: _controlChanges,
      timing: _timing,
      notes: _notes,
      createdAt: widget.initialMapping?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context);
    widget.onMappingUpdated(updatedMapping);
  }

  /// Get format hint based on current input
  String _getFormatHint(String input) {
    // Check if we're at the start or after a comma (typing a new command)
    final lastCommaIndex = input.lastIndexOf(',');
    final currentCommand = lastCommaIndex >= 0
        ? input.substring(lastCommaIndex + 1).trim()
        : input.trim();

    final currentCommandLower = currentCommand.toLowerCase();

    if (currentCommandLower.isEmpty) {
      return 'Type CC, PC, or timing';
    } else if (currentCommandLower.startsWith('c') ||
        currentCommandLower.startsWith('cc')) {
      return 'CC00:00';
    } else if (currentCommandLower.startsWith('p') ||
        currentCommandLower.startsWith('pc')) {
      return 'PC00';
    } else if (currentCommandLower.startsWith('t') ||
        currentCommandLower.contains('timing') ||
        currentCommandLower.contains('timer') ||
        currentCommandLower.contains('midi clock')) {
      return 'timing';
    }

    return 'Invalid format';
  }

  @override
  Widget build(BuildContext context) {
    const primaryGradientTop = Color(0xFF0468cc);
    const primaryGradientBottom = Color.fromARGB(99, 3, 73, 153);

    return Consumer<MidiService>(
      builder: (context, midiService, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Get format hint based on current input
            final formatHint = _getFormatHint(_codeController?.text ?? '');

            return Column(
              children: [
                Row(
                  children: [
                    const Text('MIDI Sends'),
                    const Spacer(),
                    // Connection status indicator
                    Icon(
                      midiService.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          midiService.isConnected ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      midiService.isConnected ? 'Connected' : 'No Device',
                      style: TextStyle(
                        fontSize: 12,
                        color: midiService.isConnected
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current MIDI sends section
                        if (_timing ||
                            _programChange != null ||
                            _controlChanges.isNotEmpty) ...[
                          const Text(
                            'Current MIDI Sends:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryGradientTop.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: primaryGradientTop.withValues(
                                      alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_timing)
                                  Row(
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(Icons.delete, size: 16),
                                        onPressed: () =>
                                            _deleteTimingCommand(setState),
                                        color: Colors.red,
                                        tooltip: 'Remove MIDI Clock',
                                      ),
                                      Expanded(
                                        child:
                                            const Text('• MIDI Clock: timing'),
                                      ),
                                    ],
                                  ),
                                for (int i = 0; i < _controlChanges.length; i++)
                                  Row(
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(Icons.delete, size: 16),
                                        onPressed: () =>
                                            _deleteControlChange(i, setState),
                                        color: Colors.red,
                                        tooltip: 'Remove MIDI command',
                                      ),
                                      Expanded(
                                        child: Text(
                                            '• ${_controlChanges[i].controller == -1 ? 'PC${_controlChanges[i].value}' : 'CC${_controlChanges[i].controller}:${_controlChanges[i].value}'}${_controlChanges[i].label != null ? ' - ${_controlChanges[i].label}' : ''}'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Add new MIDI sends section
                        const Text(
                          'Add MIDI Sends:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Side-by-side layout for code and comment
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left half - MIDI code entry
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MIDI Code:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Focus(
                                    focusNode: _codeFocusNode,
                                    child: TextField(
                                      controller: _codeController,
                                      decoration: const InputDecoration(
                                        hintText: 'PC10, CC7:100, timing',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {});
                                      },
                                      onSubmitted: (value) {
                                        // ENTER now adds the command
                                        _addCurrentCommand(setState);
                                      },
                                      textInputAction: TextInputAction.next,
                                      onEditingComplete: () {
                                        // Tab moves focus to comment field
                                        _commentFocusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Add button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _addCurrentCommand(setState),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryGradientTop,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Add'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Right half - Comment entry
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Comment:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Focus(
                                    focusNode: _commentFocusNode,
                                    child: TextField(
                                      controller: _commentController,
                                      decoration: const InputDecoration(
                                        hintText: 'Optional notes...',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 1,
                                      onChanged: (value) {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Format hint
                        const SizedBox(height: 8),
                        Text(
                          'Format Hint:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: formatHint.contains('Invalid')
                                ? Colors.red.withValues(alpha: 0.1)
                                : primaryGradientTop.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: formatHint.contains('Invalid')
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : primaryGradientTop.withValues(
                                        alpha: 0.3)),
                          ),
                          child: Text(
                            formatHint,
                            style: TextStyle(
                                fontSize: 12,
                                color: formatHint.contains('Invalid')
                                    ? Colors.red
                                    : primaryGradientTop),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Focus(
                      focusNode: _okButtonFocusNode,
                      canRequestFocus: false,
                      skipTraversal: true,
                      child: FilledButton(
                        onPressed: () {
                          _saveAndClose(setState);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryGradientTop,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('OK'),
                      ),
                    ),
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryGradientBottom,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
