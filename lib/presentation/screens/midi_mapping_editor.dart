import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../services/midi/midi_service.dart';
import 'midi_settings_screen.dart';

/// Screen for editing MIDI mappings for a specific song
class MidiMappingEditorScreen extends StatefulWidget {
  final Song song;
  final MidiMapping? initialMapping;

  const MidiMappingEditorScreen({
    Key? key,
    required this.song,
    this.initialMapping,
  }) : super(key: key);

  @override
  State<MidiMappingEditorScreen> createState() =>
      _MidiMappingEditorScreenState();
}

class _MidiMappingEditorScreenState extends State<MidiMappingEditorScreen> {
  late MidiService _midiService;

  // Form controllers
  final _notesController = TextEditingController();
  int? _programChangeNumber;
  List<MidiCC> _controlChanges = [];

  // Form keys for validation
  final _formKey = GlobalKey<FormState>();
  final _pcFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _midiService = MidiService();
    _initializeFromInitialMapping();
  }

  void _initializeFromInitialMapping() {
    if (widget.initialMapping != null) {
      _programChangeNumber = widget.initialMapping!.programChangeNumber;
      _controlChanges = List.from(widget.initialMapping!.controlChanges);
      _notesController.text = widget.initialMapping!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MIDI Mapping - ${widget.song.title}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Test button (only when connected)
          Consumer<MidiService>(
            builder: (context, midiService, child) {
              return IconButton(
                onPressed: midiService.isConnected ? _testCurrentMapping : null,
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Test Current Mapping',
              );
            },
          ),
          // Save button
          IconButton(
            onPressed: _saveMapping,
            icon: const Icon(Icons.save),
            tooltip: 'Save Mapping',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Song info card
              _buildSongInfoCard(),
              const SizedBox(height: 20),

              // Program Change section
              _buildProgramChangeSection(),
              const SizedBox(height: 20),

              // Control Changes section
              _buildControlChangesSection(),
              const SizedBox(height: 20),

              // Notes section
              _buildNotesSection(),
              const SizedBox(height: 20),

              // Connection status
              _buildConnectionStatus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.song.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Artist: ${widget.song.artist}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (widget.song.key.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Key: ${widget.song.key}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramChangeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Program Change (PC)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Selects a preset/patch on the MIDI device (0-127)',
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Send a Program Change message to select a specific preset on your MIDI device when this song loads.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Form(
              key: _pcFormKey,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Program Number',
                        hintText: '0-127',
                        border: OutlineInputBorder(),
                        helperText: 'Leave empty to disable PC message',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _programChangeNumber?.toString(),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final number = int.tryParse(value);
                        if (number == null) return 'Must be a number';
                        if (number < 0 || number > 127) return 'Must be 0-127';
                        return null;
                      },
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _programChangeNumber = null;
                        } else {
                          _programChangeNumber = int.parse(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Test PC button
                  Consumer<MidiService>(
                    builder: (context, midiService, child) {
                      return ElevatedButton(
                        onPressed: midiService.isConnected &&
                                _programChangeNumber != null
                            ? () => _testProgramChange(_programChangeNumber!)
                            : null,
                        child: const Text('Test'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlChangesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Control Changes (CC)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      'Adjust parameters like volume, pan, effects (0-127)',
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Send Control Change messages to adjust parameters on your MIDI device when this song loads.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),

            // CC List
            if (_controlChanges.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No Control Changes configured',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ] else ...[
              ...List.generate(_controlChanges.length, (index) {
                final cc = _controlChanges[index];
                return _buildCCItem(cc, index);
              }),
            ],

            const SizedBox(height: 12),

            // Add CC button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddCCDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Control Change'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCCItem(MidiCC cc, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cc.label ?? 'Controller ${cc.controller}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'CC${cc.controller} = ${cc.value}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Test button
          Consumer<MidiService>(
            builder: (context, midiService, child) {
              return IconButton(
                onPressed: midiService.isConnected
                    ? () => _testControlChange(cc.controller, cc.value)
                    : null,
                icon: const Icon(Icons.play_arrow, size: 20),
                tooltip: 'Test',
              );
            },
          ),
          // Edit button
          IconButton(
            onPressed: () => _showEditCCDialog(cc, index),
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Edit',
          ),
          // Delete button
          IconButton(
            onPressed: () => _removeCC(index),
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Mapping Notes',
                hintText: 'Add any notes about this MIDI mapping...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<MidiService>(
      builder: (context, midiService, child) {
        Color statusColor;
        String statusText;
        IconData statusIcon;

        switch (midiService.connectionState) {
          case MidiConnectionState.connected:
            statusColor = Colors.green;
            statusText =
                'Connected to ${midiService.connectedDevice?.name ?? 'Unknown'}';
            statusIcon = Icons.check_circle;
            break;
          case MidiConnectionState.connecting:
            statusColor = Colors.orange;
            statusText = 'Connecting...';
            statusIcon = Icons.sync;
            break;
          case MidiConnectionState.scanning:
            statusColor = Colors.blue;
            statusText = 'Scanning...';
            statusIcon = Icons.search;
            break;
          case MidiConnectionState.error:
            statusColor = Colors.red;
            statusText = midiService.errorMessage ?? 'Error';
            statusIcon = Icons.error;
            break;
          default:
            statusColor = Colors.grey;
            statusText = 'No MIDI device connected';
            statusIcon = Icons.bluetooth_disabled;
        }

        return Card(
          color: statusColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!midiService.isConnected)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MidiSettingsScreen(),
                        ),
                      );
                    },
                    child: const Text('Configure MIDI'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCCDialog() {
    showDialog(
      context: context,
      builder: (context) => _CCEditorDialog(
        onSave: (controller, value, label) {
          setState(() {
            _controlChanges.add(MidiCC(
              controller: controller,
              value: value,
              label: label,
            ));
          });
        },
      ),
    );
  }

  void _showEditCCDialog(MidiCC cc, int index) {
    showDialog(
      context: context,
      builder: (context) => _CCEditorDialog(
        initialCC: cc,
        onSave: (controller, value, label) {
          setState(() {
            _controlChanges[index] = MidiCC(
              controller: controller,
              value: value,
              label: label,
            );
          });
        },
      ),
    );
  }

  void _removeCC(int index) {
    setState(() {
      _controlChanges.removeAt(index);
    });
  }

  Future<void> _testProgramChange(int program) async {
    try {
      await _midiService.sendProgramChange(program);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Program Change $program sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testControlChange(int controller, int value) async {
    try {
      await _midiService.sendControlChange(controller, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Control Change CC$controller=$value sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testCurrentMapping() async {
    if (!mounted) return;

    try {
      // Test Program Change
      if (_programChangeNumber != null) {
        await _midiService.sendProgramChange(_programChangeNumber!);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Test Control Changes
      for (final cc in _controlChanges) {
        await _midiService.sendControlChange(cc.controller, cc.value);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MIDI mapping test completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing mapping: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveMapping() {
    if (!_formKey.currentState!.validate() ||
        !_pcFormKey.currentState!.validate()) return;

    // Create the MidiMapping object
    final mapping = MidiMapping(
      id: widget.initialMapping?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      songId: widget.song.id,
      programChangeNumber: _programChangeNumber,
      controlChanges: _controlChanges,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    // TODO: Save to database via provider
    debugPrint('🎹 Saving MIDI mapping for ${widget.song.title}:');
    debugPrint('  PC: ${_programChangeNumber ?? 'None'}');
    debugPrint('  CC: ${_controlChanges.length} messages');
    for (final cc in _controlChanges) {
      debugPrint(
          '    CC${cc.controller}=${cc.value} (${cc.label ?? 'No label'})');
    }

    Navigator.of(context).pop(mapping);
  }
}

/// Dialog for editing individual Control Change messages
class _CCEditorDialog extends StatefulWidget {
  final MidiCC? initialCC;
  final Function(int controller, int value, String? label) onSave;

  const _CCEditorDialog({
    this.initialCC,
    required this.onSave,
  });

  @override
  State<_CCEditorDialog> createState() => _CCEditorDialogState();
}

class _CCEditorDialogState extends State<_CCEditorDialog> {
  late TextEditingController _controllerController;
  late TextEditingController _valueController;
  late TextEditingController _labelController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controllerController = TextEditingController(
      text: widget.initialCC?.controller.toString() ?? '',
    );
    _valueController = TextEditingController(
      text: widget.initialCC?.value.toString() ?? '',
    );
    _labelController = TextEditingController(
      text: widget.initialCC?.label ?? '',
    );
  }

  @override
  void dispose() {
    _controllerController.dispose();
    _valueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialCC == null
          ? 'Add Control Change'
          : 'Edit Control Change'),
      content: SizedBox(
        width: 300,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _controllerController,
                decoration: const InputDecoration(
                  labelText: 'Controller Number',
                  hintText: '0-119',
                  helperText: 'Common: 7=Volume, 10=Pan, 64=Sustain',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final number = int.tryParse(value);
                  if (number == null) return 'Must be a number';
                  if (number < 0 || number > 119) return 'Must be 0-119';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  hintText: '0-127',
                  helperText: '0=Min, 64=Center, 127=Max',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final number = int.tryParse(value);
                  if (number == null) return 'Must be a number';
                  if (number < 0 || number > 127) return 'Must be 0-127';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (Optional)',
                  hintText: 'e.g., Volume, Reverb, Delay',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final controller = int.parse(_controllerController.text);
              final value = int.parse(_valueController.text);
              final label =
                  _labelController.text.isEmpty ? null : _labelController.text;

              widget.onSave(controller, value, label);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
