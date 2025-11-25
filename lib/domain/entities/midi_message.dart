import 'package:equatable/equatable.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

/// MIDI message types supported by the app
enum MidiMessageType {
  cc, // Control Change
  pc, // Program Change
  noteOn, // Note On (for future expansion)
  noteOff, // Note Off (for future expansion)
}

/// Reference to a MIDI device for message routing
class MidiDeviceRef extends Equatable {
  final String id;
  final String name;
  final String type; // 'bluetooth', 'usb', 'virtual', etc.

  const MidiDeviceRef({
    required this.id,
    required this.name,
    required this.type,
  });

  factory MidiDeviceRef.fromMidiDevice(MidiDevice device) {
    return MidiDeviceRef(
      id: device.id,
      name: device.name,
      type: device.type.toString().split('.').last,
    );
  }

  @override
  List<Object?> get props => [id, name, type];
}

/// Normalized MIDI message model for inbound processing
class MidiMessage extends Equatable {
  final MidiDeviceRef device;
  final MidiMessageType type;
  final int channel; // 0-15
  final int number; // CC number, PC number, or note number
  final int? value; // CC value (0-127), null for PC
  final DateTime timestamp;

  const MidiMessage({
    required this.device,
    required this.type,
    required this.channel,
    required this.number,
    this.value,
    required this.timestamp,
  });

  /// Parse raw MIDI data into a normalized MidiMessage
  factory MidiMessage.fromRawData({
    required MidiDeviceRef device,
    required List<int> data,
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now();

    if (data.isEmpty) {
      throw ArgumentError('MIDI data cannot be empty');
    }

    final statusByte = data[0];
    final channel = statusByte & 0x0F; // Low nibble is channel
    final status = statusByte & 0xF0; // High nibble is message type

    switch (status) {
      case 0xB0: // Control Change
        if (data.length < 3) {
          throw ArgumentError('CC message requires 3 bytes');
        }
        return MidiMessage(
          device: device,
          type: MidiMessageType.cc,
          channel: channel,
          number: data[1], // Controller number
          value: data[2], // Controller value
          timestamp: ts,
        );

      case 0xC0: // Program Change
        if (data.length < 2) {
          throw ArgumentError('PC message requires 2 bytes');
        }
        return MidiMessage(
          device: device,
          type: MidiMessageType.pc,
          channel: channel,
          number: data[1], // Program number
          value: null, // PC doesn't have a value
          timestamp: ts,
        );

      case 0x90: // Note On
        if (data.length < 3) {
          throw ArgumentError('Note On message requires 3 bytes');
        }
        return MidiMessage(
          device: device,
          type: MidiMessageType.noteOn,
          channel: channel,
          number: data[1], // Note number
          value: data[2], // Velocity
          timestamp: ts,
        );

      case 0x80: // Note Off
        if (data.length < 3) {
          throw ArgumentError('Note Off message requires 3 bytes');
        }
        return MidiMessage(
          device: device,
          type: MidiMessageType.noteOff,
          channel: channel,
          number: data[1], // Note number
          value: data[2], // Velocity
          timestamp: ts,
        );

      default:
        throw ArgumentError(
            'Unsupported MIDI message type: 0x${status.toRadixString(16)}');
    }
  }

  /// Create a copy with updated values
  MidiMessage copyWith({
    MidiDeviceRef? device,
    MidiMessageType? type,
    int? channel,
    int? number,
    int? value,
    DateTime? timestamp,
  }) {
    return MidiMessage(
      device: device ?? this.device,
      type: type ?? this.type,
      channel: channel ?? this.channel,
      number: number ?? this.number,
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [device, type, channel, number, value, timestamp];

  @override
  String toString() {
    final typeStr = type.toString().split('.').last.toUpperCase();
    final valueStr = value != null ? ', value: $value' : '';
    return 'MidiMessage($typeStr, device: ${device.name}, channel: ${channel + 1}, number: $number$valueStr)';
  }
}
