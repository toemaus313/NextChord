import 'package:flutter/material.dart';
import '../../../domain/entities/midi_profile.dart';
import '../../../services/midi/midi_command_parser.dart';

/// Display list of MIDI commands with delete buttons
class MidiCommandsList extends StatelessWidget {
  final List<MidiCC> controlChanges;
  final bool timing;
  final Function(int) onRemoveCommand;
  final VoidCallback onRemoveTiming;

  const MidiCommandsList({
    super.key,
    required this.controlChanges,
    required this.timing,
    required this.onRemoveCommand,
    required this.onRemoveTiming,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'MIDI Commands:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.9, // Reduced by 15% from 14
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (controlChanges.isEmpty && !timing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: const Text(
                'No MIDI commands added yet.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.2, // Reduced by 15% from 12
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timing)
                      _buildCommandRow(
                        'MIDI Clock: timing',
                        onRemoveTiming,
                      ),
                    for (int i = 0; i < controlChanges.length; i++)
                      _buildCommandRow(
                        _formatCommand(controlChanges[i]),
                        () => onRemoveCommand(i),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommandRow(String command, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              command,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.2, // Reduced by 15% from 12
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.close,
              size: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommand(MidiCC cc) {
    final command = MidiCommandParser.midiCCToString(cc);
    return cc.label != null ? '$command - ${cc.label}' : command;
  }
}
