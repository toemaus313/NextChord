import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/midi_profile.dart';

/// Controller for managing MIDI profiles modal state and logic
class MidiProfilesController extends ChangeNotifier {
  final List<MidiProfile> profiles;
  MidiProfile? selectedProfile;

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController programChangeController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // Form state
  List<MidiCC> controlChanges = [];
  bool timing = false;
  bool hasUnsavedChanges = false;

  // Original values for comparison
  late final String _originalName;
  late final String _originalProgramChange;
  late final List<MidiCC> _originalControlChanges;
  late final bool _originalTiming;
  late final String _originalNotes;
  late final MidiProfile? _originalSelectedProfile;

  MidiProfilesController({
    required this.profiles,
    this.selectedProfile,
  }) {
    _initializeForm();
  }

  void _initializeForm() {
    _originalSelectedProfile = selectedProfile;

    if (selectedProfile != null) {
      _originalName = selectedProfile!.name;
      _originalProgramChange =
          selectedProfile!.programChangeNumber?.toString() ?? '';
      _originalControlChanges = List.from(selectedProfile!.controlChanges);
      _originalTiming = selectedProfile!.timing;
      _originalNotes = selectedProfile!.notes ?? '';

      nameController.text = _originalName;
      programChangeController.text = _originalProgramChange;
      controlChanges = List.from(_originalControlChanges);
      timing = _originalTiming;
      notesController.text = _originalNotes;
    } else {
      _originalName = '';
      _originalProgramChange = '';
      _originalControlChanges = [];
      _originalTiming = false;
      _originalNotes = '';
    }

    // Add listeners to track changes
    nameController.addListener(_onFormChanged);
    programChangeController.addListener(_onFormChanged);
    notesController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    final currentName = nameController.text;
    final currentProgramChange = programChangeController.text;
    final currentNotes = notesController.text;

    hasUnsavedChanges = currentName != _originalName ||
        currentProgramChange != _originalProgramChange ||
        currentNotes != _originalNotes ||
        !listEquals(controlChanges, _originalControlChanges) ||
        timing != _originalTiming ||
        selectedProfile != _originalSelectedProfile;

    notifyListeners();
  }

  void selectProfile(MidiProfile? profile) {
    selectedProfile = profile;
    _updateFormFromProfile();
    _onFormChanged();
  }

  void _updateFormFromProfile() {
    if (selectedProfile != null) {
      nameController.text = selectedProfile!.name;
      programChangeController.text =
          selectedProfile!.programChangeNumber?.toString() ?? '';
      controlChanges = List.from(selectedProfile!.controlChanges);
      timing = selectedProfile!.timing;
      notesController.text = selectedProfile!.notes ?? '';
    } else {
      clearForm();
    }
  }

  void clearForm() {
    nameController.clear();
    programChangeController.clear();
    notesController.clear();
    controlChanges = [];
    timing = false;
    selectedProfile = null;
    hasUnsavedChanges = false;
    notifyListeners();
  }

  void addControlChange() {
    controlChanges.add(const MidiCC(
      controller: 1,
      value: 0,
      label: 'Controller 1',
    ));
    notifyListeners();
  }

  void updateControlChange(int index, MidiCC cc) {
    if (index >= 0 && index < controlChanges.length) {
      controlChanges[index] = cc;
      notifyListeners();
    }
  }

  void removeControlChange(int index) {
    if (index >= 0 && index < controlChanges.length) {
      controlChanges.removeAt(index);
      notifyListeners();
    }
  }

  void toggleTiming() {
    timing = !timing;
    notifyListeners();
  }

  void restoreOriginalValues() {
    nameController.text = _originalName;
    programChangeController.text = _originalProgramChange;
    controlChanges = List.from(_originalControlChanges);
    timing = _originalTiming;
    notesController.text = _originalNotes;
    selectedProfile = _originalSelectedProfile;
    hasUnsavedChanges = false;
    notifyListeners();
  }

  bool validateForm() {
    if (nameController.text.trim().isEmpty) {
      return false;
    }

    if (programChangeController.text.isNotEmpty) {
      final programChange = int.tryParse(programChangeController.text);
      if (programChange == null || programChange < 0 || programChange > 127) {
        return false;
      }
    }

    return true;
  }

  MidiProfile createProfileFromForm() {
    return MidiProfile(
      id: selectedProfile?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      programChangeNumber: programChangeController.text.isNotEmpty
          ? int.tryParse(programChangeController.text)
          : null,
      controlChanges: controlChanges,
      timing: timing,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      createdAt: selectedProfile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    programChangeController.dispose();
    notesController.dispose();
    super.dispose();
  }
}
