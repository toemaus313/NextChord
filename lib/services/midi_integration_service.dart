import '../core/utils/logger.dart';
import '../core/constants/song_viewer_constants.dart';
import '../data/repositories/song_repository.dart';
import '../services/midi/midi_service.dart';

/// Service for handling MIDI integration in the song viewer
class MidiIntegrationService {
  final SongRepository _songRepository;
  final MidiService _midiService;

  MidiIntegrationService({
    required SongRepository songRepository,
    required MidiService midiService,
  })  : _songRepository = songRepository,
        _midiService = midiService;

  /// Send MIDI mapping when song is opened in viewer
  Future<void> sendMidiMappingOnOpen(
      String songId, String songTitle, int bpm) async {
    Logger.methodEntry('MidiIntegrationService', 'sendMidiMappingOnOpen', {
      'songId': songId,
      'songTitle': songTitle,
      'bpm': bpm,
    });

    try {
      Logger.midi('Starting MIDI mapping for song: $songTitle');

      // Check MIDI service connection state
      Logger.midi(
          'MIDI service connection state: ${_midiService.connectionState}');
      Logger.midi(
          'MIDI service sendMidiClockEnabled: ${_midiService.sendMidiClockEnabled}');

      // Load MIDI profile from database
      final midiProfile = await _songRepository.getSongMidiProfile(songId);

      if (midiProfile == null) {
        Logger.midi(
            'No MIDI profile found for song: $songTitle - skipping profile MIDI sends');
      } else {
        await _sendMidiProfile(midiProfile, songTitle);
      }

      // Send MIDI clock stream if enabled
      await _sendMidiClockStreamIfNeeded(bpm);

      Logger.midi('MIDI profile sending completed for song: $songTitle');
    } catch (e, stackTrace) {
      Logger.error(
          'ERROR in sendMidiMappingOnOpen for song: $songTitle', e, stackTrace);
    }

    Logger.methodExit('MidiIntegrationService', 'sendMidiMappingOnOpen');
  }

  /// Send MIDI profile data
  Future<void> _sendMidiProfile(dynamic midiProfile, String songTitle) async {
    Logger.midi(
        'Found MIDI profile: ${midiProfile.name} (ID: ${midiProfile.id})');
    Logger.midi('Starting to send MIDI profile for song: $songTitle');

    // Send Program Change
    if (midiProfile.programChangeNumber != null) {
      Logger.midi('Sending Program Change: ${midiProfile.programChangeNumber}');
      await _midiService.sendProgramChange(midiProfile.programChangeNumber!);
    } else {
      Logger.midi('No Program Change number in profile');
    }

    // Send Control Changes
    if (midiProfile.controlChanges.isNotEmpty) {
      Logger.midi(
          'Sending ${midiProfile.controlChanges.length} Control Changes');
      for (final cc in midiProfile.controlChanges) {
        Logger.midi(
            'Sending Control Change: CC${cc.controller} -> ${cc.value}');
        await _midiService.sendControlChange(cc.controller, cc.value);
      }
      // Add delay between control changes
      await Future.delayed(const Duration(
          milliseconds: SongViewerConstants.midiControlChangeDelay));
    } else {
      Logger.midi('No Control Changes in profile');
    }

    // Send timing if enabled
    if (midiProfile.timing) {
      Logger.midi('Profile timing is enabled - sending single MIDI clock');
      await _midiService.sendMidiClock();
    } else {
      Logger.midi('Profile timing is disabled');
    }
  }

  /// Send MIDI clock stream if conditions are met
  Future<void> _sendMidiClockStreamIfNeeded(int bpm) async {
    if (_midiService.isConnected && _midiService.sendMidiClockEnabled) {
      Logger.midi(
          'sendMidiClockEnabled is TRUE and device connected - sending clock stream...');
      try {
        await _midiService.sendMidiClockStream(
          durationSeconds: SongViewerConstants.midiClockStreamDuration,
          bpm: bpm,
        );
        Logger.midi('Clock stream completed successfully');
      } catch (e) {
        Logger.midi('ERROR sending clock stream: $e');
      }
    } else {
      if (!_midiService.isConnected) {
        Logger.midi('No MIDI device connected - skipping clock stream');
      }
      if (!_midiService.sendMidiClockEnabled) {
        Logger.midi('sendMidiClockEnabled is FALSE - skipping clock stream');
      }
    }
  }
}
