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
    try {
      // Check if MidiService is still valid (not disposed)
      if (_midiService.isDisposed) {
        return;
      }

      // Load MIDI profile from database
      final midiProfile = await _songRepository.getSongMidiProfile(songId);

      if (midiProfile == null) {
      } else {
        // Check again before sending profile (async operation might have completed after disposal)
        if (_midiService.isDisposed) {
          return;
        }
        await _sendMidiProfile(midiProfile, songTitle);
      }

      // Send MIDI clock stream if enabled
      if (!_midiService.isDisposed) {
        await _sendMidiClockStreamIfNeeded(bpm);
      }
    } catch (e, stackTrace) {}
  }

  /// Send MIDI profile data
  Future<void> _sendMidiProfile(dynamic midiProfile, String songTitle) async {
    // Send Program Change
    if (midiProfile.programChangeNumber != null) {
      await _midiService.sendProgramChange(midiProfile.programChangeNumber!);
    }

    // Send Control Changes
    if (midiProfile.controlChanges.isNotEmpty) {
      for (final cc in midiProfile.controlChanges) {
        await _midiService.sendControlChange(cc.controller, cc.value);
      }
      // Add delay between control changes
      await Future.delayed(const Duration(
          milliseconds: SongViewerConstants.midiControlChangeDelay));
    }

    // Send timing if enabled
    if (midiProfile.timing) {
      await _midiService.sendMidiClock();
    }
  }

  /// Send MIDI clock stream if conditions are met
  Future<void> _sendMidiClockStreamIfNeeded(int bpm) async {
    if (_midiService.isConnected && _midiService.sendMidiClockEnabled) {
      try {
        await _midiService.sendMidiClockStream(
          durationSeconds: SongViewerConstants.midiClockStreamDuration,
          bpm: bpm,
        );
      } catch (e) {}
    }
  }
}
