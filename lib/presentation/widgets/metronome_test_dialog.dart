import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/metronome_provider.dart';
import '../providers/metronome_settings_provider.dart';
import '../../services/midi/midi_service.dart';

/// Dialog that shows real-time MIDI command streaming while metronome is running
class MetronomeTestDialog extends StatefulWidget {
  const MetronomeTestDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: const MetronomeTestDialog(),
      ),
    );
  }

  @override
  State<MetronomeTestDialog> createState() => _MetronomeTestDialogState();
}

class _MetronomeTestDialogState extends State<MetronomeTestDialog> {
  final List<String> _midiLog = [];
  final ScrollController _scrollController = ScrollController();
  final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();
  MetronomeProvider? _metronomeProvider;
  MetronomeSettingsProvider? _settingsProvider;
  MidiService? _midiService;
  Timer? _logCleanupTimer;
  bool _isStarting = true;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  @override
  void dispose() {
    _stopTest();
    _scrollController.dispose();
    _logStreamController.close();
    _logCleanupTimer?.cancel();
    super.dispose();
  }

  void _initializeTest() async {
    // Get providers
    _metronomeProvider = context.read<MetronomeProvider>();
    _settingsProvider = context.read<MetronomeSettingsProvider>();
    _midiService = MidiService();

    // Check if we can start the test
    if (_settingsProvider!.midiSendOnTick.isEmpty) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No MIDI command configured'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!_midiService!.isConnected) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No MIDI device connected'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Register MIDI logging action
    _metronomeProvider!
        .registerTickAction('midi_test_logging', _handleMidiTick);

    // Set metronome to 120 BPM
    _metronomeProvider!.setTempo(120);

    // Start metronome
    try {
      await _metronomeProvider!.start();
      setState(() {
        _isStarting = false;
      });
      _addLogEntry('🎵 Metronome started at 120 BPM');
      _addLogEntry('🎹 MIDI command: ${_settingsProvider!.midiSendOnTick}');

      // Start log cleanup timer (keep last 50 entries)
      _logCleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_midiLog.length > 50) {
          setState(() {
            _midiLog.removeRange(0, _midiLog.length - 50);
          });
        }
      });
    } catch (e) {
      _addLogEntry('❌ Failed to start metronome: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _stopTest() {
    _metronomeProvider?.unregisterTickAction('midi_test_logging');
    _metronomeProvider?.stop();
    _logCleanupTimer?.cancel();
  }

  Future<void> _handleMidiTick(int tickCount) async {
    if (_settingsProvider == null || _midiService == null) return;

    try {
      final midiCommand = _settingsProvider!.midiSendOnTick;
      if (midiCommand.isEmpty) return;

      if (!_midiService!.isConnected) {
        _addLogEntry('⚠️ MIDI device disconnected');
        return;
      }

      // Send MIDI command and log it with hex bytes
      await _sendMidiCommand(midiCommand, tickCount);
    } catch (e) {
      _addLogEntry('❌ Tick $tickCount: Error - $e');
    }
  }

  Future<void> _sendMidiCommand(String commandText, int tickCount) async {
    if (_midiService == null) return;

    final messages = commandText
        .split(',')
        .map((msg) => msg.trim())
        .where((msg) => msg.isNotEmpty);

    for (final message in messages) {
      final lowerMessage = message.toLowerCase();

      // Check timing command
      if (lowerMessage == 'timing') {
        await _midiService!.sendMidiClock();
        final hexBytes = _formatMidiBytes([0xF8]); // MIDI Clock timing byte
        _addLogEntry('🎹 Tick $tickCount: Sent timing -> $hexBytes');
      }
      // Parse Program Change: "PC10" or "PC:10"
      else if (lowerMessage.startsWith('pc')) {
        final pcMatch =
            RegExp(r'^pc(\d+)$', caseSensitive: false).firstMatch(message) ??
                RegExp(r'^pc:(\d+)$', caseSensitive: false).firstMatch(message);

        if (pcMatch != null) {
          final pcValue = int.tryParse(pcMatch.group(1)!);
          if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
            await _midiService!
                .sendProgramChange(pcValue, channel: _midiService!.midiChannel);
            final displayBytes = _formatMidiBytesReadable(
                [0xC0 | _midiService!.midiChannel, pcValue],
                ['status', 'program']);
            _addLogEntry(
                '🎹 Tick $tickCount: Sent PC$pcValue -> $displayBytes');
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
            await _midiService!.sendControlChange(controller, value,
                channel: _midiService!.midiChannel);
            final displayBytes = _formatMidiBytesReadable(
                [0xB0 | _midiService!.midiChannel, controller, value],
                ['status', 'controller', 'value']);
            _addLogEntry(
                '🎹 Tick $tickCount: Sent CC$controller:$value -> $displayBytes');
          }
        }
      }
    }
  }

  /// Format MIDI bytes as hexadecimal string for display
  String _formatMidiBytes(List<int> bytes) {
    return bytes
        .map((byte) =>
            '0x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}')
        .join(' ');
  }

  /// Format MIDI bytes with mixed format for readability
  /// Status bytes in hex, data bytes (controller/value) in decimal
  String _formatMidiBytesReadable(List<int> bytes, List<String> byteTypes) {
    return bytes.asMap().entries.map((entry) {
      final byte = entry.value;
      final type = entry.key < byteTypes.length ? byteTypes[entry.key] : 'data';

      if (type == 'status') {
        // Status byte in hex
        return '0x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}';
      } else {
        // Data bytes (controller, value, program) in decimal
        return byte.toString();
      }
    }).join(' ');
  }

  void _addLogEntry(String entry) {
    final timestamp = DateTime.now().toString().substring(11, 19); // HH:mm:ss
    final logEntry = '[$timestamp] $entry';

    setState(() {
      _midiLog.add(logEntry);
      // Keep only last 100 entries
      if (_midiLog.length > 100) {
        _midiLog.removeAt(0);
      }
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Also send to stream for potential external listeners
    _logStreamController.add(logEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 600,
        maxHeight: 500,
      ),
      decoration: BoxDecoration(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: _buildMidiLog(),
            ),
          ),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.piano,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Metronome MIDI Test',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isStarting
                  ? Colors.orange.withAlpha(30)
                  : (_metronomeProvider?.isRunning == true
                      ? Colors.green.withAlpha(30)
                      : Colors.red.withAlpha(30)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isStarting
                    ? Colors.orange
                    : (_metronomeProvider?.isRunning == true
                        ? Colors.green
                        : Colors.red),
              ),
            ),
            child: Text(
              _isStarting
                  ? 'Starting...'
                  : (_metronomeProvider?.isRunning == true
                      ? 'Running'
                      : 'Stopped'),
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

  Widget _buildMidiLog() {
    if (_isStarting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Starting metronome test...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_midiLog.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for metronome ticks...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _midiLog.length,
      itemBuilder: (context, index) {
        final entry = _midiLog[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            entry,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _midiLog.clear();
                });
                _addLogEntry('📋 Log cleared');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              child: const Text('Clear Log'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(100),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Stop Test'),
            ),
          ),
        ],
      ),
    );
  }
}
