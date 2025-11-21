import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../../services/midi/midi_service.dart';
import 'metronome_test_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _midiSendController = TextEditingController();

    // Initialize MIDI service singleton
    MidiService();

    // Load current MIDI send setting into controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settingsProvider = context.read<MetronomeSettingsProvider>();
      final initialValue = settingsProvider.midiSendOnTick;
      _midiSendController.text = initialValue;
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

  void _attemptClose(BuildContext context) {
    if (_midiSendError != null) return;
    Navigator.of(context).pop();
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // App Modal Design Standard: Header button styling
        TextButton(
          onPressed:
              _midiSendError == null ? () => _attemptClose(context) : null,
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
          'Metronome Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // Test button (only when MIDI send is configured and device connected)
        Consumer<MetronomeSettingsProvider>(
          builder: (context, settingsProvider, child) {
            return Consumer<MidiService>(
              builder: (context, midiService, child) {
                final canTest = settingsProvider.midiSendOnTick.isNotEmpty &&
                    midiService.isConnected;

                return TextButton(
                  onPressed: canTest ? _startMetronomeTest : null,
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
                  child: const Text('Test', style: TextStyle(fontSize: 14)),
                );
              },
            );
          },
        ),
      ],
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
              'Count In Only',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: settingsProvider.countInOnly,
            onChanged: (value) {
              settingsProvider.setCountInOnly(value);
            },
            activeColor: const Color(0xFF0468cc),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white.withAlpha(30),
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
              settingsProvider.setMidiSendOnTick(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Enter MIDI commands to send on each metronome tick',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
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

  Future<void> _startMetronomeTest() async {
    await MetronomeTestDialog.show(context);
  }
}
