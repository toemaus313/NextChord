import 'package:flutter/material.dart';

/// Input fields for MIDI commands and comments
class MidiCodeInput extends StatelessWidget {
  final TextEditingController controlChangeController;
  final TextEditingController notesController;
  final FocusNode midiCodeFocusNode;
  final VoidCallback onAddCommand;

  const MidiCodeInput({
    super.key,
    required this.controlChangeController,
    required this.notesController,
    required this.midiCodeFocusNode,
    required this.onAddCommand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
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
                  controller: controlChangeController,
                  focusNode: midiCodeFocusNode,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.9), // Reduced by 15% from 14
                  decoration: InputDecoration(
                    hintText: 'PC10, CC7:100, timing',
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
                  onFieldSubmitted: (_) => onAddCommand(),
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
                TextFormField(
                  controller: notesController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.9), // Reduced by 15% from 14
                  decoration: InputDecoration(
                    hintText: 'Optional label',
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
                  onFieldSubmitted: (_) => onAddCommand(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
