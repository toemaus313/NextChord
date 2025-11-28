import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/midi_profile.dart';
import '../../providers/appearance_provider.dart';

/// Dropdown selector for MIDI profiles
class ProfileSelector extends StatelessWidget {
  final List<MidiProfile> profiles;
  final MidiProfile? selectedProfile;
  final ValueChanged<MidiProfile?> onProfileSelected;

  const ProfileSelector({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.onProfileSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Get themed dropdown background color from AppearanceProvider
    final appearanceProvider = Provider.of<AppearanceProvider?>(
      context,
      listen: false,
    );
    final dropdownBackgroundColor =
        appearanceProvider?.gradientStart ?? const Color(0xFF0468cc);

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(
            Icons.list,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Profiles:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.9, // Reduced by 15% from 14
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<MidiProfile>(
              value: selectedProfile,
              hint: const Text(
                'Select profile...',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11.9, // Reduced by 15% from 14
                ),
              ),
              dropdownColor: dropdownBackgroundColor,
              items: profiles.map((profile) {
                return DropdownMenuItem<MidiProfile>(
                  value: profile,
                  child: Text(
                    profile.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.9, // Reduced by 15% from 14
                    ),
                  ),
                );
              }).toList(),
              onChanged: onProfileSelected,
              isExpanded: true,
              underline: Container(
                height: 1,
                color: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
