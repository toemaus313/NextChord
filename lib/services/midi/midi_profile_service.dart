import 'package:uuid/uuid.dart';
import '../../domain/entities/midi_profile.dart';
import '../../data/repositories/song_repository.dart';
import '../midi/midi_service.dart';
import 'midi_command_parser.dart';

/// Service for managing MIDI profiles
class MidiProfileService {
  final SongRepository _repository;
  final MidiService _midiService;
  final Uuid _uuid = const Uuid();

  MidiProfileService(this._repository, this._midiService);

  /// Load all MIDI profiles from the database
  Future<List<MidiProfile>> loadProfiles() async {
    try {
      final profiles = await _repository.getAllMidiProfiles();
      return profiles;
    } catch (e) {
      rethrow;
    }
  }

  /// Save a MIDI profile to the database
  Future<void> saveProfile({
    required String name,
    required List<MidiCC> controlChanges,
    required bool timing,
    String? notes,
    String? id,
  }) async {
    try {
      // Separate program changes from control changes
      final separated =
          MidiCommandParser.separateProgramChanges(controlChanges);

      final profile = MidiProfile(
        id: id ?? _uuid.v4(),
        name: name,
        programChangeNumber: separated.programChangeNumber,
        controlChanges: separated.controlChanges,
        timing: timing,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.saveMidiProfile(profile);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a MIDI profile from the database
  Future<void> deleteProfile(String profileId) async {
    try {
      await _repository.deleteMidiProfile(profileId);
    } catch (e) {
      rethrow;
    }
  }

  /// Test MIDI commands for a profile
  Future<void> testProfile({
    required List<MidiCC> controlChanges,
    required bool timing,
  }) async {
    try {
      if (!_midiService.isConnected) {
        throw Exception('Connect a MIDI device before testing commands.');
      }

      // Separate program changes from control changes
      final separated =
          MidiCommandParser.separateProgramChanges(controlChanges);

      final hasCommands = separated.programChangeNumber != null ||
          separated.controlChanges.isNotEmpty ||
          timing;

      if (!hasCommands) {
        throw Exception('Add some MIDI commands before testing.');
      }

      // Send program change if present
      if (separated.programChangeNumber != null) {
        await _midiService.sendProgramChange(
          separated.programChangeNumber!,
          channel: _midiService.midiChannel,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Send control changes
      for (final cc in separated.controlChanges) {
        await _midiService.sendControlChange(
          cc.controller,
          cc.value,
          channel: _midiService.midiChannel,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Send MIDI clock if timing is enabled
      if (timing) {
        await _midiService.sendMidiClock();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Parse and validate a MIDI command string
  MidiCC? parseCommand(String command) {
    return MidiCommandParser.parseControlChange(command);
  }

  /// Check if a command is a timing command
  bool isTimingCommand(String command) {
    return MidiCommandParser.isTimingCommand(command);
  }

  /// Convert control changes to display format
  List<String> controlChangesToDisplayStrings(List<MidiCC> controlChanges) {
    return MidiCommandParser.midiCCToDisplayStrings(controlChanges);
  }

  /// Convert a stored profile to display format
  List<MidiCC> profileToDisplayFormat(MidiProfile profile) {
    return MidiCommandParser.profileToDisplayFormat(profile);
  }
}
