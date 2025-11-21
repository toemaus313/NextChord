import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/song_provider.dart';
import '../../domain/entities/midi_profile.dart';
import '../../services/midi/midi_service.dart';

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
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: const MidiProfilesModal(),
      ),
    );
  }

  @override
  State<MidiProfilesModal> createState() => _MidiProfilesModalState();
}

class _MidiProfilesModalState extends State<MidiProfilesModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _programChangeController = TextEditingController();
  final _controlChangeController = TextEditingController();
  final _notesController = TextEditingController();
  final MidiService _midiService = MidiService();
  late final FocusNode _midiCodeFocusNode;

  MidiProfile? _selectedProfile;
  List<MidiProfile> _profiles = [];
  List<MidiCC> _controlChanges = [];
  bool _timing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _midiCodeFocusNode = FocusNode();
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _programChangeController.dispose();
    _controlChangeController.dispose();
    _notesController.dispose();
    _midiCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      // First ensure the database schema is correct
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      final songRepository = songProvider.repository;
      await songRepository.database.ensureMidiProfilesTable();

      final profiles = await songRepository.getAllMidiProfiles();
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Database Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Failed to load MIDI profiles from database.'),
                const SizedBox(height: 8),
                Text('Error: $e', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                const Text(
                    'This usually means the database schema needs to be updated.'),
                const SizedBox(height: 8),
                const Text(
                    'Try restarting the app to trigger database migration.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _selectProfile(MidiProfile? profile) {
    setState(() {
      _selectedProfile = profile;
      if (profile != null) {
        _nameController.text = profile.name;
        _programChangeController.text =
            profile.programChangeNumber?.toString() ?? '';
        _controlChanges = List.from(profile.controlChanges);
        _timing = profile.timing;
        _notesController.text = profile.notes ?? '';
      } else {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _nameController.clear();
    _programChangeController.clear();
    _controlChangeController.clear();
    _notesController.clear();
    _controlChanges = [];
    _timing = false;
  }

  void _addControlChange() {
    final text = _controlChangeController.text.trim();
    final comment = _notesController.text.trim();

    if (text.isEmpty) return;

    try {
      final cc = _parseControlChange(text);
      if (cc != null) {
        setState(() {
          _controlChanges.add(MidiCC(
            controller: cc.controller,
            value: cc.value,
            label: comment.isNotEmpty ? comment : null,
          ));
          _controlChangeController.clear();
          _notesController.clear();
        });

        // Return focus to MIDI code field for next entry
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _midiCodeFocusNode.requestFocus();
          }
        });
      } else {
        _showError(
            'Invalid format. Use "CC0:127" for Control Change or "PC5" for Program Change');
      }
    } catch (e) {
      _showError('Invalid MIDI command: $e');
    }
  }

  MidiCC? _parseControlChange(String text) {
    final upperText = text.toUpperCase().trim();

    // Parse Program Change: "PC5" or "PC:5"
    if (upperText.startsWith('PC')) {
      final pcMatch = RegExp(r'^PC(\d+)$').firstMatch(upperText) ??
          RegExp(r'^PC:(\d+)$').firstMatch(upperText);
      if (pcMatch != null) {
        final pcValue = int.tryParse(pcMatch.group(1)!);
        if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
          return MidiCC(controller: -1, value: pcValue); // -1 indicates PC
        }
      }
    }

    // Parse Control Change: "CC0:127"
    if (upperText.startsWith('CC')) {
      final ccMatch = RegExp(r'^CC(\d+):(\d+)$').firstMatch(upperText);
      if (ccMatch != null) {
        final controller = int.tryParse(ccMatch.group(1)!);
        final value = int.tryParse(ccMatch.group(2)!);
        if (controller != null &&
            controller >= 0 &&
            controller <= 119 &&
            value != null &&
            value >= 0 &&
            value <= 127) {
          return MidiCC(controller: controller, value: value);
        }
      }
    }

    return null;
  }

  void _removeControlChange(int index) {
    setState(() {
      _controlChanges.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a profile name');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      final songRepository = songProvider.repository;

      final profile = MidiProfile(
        id: _selectedProfile?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        programChangeNumber: _programChangeController.text.isNotEmpty
            ? int.tryParse(_programChangeController.text)
            : null,
        controlChanges: _controlChanges,
        timing: _timing,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await songRepository.saveMidiProfile(profile);
      await _loadProfiles();
      _clearForm();
      _selectProfile(null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MIDI profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Error saving profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfile() async {
    if (_selectedProfile == null) return;

    final confirmed = await _showConfirmDialog(
      'Delete Profile',
      'Are you sure you want to delete "${_selectedProfile!.name}"? This will remove it from any songs that use it.',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      final songRepository = songProvider.repository;
      await songRepository.deleteMidiProfile(_selectedProfile!.id);
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
      _showError('Error deleting profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testProfileMidiCommands() async {
    if (!_midiService.isConnected) {
      _showError('Connect a MIDI device before testing commands.');
      return;
    }

    final programChangeText = _programChangeController.text.trim();
    final programChange =
        programChangeText.isEmpty ? null : int.tryParse(programChangeText);

    if (programChangeText.isNotEmpty && programChange == null) {
      _showError('Invalid Program Change number.');
      return;
    }

    final hasCommands =
        programChange != null || _controlChanges.isNotEmpty || _timing;

    if (!hasCommands) {
      _showError('Add some MIDI commands before testing.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (programChange != null) {
        await _midiService.sendProgramChange(programChange,
            channel: _midiService.midiChannel);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      for (final cc in _controlChanges) {
        if (cc.controller == -1) {
          await _midiService.sendProgramChange(cc.value,
              channel: _midiService.midiChannel);
        } else {
          await _midiService.sendControlChange(cc.controller, cc.value,
              channel: _midiService.midiChannel);
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (_timing) {
        await _midiService.sendMidiClock();
      }

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
      _showError('Error testing MIDI commands: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // App Modal Design Standard: Constrained dialog size
        constraints: const BoxConstraints(
          maxWidth: 480,
          minWidth: 320,
          maxHeight: 650,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              // App Modal Design Standard: Gradient background
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0468cc), Color.fromARGB(150, 3, 73, 153)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            // App Modal Design Standard: Consistent padding
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileList(),
                          const SizedBox(height: 6),
                          _buildProfileNameSetting(),
                          const SizedBox(height: 6),
                          _buildMidiCodeSection(),
                          const SizedBox(height: 6),
                          _buildMidiCommandsList(),
                          const SizedBox(height: 6),
                          _buildActionButtons(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // App Modal Design Standard: Header button styling
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('Close', style: TextStyle(fontSize: 14)),
        ),
        const Spacer(),
        const Text(
          'MIDI Profiles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // New button
        TextButton(
          onPressed: () => _selectProfile(null),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text('New', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildProfileList() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
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
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<MidiProfile>(
              value: _selectedProfile,
              dropdownColor: const Color(0xFF0468cc),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: _profiles.map((profile) {
                return DropdownMenuItem<MidiProfile>(
                  value: profile,
                  child: Text(profile.name),
                );
              }).toList(),
              onChanged: (MidiProfile? profile) {
                _selectProfile(profile);
              },
              hint: const Text(
                'Select profile...',
                style: TextStyle(color: Colors.white70),
              ),
              isExpanded: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileNameSetting() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        children: [
          const Text(
            'Profile Name:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
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
                  borderSide: const BorderSide(color: Color(0xFF0468cc)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                hintStyle: const TextStyle(color: Colors.white38),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a profile name';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMidiCodeSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
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
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _controlChangeController,
                  focusNode: _midiCodeFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      borderSide: const BorderSide(color: Color(0xFF0468cc)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  onFieldSubmitted: (value) {
                    _addControlChange();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right half - Comment entry
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comment:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Optional notes...',
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
                      borderSide: const BorderSide(color: Color(0xFF0468cc)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  onFieldSubmitted: (value) {
                    _addControlChange();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMidiCommandsList() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MIDI Commands:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (_controlChanges.isEmpty && !_timing)
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
                  fontSize: 12,
                ),
              ),
            )
          else
            Column(
              children: [
                if (_timing)
                  _buildCommandRow(
                    'MIDI Clock: timing',
                    () => setState(() => _timing = false),
                  ),
                for (int i = 0; i < _controlChanges.length; i++)
                  _buildCommandRow(
                    '${_controlChanges[i].controller == -1 ? 'PC${_controlChanges[i].value}' : 'CC${_controlChanges[i].controller}:${_controlChanges[i].value}'}${_controlChanges[i].label != null ? ' - ${_controlChanges[i].label}' : ''}',
                    () => _removeControlChange(i),
                  ),
              ],
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
                fontSize: 12,
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Save/New button at top
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(_selectedProfile == null ? 'Create' : 'Save',
                    style: const TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 6),
        // Test MIDI button (replaces add button)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _testProfileMidiCommands,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Test', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 6),
        // Delete button at bottom (only when editing)
        if (_selectedProfile != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _deleteProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete', style: TextStyle(fontSize: 14)),
            ),
          ),
      ],
    );
  }
}
