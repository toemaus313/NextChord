import 'package:flutter/material.dart';
import '../../../domain/entities/midi_profile.dart';
import '../../../services/midi/midi_command_parser.dart';

/// Display list of MIDI commands with delete buttons
class MidiCommandsList extends StatelessWidget {
  final List<MidiCC> controlChanges;
  final bool timing;
  final Function(int) onRemoveCommand;
  final VoidCallback onRemoveTiming;
  final void Function(int oldIndex, int newIndex) onReorderCommand;
  final int? selectedIndex;
  final void Function(int index) onSelectCommand;
  final VoidCallback onMoveSelectedUp;
  final VoidCallback onMoveSelectedDown;
  final bool canMoveUp;
  final bool canMoveDown;

  const MidiCommandsList({
    super.key,
    required this.controlChanges,
    required this.timing,
    required this.onRemoveCommand,
    required this.onRemoveTiming,
    required this.onReorderCommand,
    required this.selectedIndex,
    required this.onSelectCommand,
    required this.onMoveSelectedUp,
    required this.onMoveSelectedDown,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'MIDI Commands:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.9, // Reduced by 15% from 14
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.arrow_upward,
                  size: 16,
                  color: canMoveUp ? Colors.white : Colors.white24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 16),
                onPressed: canMoveUp ? onMoveSelectedUp : null,
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: canMoveDown ? Colors.white : Colors.white24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 16),
                onPressed: canMoveDown ? onMoveSelectedDown : null,
              ),
            ],
          ),
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
          else ...[
            if (timing)
              _buildCommandRow(
                'MIDI Clock: timing',
                onRemoveTiming,
                isSelected: false,
                onTap: null,
              ),
            if (controlChanges.isNotEmpty)
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.zero,
                  onReorder: onReorderCommand,
                  itemCount: controlChanges.length,
                  itemBuilder: (context, index) {
                    final cc = controlChanges[index];
                    return Container(
                      key: ValueKey('midi_cc_'
                          '${cc.controller}_'
                          '${cc.value}_'
                          '${cc.label ?? ''}_'
                          '$index'),
                      child: _buildCommandRow(
                        _formatCommand(cc),
                        () => onRemoveCommand(index),
                        isSelected: selectedIndex == index,
                        onTap: () => onSelectCommand(index),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandRow(
    String command,
    VoidCallback onDelete, {
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final backgroundColor =
        isSelected ? Colors.white.withAlpha(40) : Colors.white.withAlpha(5);
    final borderColor =
        isSelected ? Colors.white.withAlpha(120) : Colors.white.withAlpha(20);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
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
      ),
    );
  }

  String _formatCommand(MidiCC cc) {
    final command = MidiCommandParser.midiCCToString(cc);
    return cc.label != null ? '$command - ${cc.label}' : command;
  }
}
