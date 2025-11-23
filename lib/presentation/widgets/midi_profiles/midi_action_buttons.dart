import 'package:flutter/material.dart';
import '../../../domain/entities/midi_profile.dart';

/// Action buttons for MIDI profiles modal
class MidiActionButtons extends StatelessWidget {
  final MidiProfile? selectedProfile;
  final bool isLoading;
  final VoidCallback onSave;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const MidiActionButtons({
    super.key,
    required this.selectedProfile,
    required this.isLoading,
    required this.onSave,
    required this.onTest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Save/New button at top
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.white24),
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
                : Text(
                    selectedProfile == null ? 'Create' : 'Save',
                    style: const TextStyle(
                        fontSize: 11.9), // Reduced by 15% from 14
                  ),
          ),
        ),
        const SizedBox(height: 6),
        // Test MIDI button (replaces add button)
        SizedBox(
          width: double.infinity,
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
        const SizedBox(height: 6),
        // Delete button at bottom (only when editing)
        if (selectedProfile != null)
          SizedBox(
            width: double.infinity,
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
          ),
      ],
    );
  }
}
