import 'package:flutter/material.dart';
import '../../domain/entities/app_control_action.dart';
import '../../services/midi/midi_action_dispatcher.dart';
import '../../presentation/widgets/templates/standard_modal_template.dart';

/// Modal for testing app control actions without MIDI mappings
class ActionTestModal extends StatefulWidget {
  const ActionTestModal({super.key});

  /// Show the Action Test modal
  static Future<void> show(BuildContext context) {
    return StandardModalTemplate.show<void>(
      context: context,
      child: const ActionTestModal(),
      barrierDismissible: false,
    );
  }

  @override
  State<ActionTestModal> createState() => _ActionTestModalState();
}

class _ActionTestModalState extends State<ActionTestModal> {
  AppControlActionType _selectedAction = AppControlActionType.nextSong;
  bool _isTestRunning = false;

  late final MidiActionDispatcher _midiDispatcher;

  @override
  void initState() {
    super.initState();
    _midiDispatcher = MidiActionDispatcher();
  }

  void _cancelChanges(BuildContext context) {
    Navigator.of(context).pop();
  }

  Future<void> _testAction() async {
    if (_isTestRunning) return;

    setState(() => _isTestRunning = true);

    try {
      // Use the same executeAction method as MIDI mappings
      await _midiDispatcher.executeAction(_selectedAction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Executed: ${_getActionDisplayName(_selectedAction)}'),
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
    } finally {
      if (mounted) {
        setState(() => _isTestRunning = false);
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

  @override
  Widget build(BuildContext context) {
    return StandardModalTemplate.buildModalContainer(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Cancel/Close buttons
          StandardModalTemplate.buildHeader(
            context: context,
            title: 'Action Test',
            onCancel: () => _cancelChanges(context),
            onOk: () => Navigator.pop(context),
            okLabel: 'Close',
          ),

          // Form content
          StandardModalTemplate.buildContent(
            children: [
              // Info box
              StandardModalTemplate.buildInfoBox(
                text: 'Test actions without creating MIDI mappings',
                icon: Icons.info_outline,
                color: Colors.blue,
              ),
              StandardModalTemplate.spacing(),

              // Action selection
              _buildActionSelection(),
              StandardModalTemplate.spacing(),

              // Test button
              _buildTestButton(),
              StandardModalTemplate.spacing(),
            ],
          ),
        ],
      ),
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

  Widget _buildTestButton() {
    return StandardModalTemplate.buildButton(
      label: _isTestRunning ? 'Testing...' : 'Test Action',
      onPressed: _isTestRunning ? null : _testAction,
      icon: _isTestRunning ? null : Icons.play_arrow,
    );
  }
}
