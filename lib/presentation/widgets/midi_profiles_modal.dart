import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/midi_profile.dart';
import '../providers/song_provider.dart';
import '../../../services/midi/midi_service.dart';
import '../../../services/midi/midi_profile_service.dart';
import 'midi_profiles/profile_selector.dart';
import 'midi_profiles/profile_name_input.dart';
import 'midi_profiles/midi_code_input.dart';
import 'midi_profiles/midi_commands_list.dart';
import 'midi_profiles/midi_action_buttons.dart';
import '../providers/appearance_provider.dart';
import 'templates/standard_modal_template.dart';

/// Modal for creating and managing MIDI profiles
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class MidiProfilesModal extends StatefulWidget {
  const MidiProfilesModal({super.key});

  /// Show the MIDI Profiles modal
  static Future<void> show(BuildContext context) {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: false,
      child: const MidiProfilesModal(),
    );
  }

  @override
  State<MidiProfilesModal> createState() => _MidiProfilesModalState();
}

class _MidiProfilesModalState extends State<MidiProfilesModal> {
  final _nameController = TextEditingController();
  final _controlChangeController = TextEditingController();
  final _notesController = TextEditingController();
  final MidiService _midiService = MidiService();
  late final FocusNode _midiCodeFocusNode;

  late final MidiProfileService _profileService;

  MidiProfile? _selectedProfile;
  List<MidiProfile> _profiles = [];
  List<MidiCC> _controlChanges = [];
  bool _timing = false;
  bool _isLoading = false;
  int? _selectedCommandIndex;

  @override
  void initState() {
    super.initState();
    _midiCodeFocusNode = FocusNode();

    // Initialize the profile service
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    _profileService = MidiProfileService(
      songProvider.repository,
      _midiService,
    );

    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _controlChangeController.dispose();
    _notesController.dispose();
    _midiCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _profileService.loadProfiles();
    if (mounted) {
      setState(() {
        _profiles = profiles;
      });
    }
  }

  void _selectProfile(MidiProfile? profile) {
    setState(() {
      _selectedProfile = profile;
      if (profile != null) {
        _nameController.text = profile.name;
        _controlChanges = _profileService.profileToDisplayFormat(profile);
        _timing = profile.timing;
        _notesController.text = profile.notes ?? '';
      } else {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _nameController.clear();
    _controlChangeController.clear();
    _notesController.clear();
    _controlChanges = [];
    _timing = false;
  }

  void _addControlChange() {
    final text = _controlChangeController.text.trim();
    if (text.isEmpty) return;

    // Check for timing command
    if (_profileService.isTimingCommand(text)) {
      setState(() {
        _timing = true;
      });
      _controlChangeController.clear();
      _notesController.clear();
      return;
    }

    // Parse MIDI command
    final cc = _profileService.parseCommand(text);
    if (cc != null) {
      setState(() {
        // Add label if provided
        final comment = _notesController.text.trim();
        final labeledCc = comment.isNotEmpty
            ? MidiCC(
                controller: cc.controller,
                value: cc.value,
                label: comment,
              )
            : cc;
        _controlChanges.add(labeledCc);
      });
      _controlChangeController.clear();
      _notesController.clear();
    } else {}
  }

  void _removeControlChange(int index) {
    setState(() {
      _controlChanges.removeAt(index);

      if (_selectedCommandIndex != null) {
        if (index == _selectedCommandIndex) {
          _selectedCommandIndex = null;
        } else if (index < _selectedCommandIndex!) {
          _selectedCommandIndex = _selectedCommandIndex! - 1;
        }
      }
    });
  }

  void _reorderControlChange(int oldIndex, int newIndex,
      {bool fromDrag = true}) {
    setState(() {
      if (fromDrag && newIndex > oldIndex) {
        newIndex -= 1;
      }
      final currentSelected = _selectedCommandIndex;
      if (oldIndex < 0 || oldIndex >= _controlChanges.length) {
        return;
      }
      if (newIndex < 0 || newIndex > _controlChanges.length) {
        return;
      }
      final item = _controlChanges.removeAt(oldIndex);
      _controlChanges.insert(newIndex, item);

      if (currentSelected != null) {
        if (currentSelected == oldIndex) {
          _selectedCommandIndex = newIndex;
        } else if (oldIndex < currentSelected && currentSelected <= newIndex) {
          _selectedCommandIndex = currentSelected - 1;
        } else if (newIndex <= currentSelected && currentSelected < oldIndex) {
          _selectedCommandIndex = currentSelected + 1;
        }
      }
    });
  }

  void _selectControlChange(int index) {
    setState(() {
      _selectedCommandIndex = index;
    });
  }

  void _moveSelectedCommandUp() {
    if (_selectedCommandIndex == null || _selectedCommandIndex! <= 0) {
      return;
    }
    final index = _selectedCommandIndex!;
    _reorderControlChange(index, index - 1, fromDrag: false);
  }

  void _moveSelectedCommandDown() {
    if (_selectedCommandIndex == null ||
        _selectedCommandIndex! >= _controlChanges.length - 1) {
      return;
    }
    final index = _selectedCommandIndex!;
    _reorderControlChange(index, index + 1, fromDrag: false);
  }

  void _removeTiming() {
    setState(() {
      _timing = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _profileService.saveProfile(
        name: _nameController.text.trim(),
        controlChanges: _controlChanges,
        timing: _timing,
        notes: _controlChanges.isNotEmpty ? _controlChanges.first.label : null,
        id: _selectedProfile?.id,
      );

      await _loadProfiles();
      _clearForm();
      _selectProfile(null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedProfile == null
                  ? 'MIDI profile created successfully!'
                  : 'MIDI profile updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProfile() async {
    if (_selectedProfile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
            'Are you sure you want to delete "${_selectedProfile!.name}"? This will remove it from any songs that use it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _profileService.deleteProfile(_selectedProfile!.id);
      await _loadProfiles();
      _clearForm();
      _selectProfile(null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MIDI profile deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testProfileMidiCommands() async {
    setState(() => _isLoading = true);
    try {
      await _profileService.testProfile(
        controlChanges: _controlChanges,
        timing: _timing,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'MIDI commands sent on Channel ${_midiService.displayMidiChannel}.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelChanges(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppearanceProvider>(
      builder: (context, appearanceProvider, child) {
        return Material(
          type: MaterialType.transparency,
          child: StandardModalTemplate.buildModalContainer(
            context: context,
            appearanceProvider: appearanceProvider,
            maxHeight: 650,
            maxWidth: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Close and Save buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      // Close button (upper left)
                      TextButton(
                        onPressed: () => _cancelChanges(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 21, vertical: 11),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'MIDI Profiles',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.6, // Reduced by 15% from 16
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Save button (upper right)
                      TextButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 21, vertical: 11),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                // Form content (non-scrollable; only commands list scrolls)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile selector
                      ProfileSelector(
                        profiles: _profiles,
                        selectedProfile: _selectedProfile,
                        onProfileSelected: _selectProfile,
                      ),
                      const SizedBox(height: 5),
                      // Profile name input
                      ProfileNameInput(
                        nameController: _nameController,
                      ),
                      const SizedBox(height: 5),
                      // MIDI code input
                      MidiCodeInput(
                        controlChangeController: _controlChangeController,
                        notesController: _notesController,
                        midiCodeFocusNode: _midiCodeFocusNode,
                        onAddCommand: _addControlChange,
                      ),
                      const SizedBox(height: 5),
                      // MIDI commands list (scrolls within a fixed-height area)
                      SizedBox(
                        height: 140,
                        child: MidiCommandsList(
                          controlChanges: _controlChanges,
                          timing: _timing,
                          onRemoveCommand: _removeControlChange,
                          onRemoveTiming: _removeTiming,
                          onReorderCommand: _reorderControlChange,
                          selectedIndex: _selectedCommandIndex,
                          onSelectCommand: _selectControlChange,
                          onMoveSelectedUp: _moveSelectedCommandUp,
                          onMoveSelectedDown: _moveSelectedCommandDown,
                          canMoveUp: _selectedCommandIndex != null &&
                              _selectedCommandIndex! > 0,
                          canMoveDown: _selectedCommandIndex != null &&
                              _selectedCommandIndex! <
                                  _controlChanges.length - 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Action buttons
                      MidiActionButtons(
                        selectedProfile: _selectedProfile,
                        isLoading: _isLoading,
                        onTest: _testProfileMidiCommands,
                        onDelete: _deleteProfile,
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
