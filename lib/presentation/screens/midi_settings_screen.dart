import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/midi/midi_service.dart';

/// Screen for MIDI device selection and testing
class MidiSettingsScreen extends StatefulWidget {
  const MidiSettingsScreen({Key? key}) : super(key: key);

  @override
  State<MidiSettingsScreen> createState() => _MidiSettingsScreenState();
}

class _MidiSettingsScreenState extends State<MidiSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize MIDI service singleton
    MidiService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDI Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<MidiService>(
        builder: (context, midiService, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status Card
                _buildConnectionStatusCard(midiService),
                const SizedBox(height: 20),

                // Device List
                Expanded(
                  child: _buildDeviceList(midiService),
                ),

                // Action Buttons
                _buildActionButtons(midiService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusCard(MidiService midiService) {
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
            if (midiService.connectionState == MidiConnectionState.scanning ||
                midiService.connectionState == MidiConnectionState.connecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(MidiService midiService) {
    if (midiService.isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for MIDI devices...'),
          ],
        ),
      );
    }

    if (midiService.availableDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No MIDI devices found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your MIDI device and tap "Scan for Devices"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available MIDI Devices',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: midiService.availableDevices.length,
            itemBuilder: (context, index) {
              final device = midiService.availableDevices[index];
              final isConnected = midiService.connectedDevice?.id == device.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isConnected ? 4 : 1,
                color: isConnected ? Colors.blue.withValues(alpha: 0.1) : null,
                child: ListTile(
                  leading: Icon(
                    device.type == 'input' ? Icons.keyboard : Icons.speaker,
                    color: isConnected ? Colors.blue : Colors.grey[600],
                  ),
                  title: Text(
                    device.name,
                    style: TextStyle(
                      fontWeight:
                          isConnected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${device.type.toUpperCase()} • ${device.connected ? 'Connected' : 'Available'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: isConnected
                      ? ElevatedButton.icon(
                          onPressed: () async {
                            await midiService.disconnect();
                          },
                          icon: const Icon(Icons.link_off, size: 16),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: midiService.connectionState ==
                                  MidiConnectionState.connecting
                              ? null
                              : () async {
                                  await midiService.connectToDevice(device);
                                },
                          icon: midiService.connectionState ==
                                  MidiConnectionState.connecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.link, size: 16),
                          label: Text(midiService.connectionState ==
                                  MidiConnectionState.connecting
                              ? 'Connecting'
                              : 'Connect'),
                        ),
                ),
              );
            },
          ),
        ),
      ],
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
                midiService.isScanning ? 'Scanning...' : 'Scan for Devices'),
          ),
        ),

        // Test MIDI Button (only when connected)
        if (midiService.isConnected) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTestMidiDialog(),
              icon: const Icon(Icons.music_note),
              label: const Text('Test MIDI Messages'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showTestMidiDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test MIDI Messages'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will send test MIDI messages to verify the connection:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('• Program Change: Select presets 1, 5, 10'),
            Text('• Control Change: Adjust volume, pan, modulation'),
            SizedBox(height: 12),
            Text(
              'Make sure your MIDI device is ready to receive messages!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendTestMessages();
            },
            child: const Text('Send Test Messages'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestMessages() async {
    final midiService = MidiService();

    try {
      // Send Program Change messages (select presets 1, 5, 10)
      await midiService.sendProgramChange(1);
      await Future.delayed(const Duration(milliseconds: 500));

      await midiService.sendProgramChange(5);
      await Future.delayed(const Duration(milliseconds: 500));

      await midiService.sendProgramChange(10);
      await Future.delayed(const Duration(milliseconds: 500));

      // Send Control Change messages (volume, pan, modulation)
      await midiService.sendControlChange(7, 100); // Volume to ~78%
      await Future.delayed(const Duration(milliseconds: 500));

      await midiService.sendControlChange(10, 64); // Pan to center
      await Future.delayed(const Duration(milliseconds: 500));

      await midiService.sendControlChange(1, 64); // Modulation to center
      await Future.delayed(const Duration(milliseconds: 500));

      // Reset to default values
      await midiService.sendProgramChange(0); // Preset 0
      await midiService.sendControlChange(7, 127); // Volume full
      await midiService.sendControlChange(10, 64); // Pan center
      await midiService.sendControlChange(1, 0); // Modulation off

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test MIDI messages sent successfully!'),
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
}
