import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextchord/main.dart' as main;

/// MIDI Service singleton for managing MIDI device connections and message sending

///
/// MIDI (Musical Instrument Digital Interface) is a protocol that allows electronic
/// musical instruments, computers, and other devices to communicate with each other.
///
/// **Program Change (PC) Messages**: Select a preset/patch on a MIDI device.
/// - Range: 0-127 (selects different presets/sounds)
/// - Example: PC 1 selects preset 1, PC 16 selects preset 16
///
/// **Control Change (CC) Messages**: Adjust a parameter on a MIDI device.
/// - Controller range: 0-127 (different controllers like volume, pan, sustain)
/// - Value range: 0-127 (parameter values)
/// - Example: CC 7 with value 100 sets volume to ~78%, CC 64 with value 127 enables sustain pedal
///
/// **MIDI Value Ranges**: Most MIDI values use 7-bit resolution (0-127)
/// - 0 = Minimum/off
/// - 64 = Center position (for pan, etc.)
/// - 127 = Maximum/on
class MidiService with ChangeNotifier {
  static final MidiService _instance = MidiService._internal();
  factory MidiService() => _instance;
  MidiService._internal() {
    _initialize();
  }

  final MidiCommand _midiCommand = MidiCommand();

  // Connection state
  MidiConnectionState _connectionState = MidiConnectionState.disconnected;
  List<MidiDevice> _connectedDevices = [];
  List<MidiDevice> _availableDevices = [];
  String? _errorMessage;
  List<String> _preferredDeviceIds = [];

  // MIDI Configuration
  int _midiChannel = 0; // Internal storage: 0-15 (displayed as 1-16)
  bool _sendMidiClockEnabled = false; // Send MIDI clock when songs are opened
  bool _isDisposed = false; // Track disposal state

  // Getters
  MidiConnectionState get connectionState => _connectionState;
  List<MidiDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  MidiDevice? get connectedDevice =>
      _connectedDevices.isNotEmpty ? _connectedDevices.first : null;
  List<MidiDevice> get availableDevices => List.unmodifiable(_availableDevices);
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connectedDevices.isNotEmpty;
  bool get isScanning => _connectionState == MidiConnectionState.scanning;
  int get midiChannel => _midiChannel;
  bool get sendMidiClockEnabled => _sendMidiClockEnabled;
  bool get isDisposed => _isDisposed;
  int get connectedDeviceCount => _connectedDevices.length;

  /// Set the MIDI channel (1-16, displayed to user)
  void setMidiChannel(int channel) {
    if (channel < 1 || channel > 16) {
      throw ArgumentError('MIDI channel must be between 1 and 16');
    }
    _midiChannel = channel - 1; // Convert to 0-15 for MIDI protocol
    _saveSettings();
    notifyListeners();
  }

  /// Set whether to send MIDI clock when songs are opened
  void setSendMidiClock(bool enabled) {
    _sendMidiClockEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }

  /// Send MIDI clock stream for specified duration, aligning with song tempo.
  ///
  /// Streams MIDI Clock (0xF8) at the tempo-derived interval for
  /// [durationSeconds] without start/stop messages so some devices can latch onto
  /// the continuous timing pulses directly.
  Future<void> sendMidiClockStream({
    int durationSeconds = 2,
    int? bpm,
  }) async {
    if (_isDisposed) {
      return;
    }

    if (_connectedDevices.isEmpty) {
      return;
    }

    final effectiveBpm = (bpm != null && bpm > 0) ? bpm : 120;
    final clockIntervalMs = 60000 / (effectiveBpm * 24);
    final intervalMicros = (clockIntervalMs * 1000).round().clamp(1, 999999);
    final clockInterval = Duration(microseconds: intervalMicros);

    final endTime = DateTime.now().add(Duration(seconds: durationSeconds));
    final clockData = Uint8List.fromList([0xF8]);
    final tickTimestamps = <DateTime>[];
    var nextTickTime = DateTime.now().add(clockInterval);

    while (DateTime.now().isBefore(endTime) && !_isDisposed) {
      final now = DateTime.now();
      _midiCommand.sendData(clockData);
      tickTimestamps.add(now);
      final delay = nextTickTime.difference(DateTime.now());
      nextTickTime = nextTickTime.add(clockInterval);
      await Future.delayed(delay.isNegative ? Duration.zero : delay);
    }

    final tickCount = tickTimestamps.length;
    if (tickCount < 2 || _isDisposed) {
      return;
    }

    var totalInterval = 0.0;
    for (var i = 1; i < tickCount; i++) {
      totalInterval += tickTimestamps[i]
              .difference(tickTimestamps[i - 1])
              .inMicroseconds
              .toDouble() /
          1000;
    }
    // Calculate actual interval for potential future use
    totalInterval / (tickCount - 1);
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _midiChannel = prefs.getInt('new_midi_channel') ?? 0;
      _sendMidiClockEnabled = prefs.getBool('new_send_midi_clock') ?? false;
      final preferredIds = prefs.getStringList('preferred_midi_device_ids');
      _preferredDeviceIds = preferredIds ?? [];
    } catch (e) {
      main.myDebug('[MidiService] Failed to load MIDI settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('new_midi_channel', _midiChannel);
      await prefs.setBool('new_send_midi_clock', _sendMidiClockEnabled);
      await prefs.setStringList(
          'preferred_midi_device_ids', _preferredDeviceIds);
    } catch (e) {
      main.myDebug('[MidiService] Failed to save MIDI settings: $e');
    }
  }

  Future<void> _savePreferredDeviceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'preferred_midi_device_ids', _preferredDeviceIds);
    } catch (e) {
      main.myDebug(
          '[MidiService] Failed to save preferred MIDI device IDs: $e');
    }
  }

  /// Get the display MIDI channel (1-16)
  int get displayMidiChannel => _midiChannel + 1;

  /// Initialize the MIDI system on app startup
  Future<void> _initialize() async {
    try {
      // Load saved settings first
      await _loadSettings();

      // Start scanning for devices
      await scanForDevices();
    } catch (e) {
      main.myDebug('[MidiService] Initialization failed: $e');
    }
  }

  /// Scan and list available MIDI devices (inputs and outputs)
  Future<void> scanForDevices() async {
    try {
      _setConnectionState(MidiConnectionState.scanning);
      _clearError();

      // Get all available MIDI devices
      final devices = await _midiCommand.devices ?? [];

      _availableDevices = devices;

      _setConnectionState(MidiConnectionState.disconnected);

      notifyListeners();
      await _autoConnectToPreferredDevice();
    } catch (e) {
      _setConnectionState(MidiConnectionState.disconnected);
    }
  }

  /// Connect to a selected MIDI device (adds to existing connections)
  Future<bool> connectToDevice(MidiDevice device) async {
    try {
      _clearError();

      // Check if already connected
      if (_connectedDevices.any((d) => d.id == device.id)) {
        return true; // Already connected
      }

      // Connect to the new device
      await _midiCommand.connectToDevice(device);

      _connectedDevices.add(device);

      // Update preferred devices list
      if (!_preferredDeviceIds.contains(device.id)) {
        _preferredDeviceIds.add(device.id);
        await _savePreferredDeviceIds();
      }

      // Update connection state
      if (_connectedDevices.isNotEmpty) {
        _setConnectionState(MidiConnectionState.connected);
      }

      notifyListeners();
      return true;
    } catch (e) {
      final message = e is PlatformException ? e.message ?? '' : e.toString();
      if (message.contains('Device already connected')) {
        // Device is already connected at the system level
        if (!_connectedDevices.any((d) => d.id == device.id)) {
          _connectedDevices.add(device);
          if (!_preferredDeviceIds.contains(device.id)) {
            _preferredDeviceIds.add(device.id);
            await _savePreferredDeviceIds();
          }
          if (_connectedDevices.isNotEmpty) {
            _setConnectionState(MidiConnectionState.connected);
          }
          notifyListeners();
        }
        return true;
      }

      _setError('Failed to connect to ${device.name}: $message');
      return false;
    }
  }

  /// Disconnect from a specific MIDI device
  Future<bool> disconnectFromDevice(MidiDevice device) async {
    try {
      _connectedDevices.removeWhere((d) => d.id == device.id);

      if (_connectedDevices.isEmpty) {
        _setConnectionState(MidiConnectionState.disconnected);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to disconnect from ${device.name}: $e');
      return false;
    }
  }

  /// Disconnect from all MIDI devices
  Future<void> disconnect() async {
    _connectedDevices.clear();
    _setConnectionState(MidiConnectionState.disconnected);
    notifyListeners();
  }

  /// Send Program Change (PC) message to select a preset/patch
  ///
  /// [program]: Program number (0-127) - selects different presets/sounds on the device
  /// [channel]: MIDI channel (0-15, default 0) - which channel to send the message on
  ///
  /// Example: sendProgramChange(1) selects preset 1 on all connected devices
  Future<bool> sendProgramChange(int program, {int channel = 0}) async {
    if (_isDisposed) {
      return false;
    }

    try {
      if (_connectedDevices.isEmpty) {
        _setError('No MIDI devices connected');
        return false;
      }

      // Validate program number (0-127)
      if (program < 0 || program > 127) {
        _setError('Program number must be between 0 and 127');
        return false;
      }

      // Validate channel (0-15)
      if (channel < 0 || channel > 15) {
        _setError('MIDI channel must be between 0 and 15');
        return false;
      }

      // Send Program Change message to all connected devices
      // MIDI Program Change: 0xC0 | channel, program
      final midiData = Uint8List.fromList([0xC0 | channel, program]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send Control Change (CC) message to adjust a parameter
  ///
  /// [controller]: Controller number (0-127) - which parameter to control
  /// - Common controllers: 0=Bank Select, 1=Modulation, 7=Volume, 10=Pan, 64=Sustain
  /// [value]: Controller value (0-127) - the parameter value
  /// [channel]: MIDI channel (0-15, default 0) - which channel to send the message on
  ///
  /// Example: sendControlChange(7, 100) sets volume to ~78% on all devices
  /// Example: sendControlChange(64, 127) enables sustain pedal on all devices
  Future<bool> sendControlChange(int controller, int value,
      {int channel = 0}) async {
    if (_isDisposed) {
      return false;
    }

    try {
      if (_connectedDevices.isEmpty) {
        _setError('No MIDI devices connected');
        return false;
      }

      // Validate controller number (0-127)
      if (controller < 0 || controller > 127) {
        _setError('Controller number must be between 0 and 127');
        return false;
      }

      // Validate value (0-127)
      if (value < 0 || value > 127) {
        _setError('Control value must be between 0 and 127');
        return false;
      }

      // Validate channel (0-15)
      if (channel < 0 || channel > 15) {
        _setError('MIDI channel must be between 0 and 15');
        return false;
      }

      // Send Control Change message to all connected devices
      // MIDI Control Change: 0xB0 | channel, controller, value
      final midiData = Uint8List.fromList([0xB0 | channel, controller, value]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format MIDI bytes as hex and decimal string for display
  String formatMidiBytes(List<int> bytes) {
    return bytes
        .map((byte) =>
            '0x${byte.toRadixString(16).toUpperCase().padLeft(2, '0')} ($byte)')
        .join(', ');
  }

  /// Get a human-readable description for common MIDI controllers
  String getControllerDescription(int controller) {
    switch (controller) {
      case 0:
        return 'Bank Select';
      case 1:
        return 'Modulation Wheel';
      case 7:
        return 'Volume';
      case 10:
        return 'Pan';
      case 11:
        return 'Expression';
      case 64:
        return 'Sustain Pedal';
      case 65:
        return 'Portamento';
      case 66:
        return 'Sostenuto';
      case 67:
        return 'Soft Pedal';
      case 91:
        return 'Reverb Level';
      case 93:
        return 'Chorus Level';
      default:
        return 'Controller $controller';
    }
  }

  /// Send MIDI Clock message (real-time message: 0xF8)
  /// Used for timing synchronization with MIDI devices
  Future<bool> sendMidiClock() async {
    if (_isDisposed) {
      return false;
    }

    try {
      if (_connectedDevices.isEmpty) {
        _setError('No MIDI devices connected');
        return false;
      }

      // MIDI Clock is a real-time message (0xF8) - doesn't use channel
      final midiData = Uint8List.fromList([0xF8]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send MIDI Start message (0xFA)
  Future<bool> sendMidiStart() async {
    try {
      if (_connectedDevices.isEmpty) {
        _setError('No MIDI devices connected');
        return false;
      }

      final midiData = Uint8List.fromList([0xFA]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send MIDI Stop message (0xFC)
  Future<bool> sendMidiStop() async {
    try {
      if (_connectedDevices.isEmpty) {
        _setError('No MIDI devices connected');
        return false;
      }

      final midiData = Uint8List.fromList([0xFC]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dispose the MIDI service and clean up resources
  @override
  void dispose() {
    if (_isDisposed) return; // Prevent multiple disposals

    _isDisposed = true;
    disconnect();
    super.dispose();
  }

  // Private helper methods

  void _setConnectionState(MidiConnectionState state) {
    if (_isDisposed) return;
    _connectionState = state;
    notifyListeners();
  }

  void _setError(String error) {
    if (_isDisposed) return;
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _autoConnectToPreferredDevice() async {
    if (_availableDevices.isEmpty) {
      return;
    }

    if (_connectedDevices.isNotEmpty) {
      return;
    }

    // Connect to all preferred devices that are available
    for (final preferredId in _preferredDeviceIds) {
      for (final device in _availableDevices) {
        if (device.id == preferredId) {
          await connectToDevice(device);
          break; // Move to next preferred device
        }
      }
    }
  }
}

/// Extension to add connection state enum if not already defined
enum MidiConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}
