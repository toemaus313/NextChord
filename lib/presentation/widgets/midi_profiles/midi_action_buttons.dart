import 'package:flutter/material.dart';
import '../../../domain/entities/midi_profile.dart';

/// Action buttons for MIDI profiles modal
class MidiActionButtons extends StatelessWidget {
  final MidiProfile? selectedProfile;
  final bool isLoading;
  final VoidCallback onTest;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const MidiActionButtons({
    super.key,
    required this.selectedProfile,
    required this.isLoading,
    required this.onTest,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Test MIDI button
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : onTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Test',
                    style: TextStyle(fontSize: 11.9), // Reduced by 15% from 14
                  ),
          ),
        ),
        const SizedBox(width: 8),
        // Copy button
        Expanded(
          child: ElevatedButton(
            onPressed: (isLoading || selectedProfile == null) ? null : onCopy,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withAlpha(100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Copy',
                    style: TextStyle(fontSize: 11.9), // Reduced by 15% from 14
                  ),
          ),
        ),
        const SizedBox(width: 8),
        // Delete button (only when editing)
        if (selectedProfile != null)
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : onDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Delete',
                      style:
                          TextStyle(fontSize: 11.9), // Reduced by 15% from 14
                    ),
            ),
          )
        else
          // Spacer to maintain layout when no profile selected
          const Expanded(child: SizedBox()),
      ],
    );
  }
}
