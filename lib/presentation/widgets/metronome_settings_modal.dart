import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_settings_provider.dart';
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
            return StandardModalTemplate.buildModalContainer(
              context: context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StandardModalTemplate.buildHeader(
                    context: context,
                    title: 'Metronome Settings',
                    onCancel: () => _cancelChanges(context, settingsProvider),
                    onOk: _midiSendError == null
                        ? () => _saveChanges(context, settingsProvider)
                        : () {},
                    okEnabled: _midiSendError == null,
                  ),
                  StandardModalTemplate.buildContent(
                    children: [
                      _buildCountInSetting(settingsProvider),
                      const SizedBox(height: 8),
                      _buildTickActionSetting(settingsProvider),
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
  }

  Widget _buildCountInSetting(MetronomeSettingsProvider settingsProvider) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.timer,
      label: 'Count In',
      control: StandardModalTemplate.buildDropdown<int>(
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

  Widget _buildTickActionSetting(MetronomeSettingsProvider settingsProvider) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.vibration,
      label: 'Tick Action',
      control: StandardModalTemplate.buildDropdown<String>(
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
            final hasText = _midiSendController.text.trim().isNotEmpty;
            final isConnected = midiService.isConnected;
            final hasNoError = _midiSendError == null;
            final canTest = hasText && isConnected && hasNoError;

            return StandardModalTemplate.buildButton(
              label: 'Test',
              icon: Icons.play_arrow,
              onPressed: canTest
                  ? () => _testMidiCommand(
                      context.read<MetronomeSettingsProvider>(), midiService)
                  : null,
            );
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
    _midiSendController.text = _originalMidiSendOnTick;
    setState(() {
      _midiSendError = _validateMidiSendCommand(_originalMidiSendOnTick);
    });
    Navigator.of(context).pop();
  }

  /// Save changes and close modal
  void _saveChanges(
      BuildContext context, MetronomeSettingsProvider settingsProvider) {
    Navigator.of(context).pop();
  }

  /// Test MIDI command by sending 8 metronome ticks at 120bpm
  Future<void> _testMidiCommand(MetronomeSettingsProvider settingsProvider,
      MidiService midiService) async {
    final midiCommand = settingsProvider.midiSendOnTick;
    if (midiCommand.isEmpty || !midiService.isConnected) return;

    try {
      // Send 8 ticks at 120bpm (500ms intervals)
      for (int i = 1; i <= 8; i++) {
        await _sendMidiCommand(midiCommand, midiService, i);
        if (i < 8) {
          await Future.delayed(
              const Duration(milliseconds: 500)); // 120bpm interval
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test completed: 8 MIDI ticks sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send a single MIDI command (reused from test dialog logic)
  Future<void> _sendMidiCommand(
      String commandText, MidiService midiService, int tickCount) async {
    final messages = commandText
        .split(',')
        .map((msg) => msg.trim())
        .where((msg) => msg.isNotEmpty);

    for (final message in messages) {
      final lowerMessage = message.toLowerCase();

      // Check timing command
      if (lowerMessage == 'timing') {
        await midiService.sendMidiClock();
      }
      // Parse Program Change: "PC10" or "PC:10"
      else if (lowerMessage.startsWith('pc')) {
        final pcMatch =
            RegExp(r'^pc(\d+)$', caseSensitive: false).firstMatch(message) ??
                RegExp(r'^pc:(\d+)$', caseSensitive: false).firstMatch(message);

        if (pcMatch != null) {
          final pcValue = int.tryParse(pcMatch.group(1)!);
          if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
            await midiService.sendProgramChange(pcValue,
                channel: midiService.midiChannel);
          }
        }
      }
      // Parse Control Change: "CC7:100"
      else if (lowerMessage.startsWith('cc')) {
        final ccMatch = RegExp(r'^cc(\d+):(\d+)$', caseSensitive: false)
            .firstMatch(message);

        if (ccMatch != null) {
          final controller = int.tryParse(ccMatch.group(1)!);
          final value = int.tryParse(ccMatch.group(2)!);

          if (controller != null &&
              controller >= 0 &&
              controller <= 119 &&
              value != null &&
              value >= 0 &&
              value <= 127) {
            await midiService.sendControlChange(controller, value,
                channel: midiService.midiChannel);
          }
        }
      }
    }
  }
}
