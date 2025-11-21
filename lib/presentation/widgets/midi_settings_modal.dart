import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/midi/midi_service.dart';

/// Modal-style dialog for MIDI device selection and configuration
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class MidiSettingsModal extends StatefulWidget {
  const MidiSettingsModal({Key? key}) : super(key: key);

  /// Show the MIDI Settings modal
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: const MidiSettingsModal(),
      ),
    );
  }

  @override
  State<MidiSettingsModal> createState() => _MidiSettingsModalState();
}

class _MidiSettingsModalState extends State<MidiSettingsModal> {
  bool _isInitializing = true;
  String? _initError;
  bool _isTestStreamActive = false;

  @override
  void initState() {
    super.initState();
    _initializeMidiService();
  }

  Future<void> _initializeMidiService() async {
    try {
      // Initialize MIDI service singleton safely
      MidiService(); // Just initialize the singleton
      // Give it a moment to initialize
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('🎹 Error initializing MIDI service: $e');
      setState(() {
        _initError = e.toString();
        _isInitializing = false;
      });
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_initError != null) {
      return Center(
        child: AlertDialog(
          title: const Text('MIDI Error'),
          content: Text('Failed to initialize MIDI service: $_initError'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMidiChannelSetting(midiService),
                          const SizedBox(height: 12),
                          _buildMidiClockSetting(midiService),
                          const SizedBox(height: 12),
                          _buildConnectionStatus(midiService),
                          const SizedBox(height: 12),
                          _buildDeviceList(midiService),
                          const SizedBox(height: 12),
                          _buildActionButtons(midiService),
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
          'MIDI Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // Test button (only when connected)
        Consumer<MidiService>(
          builder: (context, midiService, child) {
            return TextButton(
              onPressed: midiService.isConnected ? _toggleTestStream : null,
              style: TextButton.styleFrom(
                foregroundColor:
                    _isTestStreamActive ? Colors.red : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                      color: _isTestStreamActive ? Colors.red : Colors.white24),
                ),
              ),
              child: Text(_isTestStreamActive ? 'Stop Test' : 'Test',
                  style: const TextStyle(fontSize: 14)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMidiChannelSetting(MidiService midiService) {
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
            Icons.tune,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'MIDI Channel:',
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
                child: DropdownButton<int>(
                  value: midiService.displayMidiChannel,
                  isExpanded: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  dropdownColor: const Color(0xFF0468cc),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: List.generate(16, (index) {
                    return DropdownMenuItem<int>(
                      value: index + 1, // Display as 1-16
                      child: Text(
                        'Channel ${index + 1}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    );
                  }),
                  onChanged: (int? newChannel) {
                    if (newChannel != null) {
                      midiService.setMidiChannel(newChannel);
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

  Widget _buildMidiClockSetting(MidiService midiService) {
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
            Icons.schedule,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Send MIDI Clock:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Send 2-second clock stream when songs open',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: midiService.sendMidiClockEnabled,
            onChanged: (value) {
              midiService.setSendMidiClock(value);
            },
            activeColor: const Color(0xFF0468cc),
            activeTrackColor: Colors.white.withAlpha(80),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withAlpha(30),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(MidiService midiService) {
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
        statusText = 'Scanning for devices...';
        statusIcon = Icons.search;
        break;
      case MidiConnectionState.error:
        statusColor = Colors.red;
        statusText = midiService.errorMessage ?? 'Error';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Disconnected';
        statusIcon = Icons.bluetooth_disabled;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (midiService.connectionState == MidiConnectionState.scanning ||
              midiService.connectionState == MidiConnectionState.connecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(MidiService midiService) {
    if (midiService.isScanning) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Scanning for MIDI devices...',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (midiService.availableDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 48,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'No MIDI devices found',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Connect your MIDI device and tap "Scan"',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'DEVICES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${midiService.availableDevices.length} found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(midiService.availableDevices.length, (index) {
          final device = midiService.availableDevices[index];
          final isConnected = midiService.connectedDevice?.id == device.id;
          return _buildDeviceTile(device, isConnected, midiService);
        }),
      ],
    );
  }

  Widget _buildDeviceTile(device, bool isConnected, MidiService midiService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.white.withAlpha(20)
            : Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.white.withAlpha(50) : Colors.white12,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(
          device.type == 'input' ? Icons.keyboard : Icons.speaker,
          color: isConnected ? Colors.white : Colors.white70,
          size: 20,
        ),
        title: Text(
          device.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isConnected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${device.type.toUpperCase()} • ${device.connected ? 'Connected' : 'Available'}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        trailing: isConnected
            ? TextButton.icon(
                onPressed: () async {
                  await midiService.disconnect();
                },
                icon: const Icon(Icons.link_off, size: 14),
                label: const Text('Disconnect'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(100),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            : TextButton.icon(
                onPressed: midiService.connectionState ==
                        MidiConnectionState.connecting
                    ? null
                    : () async {
                        await midiService.connectToDevice(device);
                      },
                icon: midiService.connectionState ==
                        MidiConnectionState.connecting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.link, size: 14),
                label: Text(midiService.connectionState ==
                        MidiConnectionState.connecting
                    ? 'Connecting'
                    : 'Connect'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(20),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActionButtons(MidiService midiService) {
    return Column(
      children: [
        // Scan Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: midiService.isScanning
                ? null
                : () async {
                    await midiService.scanForDevices();
                  },
            icon: midiService.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(
                midiService.isScanning ? 'Scanning...' : 'Scan for Devices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _toggleTestStream,
            icon: _isTestStreamActive
                ? const Icon(Icons.stop, size: 16)
                : const Icon(Icons.play_arrow, size: 16),
            label: Text(
                _isTestStreamActive ? 'Stop Test Stream' : 'Start Test Stream'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTestStreamActive
                  ? Colors.red.withAlpha(100)
                  : Colors.white.withAlpha(20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Toggle the test stream on/off
  Future<void> _toggleTestStream() async {
    final midiService = MidiService();

    if (_isTestStreamActive) {
      debugPrint('🎹 MIDI DEBUG: Stopping test stream...');
      setState(() {
        _isTestStreamActive = false;
      });
      try {
        await midiService.sendMidiStop();
        debugPrint('🎹 MIDI DEBUG: MIDI Stop sent to stop test stream');
      } catch (e) {
        debugPrint('🎹 MIDI DEBUG: ERROR sending MIDI Stop: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test stream stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    debugPrint('🎹 MIDI DEBUG: Starting test stream...');
    setState(() {
      _isTestStreamActive = true;
    });

    try {
      debugPrint('🎹 MIDI DEBUG: Sending CC0:0...');
      await midiService.sendControlChange(0, 0); // CC0:0
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('🎹 MIDI DEBUG: Sending PC13...');
      await midiService.sendProgramChange(13); // PC13
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_isTestStreamActive) {
        return;
      }

      debugPrint('🎹 MIDI DEBUG: Sending 30 BPM test stream...');
      await midiService.sendMidiClockStream(durationSeconds: 2, bpm: 30);

      if (!_isTestStreamActive) {
        return;
      }

      debugPrint('🎹 MIDI DEBUG: Sending 170 BPM test stream...');
      await midiService.sendMidiClockStream(durationSeconds: 2, bpm: 170);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Test stream completed - CC0:0, PC13, and timing sweeps'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('🎹 MIDI DEBUG: ERROR running test stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running test stream: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestStreamActive = false;
        });
      }
    }
  }
}
