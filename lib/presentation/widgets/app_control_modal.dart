import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database/app_database.dart';
import '../../domain/entities/app_control_action.dart';
import '../../domain/entities/midi_profile.dart';
import '../../services/midi/midi_device_manager.dart';
import '../../services/midi/midi_command_parser.dart';
import '../../domain/entities/midi_message.dart';
import '../../presentation/widgets/templates/standard_modal_template.dart';
import '../../presentation/providers/song_provider.dart';

/// Helper class for app control mappings with MIDI code support
class AppControlMapping {
  final String id;
  final String? deviceId;
  final MidiCC midiCode;
  final String description;
  final AppControlActionType action;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppControlMapping({
    required this.id,
    this.deviceId,
    required this.midiCode,
    required this.description,
    required this.action,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert from legacy PedalMappingModel
  factory AppControlMapping.fromLegacy(PedalMappingModel legacy) {
    MidiCC midiCode;

    // Convert legacy message data to MidiCC
    if (legacy.messageType == 'pc') {
      midiCode = MidiCC(controller: -1, value: legacy.number ?? 0);
    } else {
      midiCode = MidiCC(
        controller: legacy.number ?? 0,
        value: legacy.valueMax ?? 127,
      );
    }

    // Parse action from legacy JSON
    AppControlActionType action = AppControlActionType.nextSong;
    try {
      final appAction = AppControlAction.fromLegacyJson(legacy.action);
      action = appAction.type;
    } catch (e) {
      // Default to next song section
    }

    return AppControlMapping(
      id: legacy.id,
      deviceId: legacy.deviceId,
      midiCode: midiCode,
      description: legacy.description ?? '',
      action: action,
      createdAt: DateTime.fromMillisecondsSinceEpoch(legacy.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(legacy.updatedAt),
    );
  }

  /// Convert to legacy PedalMappingModel for storage
  PedalMappingModel toLegacy() {
    final appAction = AppControlAction(type: action);

    return PedalMappingModel(
      id: id,
      key: '', // Not used for MIDI mappings
      action: jsonEncode(appAction.toJson()),
      description: description,
      isEnabled: true,
      deviceId: deviceId,
      messageType: midiCode.controller == -1 ? 'pc' : 'cc',
      channel: null, // Channel is handled by MIDI service
      number: midiCode.controller == -1 ? midiCode.value : midiCode.controller,
      valueMin: midiCode.controller == -1 ? null : 0,
      valueMax: midiCode.controller == -1 ? null : midiCode.value,
      createdAt: createdAt.millisecondsSinceEpoch,
      updatedAt: updatedAt.millisecondsSinceEpoch,
      isDeleted: false,
    );
  }
}

/// Modal for configuring MIDI pedal mappings and app control actions
class AppControlModal extends StatefulWidget {
  final MidiDeviceManager deviceManager;

  const AppControlModal({super.key, required this.deviceManager});

  /// Show the App Control modal
  static Future<void> show(BuildContext context,
      {MidiDeviceManager? deviceManager}) {
    // Use provided device manager or try to get from Provider
    final manager =
        deviceManager ?? Provider.of<MidiDeviceManager>(context, listen: false);

    return StandardModalTemplate.show<void>(
      context: context,
      child: AppControlModal(deviceManager: manager),
      barrierDismissible: false,
    );
  }

  @override
  State<AppControlModal> createState() => _AppControlModalState();
}

class _AppControlModalState extends State<AppControlModal> {
  late final MidiDeviceManager _deviceManager;
  late final StreamSubscription<MidiMessage> _midiSubscription;

  // Form controllers
  final _midiCodeController = TextEditingController();
  final _midiCodeFocusNode = FocusNode();

  // Form state
  String? _selectedDeviceId; // null = any device
  AppControlActionType _selectedAction = AppControlActionType.nextSong;
  bool _isMidiLearnMode = false;
  bool _isLoading = false;

  // Data
  List<AppControlMapping> _mappings = [];
  AppControlMapping? _editingMapping;

  @override
  void initState() {
    super.initState();
    // Use the device manager passed from parent
    _deviceManager = widget.deviceManager;
    // Scan for devices to populate the available devices list
    _deviceManager.scanForDevices();
    _initializeMidiDispatcher();
    _loadMappings();
    _setupMidiListener();
  }

  /// Initialize the MIDI Action Dispatcher lazily
  Future<void> _initializeMidiDispatcher() async {
    try {
      // MidiActionDispatcher is now initialized in app_wrapper.dart with all providers
      // No need to initialize here anymore
      debugPrint(
          'MidiActionDispatcher already initialized in app_wrapper.dart');
    } catch (e) {
      // Handle initialization error gracefully
      debugPrint('Failed to initialize MIDI dispatcher: $e');
    }
  }

  @override
  void dispose() {
    _midiSubscription.cancel();
    _midiCodeController.dispose();
    _midiCodeFocusNode.dispose();
    super.dispose();
  }

  void _setupMidiListener() {
    _midiSubscription = _deviceManager.messageStream.listen((message) {
      if (_isMidiLearnMode) {
        _handleMidiLearn(message);
      }
    });
  }

  void _handleMidiLearn(MidiMessage message) {
    // Device filtering: Only accept messages from the selected device
    if (_selectedDeviceId != null && message.device.id != _selectedDeviceId) {
      return; // Ignore messages from non-selected devices
    }

    setState(() {
      _selectedDeviceId = message.device.id;

      // Convert MIDI message to code format
      if (message.type == MidiMessageType.cc) {
        _midiCodeController.text = 'CC${message.number}:${message.value ?? 0}';
      } else if (message.type == MidiMessageType.pc) {
        _midiCodeController.text = 'PC${message.number}';
      } else {
        return; // Don't learn unsupported messages
      }

      _isMidiLearnMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Learned: ${message.device.name} - ${message.toString()}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _loadMappings() async {
    try {
      final repository =
          Provider.of<SongProvider>(context, listen: false).repository;
      final mappings = await repository.getAllPedalMappings();
      if (mounted) {
        setState(() {
          _mappings = mappings
              .where((m) => !m.isDeleted)
              .map((m) => AppControlMapping.fromLegacy(m))
              .toList();
        });
      }
    } catch (e) {
      _showError('Failed to load mappings: $e');
    }
  }

  void _selectMapping(AppControlMapping? mapping) {
    setState(() {
      _editingMapping = mapping;
      if (mapping != null) {
        _midiCodeController.text =
            MidiCommandParser.midiCCToString(mapping.midiCode);
        _selectedDeviceId = mapping.deviceId;
        _selectedAction = mapping.action;
      } else {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _midiCodeController.clear();
    _selectedDeviceId = null;
    _selectedAction = AppControlActionType.nextSong;
    _isMidiLearnMode = false;
  }

  Future<void> _saveMapping() async {
    // Only validate MIDI code if it's not empty (for new mappings)
    // Allow empty fields when just closing or editing existing mappings
    if (_midiCodeController.text.trim().isNotEmpty) {
      // Parse MIDI code for validation
      final midiCode =
          MidiCommandParser.parseControlChange(_midiCodeController.text.trim());
      if (midiCode == null) {
        _showError('Invalid MIDI code format');
        return;
      }
    } else if (_editingMapping == null) {
      // Only require MIDI code for new mappings
      _showError('Please enter a MIDI code');
      return;
    }

    // If we get here with empty MIDI code, just close the modal (editing existing)
    if (_midiCodeController.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository =
          Provider.of<SongProvider>(context, listen: false).repository;
      // Parse MIDI code (already validated above)
      final midiCode =
          MidiCommandParser.parseControlChange(_midiCodeController.text.trim());

      // Create auto-generated description from MIDI code and action
      final autoDescription =
          '${_midiCodeController.text.trim()} → ${_getActionDisplayName(_selectedAction)}';

      if (_editingMapping == null) {
        // Create new mapping with unique ID
        final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
        final mapping = AppControlMapping(
          id: uniqueId,
          deviceId: _selectedDeviceId,
          midiCode: midiCode!,
          action: _selectedAction,
          description: autoDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final legacyMapping = mapping.toLegacy();
        await repository.insertPedalMapping(legacyMapping);
      } else {
        // Update existing mapping
        final updatedMapping = AppControlMapping(
          id: _editingMapping!.id,
          deviceId: _selectedDeviceId,
          midiCode: midiCode!,
          action: _selectedAction,
          description: autoDescription,
          createdAt: _editingMapping!.createdAt,
          updatedAt: DateTime.now(),
        );

        final legacyMapping = updatedMapping.toLegacy();
        await repository.updatePedalMapping(legacyMapping);
      }

      await _loadMappings();
      _clearForm();
      _selectMapping(null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mapping saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save mapping: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteMapping() async {
    if (_editingMapping == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mapping'),
        content: Text(
            'Are you sure you want to delete "${_editingMapping!.description}"?'),
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
      final repository =
          Provider.of<SongProvider>(context, listen: false).repository;
      await repository.deletePedalMapping(_editingMapping!.id);

      await _loadMappings();
      _clearForm();
      _selectMapping(null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mapping deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete mapping: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleMidiLearn() {
    setState(() {
      _isMidiLearnMode = !_isMidiLearnMode;
    });

    if (_isMidiLearnMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('MIDI Learn mode: Press a pedal/button on your MIDI device'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _cancelChanges(BuildContext context) {
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return StandardModalTemplate.buildModalContainer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Cancel/Save buttons
          StandardModalTemplate.buildHeader(
            context: context,
            title: 'App Control',
            onCancel: () => _cancelChanges(context),
            onOk: () => Navigator.pop(context),
            okEnabled: !_isLoading,
          ),

          // Form content
          StandardModalTemplate.buildContent(
            children: [
              // MIDI Learn mode indicator
              if (_isMidiLearnMode)
                StandardModalTemplate.buildInfoBox(
                  text:
                      'MIDI Learn active - Press a pedal/button on your device',
                  icon: Icons.mic,
                  color: Colors.blue,
                ),

              // Mapping list
              _buildMappingList(),
              StandardModalTemplate.spacing(),

              // Device selection
              _buildDeviceSelection(),
              StandardModalTemplate.spacing(),

              // MIDI Code input
              _buildMidiCodeInput(),
              StandardModalTemplate.spacing(),

              // Action selection
              _buildActionSelection(),
              StandardModalTemplate.spacing(),

              // Action buttons
              _buildActionButtons(),
              StandardModalTemplate.spacing(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMappingList() {
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
          Row(
            children: [
              const Text(
                'Existing Mappings:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.9, // Reduced by 15% from 14
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _toggleMidiLearn,
                style: TextButton.styleFrom(
                  backgroundColor: _isMidiLearnMode
                      ? Colors.blue
                      : Colors.white.withAlpha(20),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_isMidiLearnMode ? 'Learning...' : 'MIDI Learn'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_mappings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: const Text(
                'No mappings added yet.',
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
                    for (int i = 0; i < _mappings.length; i++)
                      _buildMappingRow(
                          _mappings[i], () => _selectMapping(_mappings[i])),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMappingRow(AppControlMapping mapping, VoidCallback onTap) {
    final isSelected = _editingMapping?.id == mapping.id;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withAlpha(20)
              : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.white.withAlpha(50)
                : Colors.white.withAlpha(20),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    MidiCommandParser.midiCCToString(mapping.midiCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.2, // Reduced by 15% from 12
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getActionDisplayName(mapping.action),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.35, // Reduced by 15% from 11
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _deleteMappingById(mapping.id),
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

  Widget _buildDeviceSelection() {
    // Use available devices instead of connectedDeviceRefs
    // availableDevices shows system-detected devices, not just connected ones
    final devices = _deviceManager.availableDevices;

    // Ensure the selected device ID is valid
    String? validSelectedId = _selectedDeviceId;
    if (_selectedDeviceId != null &&
        _selectedDeviceId != 'any' &&
        !devices.any((d) => d.id == _selectedDeviceId)) {
      validSelectedId =
          null; // Reset to 'Any Device' if selected device not available
    }

    return StandardModalTemplate.buildSettingRow(
      icon: Icons.devices,
      label: 'Device',
      control: StandardModalTemplate.buildDropdown<String>(
        value: validSelectedId ?? 'any',
        items: [
          const DropdownMenuItem(value: 'any', child: Text('Any Device')),
          ...devices.map((device) => DropdownMenuItem(
                value: device.id,
                child: Text(device.name),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedDeviceId = value == 'any' ? null : value;
          });
        },
      ),
    );
  }

  Widget _buildMidiCodeInput() {
    return Column(
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
          controller: _midiCodeController,
          focusNode: _midiCodeFocusNode,
          style: const TextStyle(
              color: Colors.white, fontSize: 11.9), // Reduced by 15% from 14
          decoration: InputDecoration(
            hintText: 'PC10, CC7:100, etc.',
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
          onFieldSubmitted: (_) => _saveMapping(),
        ),
      ],
    );
  }

  Widget _buildActionSelection() {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.touch_app,
      label: 'Action',
      control: StandardModalTemplate.buildDropdown<AppControlActionType>(
        value: _selectedAction,
        items: availableAppControlActions
            .map((action) => DropdownMenuItem(
                  value: action,
                  child: Text(_getActionDisplayName(action)),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedAction = value ?? AppControlActionType.nextSong;
          });
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: StandardModalTemplate.buildButton(
            label:
                _editingMapping == null ? 'Create Mapping' : 'Update Mapping',
            onPressed: _isLoading ? null : _saveMapping,
            icon: _editingMapping == null ? Icons.add : Icons.save,
          ),
        ),
        const SizedBox(width: 8),
        if (_editingMapping != null) ...[
          Expanded(
            child: StandardModalTemplate.buildButton(
              label: 'Cancel Edit',
              onPressed: _isLoading ? null : () => _selectMapping(null),
              icon: Icons.clear,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (_editingMapping != null)
          Expanded(
            child: StandardModalTemplate.buildButton(
              label: 'Delete',
              onPressed: _isLoading ? null : _deleteMapping,
              icon: Icons.delete,
              isDestructive: true,
            ),
          ),
      ],
    );
  }

  Future<void> _deleteMappingById(String mappingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mapping'),
        content: const Text('Are you sure you want to delete this mapping?'),
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
      final repository =
          Provider.of<SongProvider>(context, listen: false).repository;
      await repository.deletePedalMapping(mappingId);

      await _loadMappings();
      if (_editingMapping?.id == mappingId) {
        _clearForm();
        _selectMapping(null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mapping deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete mapping: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getActionDisplayName(AppControlActionType action) {
    switch (action) {
      case AppControlActionType.previousSong:
        return 'Previous Song';
      case AppControlActionType.nextSong:
        return 'Next Song';
      case AppControlActionType.previousSection:
        return 'Previous Section';
      case AppControlActionType.nextSection:
        return 'Next Section';
      case AppControlActionType.scrollUp:
        return 'Scroll Up';
      case AppControlActionType.scrollDown:
        return 'Scroll Down';
      case AppControlActionType.scrollToTop:
        return 'Scroll to Top';
      case AppControlActionType.scrollToBottom:
        return 'Scroll to Bottom';
      case AppControlActionType.startMetronome:
        return 'Start Metronome';
      case AppControlActionType.stopMetronome:
        return 'Stop Metronome';
      case AppControlActionType.toggleMetronome:
        return 'Toggle Metronome';
      case AppControlActionType.repeatCountIn:
        return 'Repeat Count-In';
      case AppControlActionType.startAutoscroll:
        return 'Start Auto-scroll';
      case AppControlActionType.stopAutoscroll:
        return 'Stop Auto-scroll';
      case AppControlActionType.toggleAutoscroll:
        return 'Toggle Auto-scroll';
      case AppControlActionType.autoscrollSpeedFaster:
        return 'Autoscroll Speed Faster';
      case AppControlActionType.autoscrollSpeedSlower:
        return 'Autoscroll Speed Slower';
      case AppControlActionType.toggleSidebar:
        return 'Toggle Sidebar';
      case AppControlActionType.transposeUp:
        return 'Transpose Up';
      case AppControlActionType.transposeDown:
        return 'Transpose Down';
      case AppControlActionType.capoUp:
        return 'Capo Up';
      case AppControlActionType.capoDown:
        return 'Capo Down';
      case AppControlActionType.zoomIn:
        return 'Zoom In';
      case AppControlActionType.zoomOut:
        return 'Zoom Out';
    }
  }
}
