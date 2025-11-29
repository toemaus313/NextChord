import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/midi_message.dart';

/// Manages multiple MIDI device connections and inbound/outbound message routing
class MidiDeviceManager extends ChangeNotifier {
  static final MidiDeviceManager _instance = MidiDeviceManager._internal();
  factory MidiDeviceManager() => _instance;
  MidiDeviceManager._internal() {
    _initialize();
  }

  /// Initialize the MIDI device manager
  void _initialize() {
    // Set up MIDI data listener
    _midiCommand.onMidiDataReceived?.listen(_handleIncomingMidiPacket);
  }

  final MidiCommand _midiCommand = MidiCommand();

  // Device management
  final Map<String, MidiDevice> _connectedDevices = {};
  final Map<String, MidiDeviceRef> _deviceRefs = {};
  List<MidiDevice> _availableDevices = [];
  String? _errorMessage;
  bool _isDisposed = false;

  // Message streams
  final StreamController<MidiMessage> _messageController =
      StreamController<MidiMessage>.broadcast();
  final StreamController<List<MidiDeviceRef>> _deviceListController =
      StreamController<List<MidiDeviceRef>>.broadcast();

  // Getters
  Map<String, MidiDevice> get connectedDevices =>
      Map.unmodifiable(_connectedDevices);
  List<MidiDeviceRef> get connectedDeviceRefs => _deviceRefs.values.toList();
  List<MidiDevice> get availableDevices => List.unmodifiable(_availableDevices);
  String? get errorMessage => _errorMessage;
  bool get isDisposed => _isDisposed;

  /// Stream of inbound MIDI messages from all connected devices
  Stream<MidiMessage> get messageStream => _messageController.stream;

  /// Stream of device connection changes
  Stream<List<MidiDeviceRef>> get deviceListStream =>
      _deviceListController.stream;

  /// Scan for available MIDI devices
  Future<void> scanForDevices() async {
    if (_isDisposed) return;

    try {
      _clearError();
      final devices = await _midiCommand.devices ?? [];
      _availableDevices = devices;
      notifyListeners();
    } catch (e) {
      _setError('Failed to scan for MIDI devices: ${e.toString()}');
    }
  }

  /// Connect to a specific MIDI device
  Future<bool> connectToDevice(MidiDevice device) async {
    if (_isDisposed) return false;

    try {
      _clearError();

      // Check if already connected
      if (_connectedDevices.containsKey(device.id)) {
        return true;
      }

      // Connect to the device
      await _midiCommand.connectToDevice(device);

      // Track the connection
      _connectedDevices[device.id] = device;
      _deviceRefs[device.id] = MidiDeviceRef.fromMidiDevice(device);

      // Save to preferences
      await _savePreferredDeviceIds();

      // Notify listeners
      notifyListeners();
      _deviceListController.add(connectedDeviceRefs);

      return true;
    } catch (e) {
      _setError('Failed to connect to ${device.name}: ${e.toString()}');
      return false;
    }
  }

  /// Disconnect from a specific MIDI device
  Future<void> disconnectFromDevice(String deviceId) async {
    if (_isDisposed) return;

    try {
      _clearError();

      final device = _connectedDevices[deviceId];
      if (device != null) {
        // Note: flutter_midi_command doesn't have explicit disconnect per device
        // We'll remove it from our tracking and rely on the plugin's cleanup
        _connectedDevices.remove(deviceId);
        _deviceRefs.remove(deviceId);

        await _savePreferredDeviceIds();
        notifyListeners();
        _deviceListController.add(connectedDeviceRefs);
      }
    } catch (e) {
      _setError('Failed to disconnect from device: ${e.toString()}');
    }
  }

  /// Disconnect from all MIDI devices
  Future<void> disconnectAll() async {
    if (_isDisposed) return;

    try {
      _clearError();

      _connectedDevices.clear();
      _deviceRefs.clear();

      await _savePreferredDeviceIds();
      notifyListeners();
      _deviceListController.add([]);
    } catch (e) {
      _setError('Failed to disconnect all devices: ${e.toString()}');
    }
  }

  /// Send a Control Change message to a specific device
  Future<bool> sendControlChange(
    String deviceId,
    int controller,
    int value, {
    int channel = 0,
  }) async {
    if (_isDisposed) return false;

    try {
      final device = _connectedDevices[deviceId];
      if (device == null) {
        _setError('Device $deviceId is not connected');
        return false;
      }

      // Validate parameters
      if (controller < 0 || controller > 127) {
        _setError('Controller number must be between 0 and 127');
        return false;
      }
      if (value < 0 || value > 127) {
        _setError('Control value must be between 0 and 127');
        return false;
      }
      if (channel < 0 || channel > 15) {
        _setError('MIDI channel must be between 0 and 15');
        return false;
      }

      // Send Control Change message
      final midiData = Uint8List.fromList([0xB0 | channel, controller, value]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      _setError('Failed to send CC: ${e.toString()}');
      return false;
    }
  }

  /// Send a Program Change message to a specific device
  Future<bool> sendProgramChange(
    String deviceId,
    int program, {
    int channel = 0,
  }) async {
    if (_isDisposed) return false;

    try {
      final device = _connectedDevices[deviceId];
      if (device == null) {
        _setError('Device $deviceId is not connected');
        return false;
      }

      // Validate parameters
      if (program < 0 || program > 127) {
        _setError('Program number must be between 0 and 127');
        return false;
      }
      if (channel < 0 || channel > 15) {
        _setError('MIDI channel must be between 0 and 15');
        return false;
      }

      // Send Program Change message
      final midiData = Uint8List.fromList([0xC0 | channel, program]);
      _midiCommand.sendData(midiData);

      return true;
    } catch (e) {
      _setError('Failed to send PC: ${e.toString()}');
      return false;
    }
  }

  /// Send a message to all connected devices
  Future<bool> sendToAllDevices(Function(String) sendFunction) async {
    if (_isDisposed) return false;

    try {
      bool allSucceeded = true;

      for (final deviceId in _connectedDevices.keys) {
        final success = sendFunction(deviceId);
        if (!success) {
          allSucceeded = false;
        }
      }

      return allSucceeded;
    } catch (e) {
      _setError('Failed to send to all devices: ${e.toString()}');
      return false;
    }
  }

  /// Handle incoming MIDI packet from any connected device
  void _handleIncomingMidiPacket(MidiPacket packet) {
    if (_isDisposed) return;

    try {
      // Extract data from MidiPacket
      final data = packet.data;

      // Since flutter_midi_command doesn't provide device info with incoming data,
      // we'll create a generic device reference and let the dispatcher handle filtering
      // based on message content rather than device source
      final genericDeviceRef = MidiDeviceRef(
        id: 'unknown',
        name: 'MIDI Device',
        type: 'unknown',
      );

      try {
        final message = MidiMessage.fromRawData(
          device: genericDeviceRef,
          data: data.toList(),
        );

        _messageController.add(message);
      } catch (e) {
        // Skip invalid messages but continue processing
      }
    } catch (e) {
      // Handle MIDI processing errors silently
    }
  }

  /// Load preferred device IDs from SharedPreferences
  Future<List<String>> _loadPreferredDeviceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsString = prefs.getStringList('preferred_midi_device_ids') ?? [];
      return idsString;
    } catch (e) {
      return [];
    }
  }

  /// Save preferred device IDs to SharedPreferences
  Future<void> _savePreferredDeviceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _connectedDevices.keys.toList();
      await prefs.setStringList('preferred_midi_device_ids', ids);
    } catch (e) {}
  }

  /// Get device reference by ID
  MidiDeviceRef? getDeviceRef(String deviceId) {
    return _deviceRefs[deviceId];
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  /// Dispose the manager and clean up resources
  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    disconnectAll();

    _messageController.close();
    _deviceListController.close();

    super.dispose();
  }

  // Private helper methods

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
}
