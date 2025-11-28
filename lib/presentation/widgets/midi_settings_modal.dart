import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/midi/midi_service.dart';
import '../providers/appearance_provider.dart';
import 'templates/standard_modal_template.dart';

/// MIDI Settings Modal - Using StandardModalTemplate
class MidiSettingsModal extends StatefulWidget {
  const MidiSettingsModal({Key? key}) : super(key: key);

  /// Show the MIDI Settings modal
  static Future<void> show(BuildContext context) {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: false,
      child: const MidiSettingsModal(),
    );
  }

  @override
  State<MidiSettingsModal> createState() => _MidiSettingsModalState();
}

class _MidiSettingsModalState extends State<MidiSettingsModal> {
  bool _isInitializing = true;
  String? _initError;

  // Store original values for cancel functionality
  late int _originalMidiChannel;
  late bool _originalSendMidiClock;

  @override
  void initState() {
    super.initState();
    _initializeMidiService();
  }

  Future<void> _initializeMidiService() async {
    try {
      // Initialize MIDI service singleton safely
      final midiService = MidiService(); // Just initialize the singleton
      // Give it a moment to initialize
      await Future.delayed(const Duration(milliseconds: 100));

      // Store original values after initialization
      if (mounted) {
        _originalMidiChannel = midiService.displayMidiChannel;
        _originalSendMidiClock = midiService.sendMidiClockEnabled;
      }
    } catch (e) {
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
    return Consumer<AppearanceProvider>(
      builder: (context, appearanceProvider, child) {
        if (_isInitializing) {
          return StandardModalTemplate.buildModalContainer(
            context: context,
            appearanceProvider: appearanceProvider,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_initError != null) {
          return StandardModalTemplate.buildModalContainer(
            context: context,
            appearanceProvider: appearanceProvider,
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
            return StandardModalTemplate.buildModalContainer(
              context: context,
              appearanceProvider: appearanceProvider,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StandardModalTemplate.buildHeader(
                    context: context,
                    title: 'MIDI Settings',
                    onCancel: () => _cancelChanges(context, midiService),
                    onOk: () => _saveChanges(context, midiService),
                  ),
                  StandardModalTemplate.buildContent(
                    children: [
                      _buildMidiChannelSetting(midiService),
                      const SizedBox(height: 8),
                      _buildMidiClockSetting(midiService),
                      const SizedBox(height: 8),
                      _buildConnectionStatus(midiService),
                      const SizedBox(height: 8),
                      _buildDeviceList(midiService),
                      const SizedBox(height: 8),
                      _buildActionButtons(midiService),
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

  Widget _buildMidiChannelSetting(MidiService midiService) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.tune,
      label: 'MIDI Channel',
      control: StandardModalTemplate.buildDropdown<int>(
        value: midiService.displayMidiChannel,
        items: List.generate(16, (index) {
          final channel = index + 1;
          return DropdownMenuItem<int>(
            value: channel,
            child: Text(
              'Channel $channel',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }),
        onChanged: (int? newChannel) {
          if (newChannel != null) {
            midiService.setMidiChannel(newChannel);
          }
        },
      ),
    );
  }

  Widget _buildMidiClockSetting(MidiService midiService) {
    return StandardModalTemplate.buildSettingRow(
      icon: Icons.schedule,
      label: 'Send MIDI Clock',
      control: Switch(
        value: midiService.sendMidiClockEnabled,
        onChanged: (value) {
          midiService.setSendMidiClock(value);
        },
        activeThumbColor: const Color(0xFF0468cc),
        activeTrackColor: Colors.white.withAlpha(80),
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white.withAlpha(30),
      ),
    );
  }

  Widget _buildConnectionStatus(MidiService midiService) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (midiService.connectedDevices.isEmpty) {
      statusColor = Colors.grey;
      statusText = 'Disconnected';
      statusIcon = Icons.bluetooth_disabled;
    } else if (midiService.connectedDevices.length == 1) {
      statusColor = Colors.green;
      statusText = 'Connected to ${midiService.connectedDevices.first.name}';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.green;
      statusText = 'Connected to ${midiService.connectedDeviceCount} devices';
      statusIcon = Icons.check_circle;
    }

    return StandardModalTemplate.buildInfoBox(
      icon: statusIcon,
      text: statusText,
      color: statusColor,
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
          final isConnected =
              midiService.connectedDevices.any((d) => d.id == device.id);
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
        leading: Checkbox(
          value: isConnected,
          onChanged: (bool? value) async {
            if (value == true) {
              await midiService.connectToDevice(device);
            } else {
              await midiService.disconnectFromDevice(device);
            }
          },
          activeColor: const Color(0xFF0468cc),
          checkColor: Colors.white,
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
                  await midiService.disconnectFromDevice(device);
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
        StandardModalTemplate.buildButton(
          label: midiService.isScanning ? 'Scanning...' : 'Scan for Devices',
          icon: Icons.refresh,
          onPressed: midiService.isScanning
              ? null
              : () async {
                  await midiService.scanForDevices();
                },
        ),
      ],
    );
  }

  /// Cancel changes and restore original values
  void _cancelChanges(BuildContext context, MidiService midiService) {
    midiService.setMidiChannel(_originalMidiChannel);
    midiService.setSendMidiClock(_originalSendMidiClock);
    Navigator.of(context).pop();
  }

  /// Save changes and close modal
  void _saveChanges(BuildContext context, MidiService midiService) {
    Navigator.of(context).pop();
  }
}
