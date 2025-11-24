import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/midi_profile.dart';
import '../../providers/theme_provider.dart';
import '../midi_profiles_modal.dart';

/// Widget for selecting MIDI profiles with management option
class MidiProfileSelector extends StatefulWidget {
  final MidiProfile? selectedProfile;
  final ValueChanged<MidiProfile?> onProfileChanged;
  final List<MidiProfile> profiles;
  final bool isLoading;
  final VoidCallback? onProfilesReloaded;

  const MidiProfileSelector({
    super.key,
    required this.selectedProfile,
    required this.onProfileChanged,
    required this.profiles,
    required this.isLoading,
    this.onProfilesReloaded,
  });

  @override
  State<MidiProfileSelector> createState() => _MidiProfileSelectorState();
}

class _MidiProfileSelectorState extends State<MidiProfileSelector> {
  bool _isLoadingProfiles = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return SizedBox(
      height: 28,
      child: widget.isLoading || _isLoadingProfiles
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: widget.selectedProfile?.id,
                  isExpanded: true,
                  hint: Text(
                    'Select MIDI profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'No MIDI profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    ...widget.profiles
                        .map((profile) => DropdownMenuItem<String?>(
                              value: profile.id,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (profile.hasMidiCommands)
                                    Icon(
                                      Icons.piano,
                                      size: 14,
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                                ],
                              ),
                            )),
                    const DropdownMenuItem<String?>(
                      value: 'manage',
                      child: Row(
                        children: [
                          Icon(Icons.settings, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            'Manage Profiles...',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == 'manage') {
                      return;
                    }

                    final selectedProfile = value != null
                        ? widget.profiles.firstWhere(
                            (p) => p.id == value,
                            orElse: () => MidiProfile(
                              id: '',
                              name: 'No MIDI profile',
                              controlChanges: const [],
                              timing: false,
                            ),
                          )
                        : null;

                    widget.onProfileChanged(selectedProfile);
                  },
                ),
              ),
            ),
    );
  }

  Future<void> _showMidiProfilesDialog() async {
    setState(() => _isLoadingProfiles = true);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const MidiProfilesModal(),
      );

      // Trigger profile reload via callback if provided
      widget.onProfilesReloaded?.call();
    } finally {
      setState(() => _isLoadingProfiles = false);
    }
  }
}
