import 'package:uuid/uuid.dart';
import '../../main.dart' as main;
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

  /// Find an existing MIDI profile by exact content match
  Future<MidiProfile?> findProfileByContent({
    required List<MidiCC> controlChanges,
    required bool timing,
    String? notes,
  }) async {
    try {
      final allProfiles = await _repository.getAllMidiProfiles();

      for (final profile in allProfiles) {
        // Check if timing matches
        if (profile.timing != timing) continue;

        // Check if notes match (case-insensitive, null-safe)
        final profileNotes = profile.notes?.toLowerCase().trim();
        final targetNotes = notes?.toLowerCase().trim();
        if (profileNotes != targetNotes) continue;

        // Check if controlChanges match exactly (including order and labels)
        if (!_controlChangesEqual(profile.controlChanges, controlChanges)) {
          continue;
        }

        return profile;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if two controlChanges lists are identical (including order and labels)
  bool _controlChangesEqual(List<MidiCC> a, List<MidiCC> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      final ccA = a[i];
      final ccB = b[i];

      if (ccA.controller != ccB.controller ||
          ccA.value != ccB.value ||
          (ccA.label ?? '').toLowerCase().trim() !=
              (ccB.label ?? '').toLowerCase().trim()) {
        return false;
      }
    }

    return true;
  }

  /// Get all unique MIDI command labels/comments from existing profiles
  Future<List<String>> getAllLabels() async {
    try {
      final profiles = await _repository.getAllMidiProfiles();
      final labels = <String>{};

      for (final profile in profiles) {
        for (final cc in profile.controlChanges) {
          if (cc.label != null && cc.label!.trim().isNotEmpty) {
            labels.add(cc.label!.trim());
          }
        }
      }

      return labels.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  /// Find MIDI commands that have a specific label
  Future<List<MidiCC>> getCommandsByLabel(String label) async {
    try {
      final profiles = await _repository.getAllMidiProfiles();
      final commands = <MidiCC>{};

      for (final profile in profiles) {
        for (final cc in profile.controlChanges) {
          if (cc.label?.trim().toLowerCase() == label.trim().toLowerCase()) {
            commands.add(cc);
          }
        }
      }

      return commands.toList();
    } catch (e) {
      return [];
    }
  }

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
    main.myDebug(
        'MidiProfileService.saveProfile: called with controlChanges order: ${controlChanges.map((cc) => MidiCommandParser.midiCCToString(cc)).join(', ')}');

    try {
      // Don't separate program changes - store all commands in controlChanges to preserve order
      final profile = MidiProfile(
        id: id ?? _uuid.v4(),
        name: name,
        programChangeNumber:
            null, // Always null - PC commands are stored in controlChanges
        controlChanges: controlChanges,
        timing: timing,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      main.myDebug(
          'MidiProfileService.saveProfile: created profile with controlChanges order: ${profile.controlChanges.map((cc) => MidiCommandParser.midiCCToString(cc)).join(', ')}');

      await _repository.saveMidiProfile(profile);

      main.myDebug('MidiProfileService.saveProfile: repository save completed');
    } catch (e) {
      main.myDebug('MidiProfileService.saveProfile: error saving profile: $e');
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

      if (controlChanges.isEmpty && !timing) {
        throw Exception('Add some MIDI commands before testing.');
      }

      // Send all commands in order with 100ms delay between each
      for (final cc in controlChanges) {
        if (cc.controller == -1) {
          // Program Change command
          await _midiService.sendProgramChange(
            cc.value,
            channel: _midiService.midiChannel,
          );
          main.myDebug('MidiProfileService.testProfile: sent PC${cc.value}');
        } else {
          // Control Change command
          await _midiService.sendControlChange(
            cc.controller,
            cc.value,
            channel: _midiService.midiChannel,
          );
          main.myDebug(
              'MidiProfileService.testProfile: sent CC${cc.controller},${cc.value}');
        }

        // 100ms delay between commands
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Send MIDI clock if timing is enabled
      if (timing) {
        await _midiService.sendMidiClock();
        main.myDebug('MidiProfileService.testProfile: sent MIDI clock');
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

  /// Delete a MIDI profile (soft delete for sync compatibility)
  Future<void> deleteProfile(String profileId) async {
    try {
      await _repository.deleteMidiProfile(profileId);
      main.myDebug(
          'MidiProfileService.deleteProfile: soft deleted profile $profileId');
    } catch (e) {
      main.myDebug(
          'MidiProfileService.deleteProfile: error deleting profile: $e');
      rethrow;
    }
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
