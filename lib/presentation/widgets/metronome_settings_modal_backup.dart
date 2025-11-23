import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../../services/midi/midi_service.dart';

/// Modal-style dialog for metronome settings configuration
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class MetronomeSettingsModal extends StatefulWidget {
  const MetronomeSettingsModal({Key? key}) : super(key: key);

  /// Show the Metronome Settings modal
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: const MetronomeSettingsModal(),
      ),
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
            return Center(
              child: ConstrainedBox(
                // App Modal Design Standard: Constrained dialog size
                constraints: const BoxConstraints(
                  maxWidth: 480,
                  minWidth: 320,
                  maxHeight: 650,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    // App Modal Design Standard: Gradient background
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0468cc),
                        Color.fromARGB(150, 3, 73, 153)
                      ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCountInOnlySetting(settingsProvider),
                              const SizedBox(height: 12),
                              _buildTickActionSetting(settingsProvider),
                              const SizedBox(height: 12),
                              _buildMidiSendOnTickSetting(
                                  settingsProvider, midiService),
                              const SizedBox(height: 12),
                              _buildMidiStatusInfo(midiService),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildHeader(BuildContext context) {
    return Consumer<MetronomeSettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Consumer<MidiService>(
          builder: (context, midiService, child) {
            return Row(
              children: [
                // Cancel button (upper left)
                TextButton(
                  onPressed: () => _cancelChanges(context, settingsProvider),
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
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
                const Spacer(),
                const Text(
                  'Metronome Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // OK button (upper right)
                TextButton(
                  onPressed: _midiSendError == null
                      ? () => _saveChanges(context, settingsProvider)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        _midiSendError == null ? Colors.white : Colors.white54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 21, vertical: 11),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: _midiSendError == null
                              ? Colors.white24
                              : Colors.white12),
                    ),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 14)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCountInOnlySetting(MetronomeSettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Count In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: settingsProvider.countInMeasures,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                dropdownColor: const Color(0xFF0468cc),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: const [
                  DropdownMenuItem<int>(
                    value: 0,
                    child: Text(
                      'Off',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  DropdownMenuItem<int>(
                    value: 1,
                    child: Text(
                      '1 measure',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  DropdownMenuItem<int>(
                    value: 2,
                    child: Text(
                      '2 measure',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
                onChanged: (int? newMeasures) {
                  if (newMeasures != null) {
                    settingsProvider.setCountInMeasures(newMeasures);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickActionSetting(MetronomeSettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.vibration,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'Tick Action:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settingsProvider.tickAction,
                  isExpanded: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  dropdownColor: const Color(0xFF0468cc),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: MetronomeSettingsProvider.availableTickActions
                      .map((action) {
                    return DropdownMenuItem<String>(
                      value: action,
                      child: Text(
                        action,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newAction) {
                    if (newAction != null) {
                      settingsProvider.setTickAction(newAction);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMidiSendOnTickSetting(
      MetronomeSettingsProvider settingsProvider, MidiService midiService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.piano,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'MIDI Send on Tick:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _midiSendController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g., PC10, CC7:100, timing',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withAlpha(20)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withAlpha(20)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0468cc)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              errorText: _midiSendError,
            ),
            onChanged: (value) {
              final error = _validateMidiSendCommand(value);
              setState(() {
                _midiSendError = error;
              });
              // Update provider asynchronously but don't wait for it
              settingsProvider.setMidiSendOnTick(value);
            },
            onSubmitted: (value) {
              // Unfocus the text field to hide keyboard when ENTER is pressed
              FocusScope.of(context).unfocus();
            },
          ),
          const SizedBox(height: 8),
          // Test button
          Builder(
            builder: (context) {
              return Consumer<MidiService>(
                builder: (context, midiService, child) {
                  // Check controller text directly for immediate responsiveness
                  final hasText = _midiSendController.text.trim().isNotEmpty;
                  final isConnected = midiService.isConnected;
                  final hasNoError = _midiSendError == null;

                  // Re-enabled MIDI device check
                  final canTest = hasText && isConnected && hasNoError;

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canTest
                          ? () => _testMidiCommand(
                              context.read<MetronomeSettingsProvider>(),
                              midiService)
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: const Text('Test', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canTest
                            ? Colors.white.withAlpha(20)
                            : Colors.white.withAlpha(10),
                        foregroundColor:
                            canTest ? Colors.white : Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: canTest ? Colors.white24 : Colors.white12),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
