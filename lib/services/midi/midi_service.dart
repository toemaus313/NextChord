import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'dart:typed_data';

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
  MidiDevice? _connectedDevice;
  List<MidiDevice> _availableDevices = [];
  String? _errorMessage;

  // MIDI Configuration
  int _midiChannel = 0; // Internal storage: 0-15 (displayed as 1-16)

  // Getters
  MidiConnectionState get connectionState => _connectionState;
  MidiDevice? get connectedDevice => _connectedDevice;
  List<MidiDevice> get availableDevices => List.unmodifiable(_availableDevices);
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connectionState == MidiConnectionState.connected;
  bool get isScanning => _connectionState == MidiConnectionState.scanning;
  int get midiChannel => _midiChannel;

  /// Set the MIDI channel (1-16, displayed to user)
  void setMidiChannel(int channel) {
    if (channel < 1 || channel > 16) {
      throw ArgumentError('MIDI channel must be between 1 and 16');
    }
    _midiChannel = channel - 1; // Convert to 0-15 for MIDI protocol
    debugPrint(
        '🎹 MidiService: MIDI channel set to $channel (encoded as $_midiChannel)');
    notifyListeners();
  }

  /// Get the display MIDI channel (1-16)
  int get displayMidiChannel => _midiChannel + 1;

  /// Initialize the MIDI system on app startup
  Future<void> _initialize() async {
    try {
      debugPrint('🎹 MidiService: Initializing MIDI system...');

      // Start scanning for devices
      await scanForDevices();

      debugPrint('🎹 MidiService: MIDI system initialized successfully');
    } catch (e) {
      _setError('Failed to initialize MIDI: $e');
    }
  }

  /// Scan and list available MIDI devices (inputs and outputs)
  Future<void> scanForDevices() async {
    try {
      _setConnectionState(MidiConnectionState.scanning);
      _clearError();

      debugPrint('🎹 MidiService: Scanning for MIDI devices...');

      // Get all available MIDI devices
      final devices = await _midiCommand.devices ?? [];

      _availableDevices = devices;
      _setConnectionState(MidiConnectionState.disconnected);

      debugPrint('🎹 MidiService: Found ${devices.length} MIDI devices');
      for (final device in devices) {
        debugPrint('🎹 - ${device.name} (${device.type})');
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to scan for MIDI devices: $e');
      _setConnectionState(MidiConnectionState.disconnected);
    }
  }

  /// Connect to a selected MIDI device
  Future<bool> connectToDevice(MidiDevice device) async {
    try {
      _setConnectionState(MidiConnectionState.connecting);
      _clearError();

      debugPrint('🎹 MidiService: Connecting to ${device.name}...');

      // Disconnect from current device if connected
      if (_connectedDevice != null) {
        await _disconnectDevice();
      }

      // Connect to the new device
      await _midiCommand.connectToDevice(device);

      _connectedDevice = device;
      _setConnectionState(MidiConnectionState.connected);

      debugPrint('🎹 MidiService: Successfully connected to ${device.name}');
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Failed to connect to ${device.name}: $e');
      _setConnectionState(MidiConnectionState.disconnected);
      return false;
    }
  }

  /// Disconnect from the current MIDI device
  Future<void> _disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        debugPrint(
            '🎹 MidiService: Disconnecting from ${_connectedDevice!.name}...');
        // Note: Disconnect functionality may vary by platform
        _connectedDevice = null;
        debugPrint('🎹 MidiService: Disconnected successfully');
      }
    } catch (e) {
      _setError('Failed to disconnect: $e');
    }
  }

  /// Disconnect from the current MIDI device
  Future<void> disconnect() async {
    await _disconnectDevice();
    _setConnectionState(MidiConnectionState.disconnected);
    notifyListeners();
  }

  /// Send Program Change (PC) message to select a preset/patch
  ///
  /// [program]: Program number (0-127) - selects different presets/sounds on the device
  /// [channel]: MIDI channel (0-15, default 0) - which channel to send the message on
  ///
  /// Example: sendProgramChange(1) selects preset 1 on the connected device
  Future<bool> sendProgramChange(int program, {int channel = 0}) async {
    try {
      if (!isConnected || _connectedDevice == null) {
        _setError('No MIDI device connected');
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

      debugPrint(
          '🎹 MidiService: Sending Program Change $program on channel $channel');

      // Send Program Change message
      // MIDI Program Change: 0xC0 | channel, program
      final midiData = Uint8List.fromList([0xC0 | channel, program]);
      _midiCommand.sendData(midiData);

      debugPrint('🎹 MidiService: Program Change sent successfully');
      return true;
    } catch (e) {
      _setError('Failed to send Program Change: $e');
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
  /// Example: sendControlChange(7, 100) sets volume to ~78% on channel 0
  /// Example: sendControlChange(64, 127) enables sustain pedal on channel 0
  Future<bool> sendControlChange(int controller, int value,
      {int channel = 0}) async {
    try {
      if (!isConnected || _connectedDevice == null) {
        _setError('No MIDI device connected');
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

      debugPrint(
          '🎹 MidiService: Sending Control Change CC$controller=$value on channel $channel');

      // Send Control Change message
      // MIDI Control Change: 0xB0 | channel, controller, value
      final midiData = Uint8List.fromList([0xB0 | channel, controller, value]);
      _midiCommand.sendData(midiData);

      debugPrint('🎹 MidiService: Control Change sent successfully');
      return true;
    } catch (e) {
      _setError('Failed to send Control Change: $e');
      return false;
    }
  }

  /// Get the MIDI byte data for a Program Change message (for debugging)
  /// Returns the hex bytes that would be sent on the configured MIDI channel
  List<int> getProgramChangeBytes(int program) {
    // Validate input
    if (program < 0 || program > 127)
      throw ArgumentError('Program number must be between 0 and 127');

    // MIDI Program Change: 0xC0 | channel, program
    return [0xC0 | _midiChannel, program];
  }

  /// Get the MIDI byte data for a Control Change message (for debugging)
  /// Returns the hex bytes that would be sent on the configured MIDI channel
  List<int> getControlChangeBytes(int controller, int value) {
    // Validate inputs
    if (controller < 0 || controller > 127)
      throw ArgumentError('Controller number must be between 0 and 127');
    if (value < 0 || value > 127)
      throw ArgumentError('Control value must be between 0 and 127');

    // MIDI Control Change: 0xB0 | channel, controller, value
    return [0xB0 | _midiChannel, controller, value];
  }

  /// Get the MIDI Clock byte (for debugging)
  /// MIDI Clock is a real-time message: 0xF8
  List<int> getMidiClockBytes() {
    return [0xF8];
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

  /// Dispose the MIDI service and clean up resources
  @override
  void dispose() {
    debugPrint('🎹 MidiService: Disposing MIDI service...');
    disconnect();
    super.dispose();
  }

  // Private helper methods

  void _setConnectionState(MidiConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    debugPrint('🎹 MidiService Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
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
