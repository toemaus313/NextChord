import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../providers/appearance_provider.dart';
import '../../services/midi/midi_service.dart';
import 'templates/standard_modal_template.dart';

/// Metronome Settings Modal - Using StandardModalTemplate
class MetronomeSettingsModal extends StatefulWidget {
  const MetronomeSettingsModal({Key? key}) : super(key: key);

  /// Show the Metronome Settings modal
  static Future<void> show(BuildContext context) {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: false,
      child: const MetronomeSettingsModal(),
    );
  }

  @override
  State<MetronomeSettingsModal> createState() => _MetronomeSettingsModalState();
}

class _MetronomeSettingsModalState extends State<MetronomeSettingsModal> {
  late final TextEditingController _midiSendController;
  String? _midiSendError;

  // Store original values for cancel functionality
  late int _originalCountInMeasures;
  late String _originalTickAction;
  late String _originalMidiSendOnTick;
  late bool _originalMetronomeOnAutoscroll;

  @override
  void initState() {
    super.initState();
    _midiSendController = TextEditingController();

    // Initialize MIDI service singleton
    MidiService();

    // Load current settings into controller and store original values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settingsProvider = context.read<MetronomeSettingsProvider>();
      final initialValue = settingsProvider.midiSendOnTick;
      _midiSendController.text = initialValue;

      // Store original values
      _originalCountInMeasures = settingsProvider.countInMeasures;
      _originalTickAction = settingsProvider.tickAction;
      _originalMidiSendOnTick = initialValue;
      _originalMetronomeOnAutoscroll = settingsProvider.metronomeOnAutoscroll;

      // Add listener to trigger rebuilds when text changes
      _midiSendController.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      setState(() {
        _midiSendError = _validateMidiSendCommand(initialValue);
      });
    });
  }

  @override
  void dispose() {
    _midiSendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeSettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Consumer<MidiService>(
          builder: (context, midiService, child) {
            return Consumer<AppearanceProvider>(
              builder: (context, appearanceProvider, child) {
                return StandardModalTemplate.buildModalContainer(
                  context: context,
                  appearanceProvider: appearanceProvider,
                  maxHeight: 700,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StandardModalTemplate.buildHeader(
                        context: context,
                        title: 'Metronome Settings',
                        onCancel: () =>
                            _cancelChanges(context, settingsProvider),
                        onOk: _midiSendError == null
                            ? () => _saveChanges(context)
                            : () {},
                        okEnabled: _midiSendError == null,
                      ),
                      StandardModalTemplate.buildContent(
                        children: [
                          _buildCountInSetting(settingsProvider),
                          const SizedBox(height: 8),
                          _buildTickActionSetting(settingsProvider),
                          const SizedBox(height: 8),
                          _buildMetronomeOnAutoscrollSetting(settingsProvider),
                          const SizedBox(height: 8),
                          _buildMidiSendSetting(settingsProvider, midiService),
                          const SizedBox(height: 8),
                          _buildMidiStatusInfo(midiService),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCountInSetting(MetronomeSettingsProvider settingsProvider) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.timer,
      label: 'Count In',
      control: StandardModalTemplate.buildDropdown<int>(
        context: context,
        value: settingsProvider.countInMeasures,
        items: const [
          DropdownMenuItem<int>(
            value: 0,
            child: Text('Off',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          DropdownMenuItem<int>(
            value: 1,
            child: Text('1 measure',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          DropdownMenuItem<int>(
            value: 2,
            child: Text('2 measure',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
        onChanged: (int? newMeasures) {
          if (newMeasures != null) {
            settingsProvider.setCountInMeasures(newMeasures);
          }
        },
      ),
    );
  }

  Widget _buildMetronomeOnAutoscrollSetting(
      MetronomeSettingsProvider settingsProvider) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.play_arrow,
      label: 'Metronome on Autoscroll',
      control: Switch(
        value: settingsProvider.metronomeOnAutoscroll,
        onChanged: (value) {
          settingsProvider.setMetronomeOnAutoscroll(value);
        },
        activeColor: Colors.white,
        activeTrackColor: Colors.white70,
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white24,
      ),
    );
  }

  Widget _buildTickActionSetting(MetronomeSettingsProvider settingsProvider) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.vibration,
      label: 'Tick Action',
      control: StandardModalTemplate.buildDropdown<String>(
        context: context,
        value: settingsProvider.tickAction,
        items: MetronomeSettingsProvider.availableTickActions
            .map((action) => DropdownMenuItem<String>(
                  value: action,
                  child: Text(
                    action,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ))
            .toList(),
        onChanged: (String? newAction) {
          if (newAction != null) {
            settingsProvider.setTickAction(newAction);
          }
        },
      ),
    );
  }

  Widget _buildMidiSendSetting(
      MetronomeSettingsProvider settingsProvider, MidiService midiService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.piano, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            const Text(
              'MIDI Send on Tick',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StandardModalTemplate.buildTextField(
          controller: _midiSendController,
          hintText: 'e.g., PC10, CC7:100, timing',
          errorText: _midiSendError,
          onChanged: (value) {
            final error = _validateMidiSendCommand(value);
            setState(() {
              _midiSendError = error;
            });
            settingsProvider.setMidiSendOnTick(value);
          },
          onSubmitted: (value) {
            FocusScope.of(context).unfocus();
          },
        ),
        const SizedBox(height: 8),
        Consumer<MidiService>(
          builder: (context, midiService, child) {
            return const SizedBox.shrink(); // Test button removed
          },
        ),
      ],
    );
  }

  Widget _buildMidiStatusInfo(MidiService midiService) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (midiService.isConnected) {
      statusColor = Colors.green;
      statusText = 'MIDI device connected - commands will be sent on tick';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.orange;
      statusText = 'No MIDI device connected - configure MIDI in Settings';
      statusIcon = Icons.info_outline;
    }

    return StandardModalTemplate.buildInfoBox(
      icon: statusIcon,
      text: statusText,
      color: statusColor,
    );
  }

  String? _validateMidiSendCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return null;

    final segments =
        trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    final pcPattern = RegExp(r'^pc:?([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-7])$',
        caseSensitive: false);
    final ccPattern = RegExp(
        r'^cc([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-7]):([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-7])$',
        caseSensitive: false);

    for (final segment in segments) {
      final lower = segment.toLowerCase();
      if (!pcPattern.hasMatch(lower) && !ccPattern.hasMatch(lower)) {
        return 'Enter PC<0-127> or CC<0-127>:<0-127>';
      }
    }

    return null;
  }

  /// Cancel changes and restore original values
  void _cancelChanges(
      BuildContext context, MetronomeSettingsProvider settingsProvider) {
    settingsProvider.setCountInMeasures(_originalCountInMeasures);
    settingsProvider.setTickAction(_originalTickAction);
    settingsProvider.setMidiSendOnTick(_originalMidiSendOnTick);
    settingsProvider.setMetronomeOnAutoscroll(_originalMetronomeOnAutoscroll);
    _midiSendController.text = _originalMidiSendOnTick;
    setState(() {
      _midiSendError = _validateMidiSendCommand(_originalMidiSendOnTick);
    });
    Navigator.of(context).pop();
  }

  /// Save changes and close modal
  void _saveChanges(BuildContext context) {
    Navigator.of(context).pop();
  }
}
