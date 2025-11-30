import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../main.dart' as main;
import '../../../services/midi/midi_profile_service.dart';

/// Input fields for MIDI commands and comments with autocomplete
class MidiCodeInput extends StatefulWidget {
  final TextEditingController controlChangeController;
  final TextEditingController notesController;
  final FocusNode midiCodeFocusNode;
  final VoidCallback onAddCommand;
  final MidiProfileService profileService;

  const MidiCodeInput({
    super.key,
    required this.controlChangeController,
    required this.notesController,
    required this.midiCodeFocusNode,
    required this.onAddCommand,
    required this.profileService,
  });

  @override
  State<MidiCodeInput> createState() => MidiCodeInputState();
}

class MidiCodeInputState extends State<MidiCodeInput> {
  List<String> _availableLabels = [];
  List<String> _filteredLabels = [];
  bool _showSuggestions = false;
  int _selectedSuggestionIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadAvailableLabels();
  }

  Future<void> _loadAvailableLabels() async {
    try {
      final labels = await widget.profileService.getAllLabels();
      main.myDebug(
          'MidiCodeInput: loaded ${labels.length} labels: ${labels.join(', ')}');
      if (mounted) {
        setState(() {
          _availableLabels = labels;
        });
      }
    } catch (e) {
      main.myDebug('MidiCodeInput: error loading labels: $e');
    }
  }

  /// Refresh the available labels for autocomplete (call after saving profiles)
  Future<void> refreshAvailableLabels() async {
    await _loadAvailableLabels();
  }

  void _onCommentChanged(String value) {
    main.myDebug('MidiCodeInput: comment changed to "$value"');
    if (value.isEmpty) {
      setState(() {
        _filteredLabels = [];
        _showSuggestions = false;
        _selectedSuggestionIndex = -1;
      });
      return;
    }

    final filtered = _availableLabels
        .where((label) => label.toLowerCase().contains(value.toLowerCase()))
        .toList();

    main.myDebug(
        'MidiCodeInput: found ${filtered.length} matching labels: ${filtered.join(', ')}');

    setState(() {
      _filteredLabels = filtered;
      _showSuggestions = filtered.isNotEmpty;
      _selectedSuggestionIndex = filtered.isNotEmpty
          ? 0
          : -1; // Start with first item selected if available
    });

    main.myDebug(
        'MidiCodeInput: _showSuggestions set to $_showSuggestions with ${filtered.length} labels');
  }

  void _onCommentSubmitted(String value) {
    if (_showSuggestions &&
        _selectedSuggestionIndex >= 0 &&
        _selectedSuggestionIndex < _filteredLabels.length) {
      _selectSuggestion(_filteredLabels[_selectedSuggestionIndex]);
    } else {
      widget.onAddCommand();
    }
  }

  Future<void> _selectSuggestion(String label) async {
    try {
      final commands = await widget.profileService.getCommandsByLabel(label);
      if (commands.isNotEmpty) {
        final command = commands.first;
        final midiCode = command.controller == -1
            ? 'PC${command.value}'
            : 'CC${command.controller},${command.value}';

        widget.controlChangeController.text = midiCode;
        widget.notesController.text = label;

        setState(() {
          _showSuggestions = false;
          _selectedSuggestionIndex = -1;
        });

        // Focus back to MIDI code field for editing if needed
        widget.midiCodeFocusNode.requestFocus();
      } else {
        main.myDebug('MidiCodeInput: no commands found for label "$label"');
      }
    } catch (e) {
      main.myDebug('MidiCodeInput: error selecting suggestion: $e');
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (!_showSuggestions || _filteredLabels.isEmpty) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (_filteredLabels.isNotEmpty) {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex + 1) % _filteredLabels.length;
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (_filteredLabels.isNotEmpty) {
            _selectedSuggestionIndex = _selectedSuggestionIndex <= 0
                ? _filteredLabels.length - 1
                : _selectedSuggestionIndex - 1;
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        if (_selectedSuggestionIndex >= 0 &&
            _selectedSuggestionIndex < _filteredLabels.length) {
          _selectSuggestion(_filteredLabels[_selectedSuggestionIndex]);
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_selectedSuggestionIndex >= 0 &&
            _selectedSuggestionIndex < _filteredLabels.length) {
          _selectSuggestion(_filteredLabels[_selectedSuggestionIndex]);
        } else {
          widget.onAddCommand();
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _showSuggestions = false;
          _selectedSuggestionIndex = -1;
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // MIDI Code input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MIDI Code:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.9, // Reduced by 15% from 14
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: widget.controlChangeController,
                        focusNode: widget.midiCodeFocusNode,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.9), // Reduced by 15% from 14
                        decoration: InputDecoration(
                          hintText: 'PC10, CC7,100, timing',
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onFieldSubmitted: (_) => widget.onAddCommand(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Comment input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comment:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.9, // Reduced by 15% from 14
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: widget.notesController,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.9), // Reduced by 15% from 14
                            decoration: InputDecoration(
                              hintText: 'Optional label',
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: _onCommentChanged,
                            onFieldSubmitted: _onCommentSubmitted,
                          ),
                          if (_showSuggestions)
                            Builder(
                              builder: (context) {
                                main.myDebug(
                                    'MidiCodeInput: rendering suggestions with ${_filteredLabels.length} items');
                                return Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 120),
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredLabels.length,
                                    itemBuilder: (context, index) {
                                      // Safety check - ensure index is valid
                                      if (index < 0 ||
                                          index >= _filteredLabels.length) {
                                        return const SizedBox.shrink();
                                      }

                                      final isSelected =
                                          index == _selectedSuggestionIndex;
                                      return InkWell(
                                        onTap: () {
                                          // Double safety check before accessing
                                          if (index >= 0 &&
                                              index < _filteredLabels.length) {
                                            _selectSuggestion(
                                                _filteredLabels[index]);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white.withAlpha(40)
                                                : Colors.transparent,
                                            borderRadius: index == 0
                                                ? const BorderRadius.only(
                                                    topLeft: Radius.circular(8),
                                                    topRight:
                                                        Radius.circular(8))
                                                : index ==
                                                        _filteredLabels.length -
                                                            1
                                                    ? const BorderRadius.only(
                                                        bottomLeft:
                                                            Radius.circular(8),
                                                        bottomRight:
                                                            Radius.circular(8))
                                                    : BorderRadius.zero,
                                          ),
                                          child: Text(
                                            _filteredLabels[index],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.9,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
