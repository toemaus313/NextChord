import '../core/constants/song_viewer_constants.dart';
import '../data/repositories/song_repository.dart';
import '../services/midi/midi_service.dart';
import '../services/midi/midi_profile_service.dart';

/// Service for handling MIDI integration in the song viewer
class MidiIntegrationService {
  final SongRepository _songRepository;
  final MidiService _midiService;
  final MidiProfileService _midiProfileService;

  MidiIntegrationService({
    required SongRepository songRepository,
    required MidiService midiService,
  })  : _songRepository = songRepository,
        _midiService = midiService,
        _midiProfileService = MidiProfileService(songRepository, midiService);

  /// Send MIDI mapping when song is opened in viewer
  Future<void> sendMidiMappingOnOpen(
      String songId, String songTitle, int bpm) async {
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

      // Best-effort: if there is no connected MIDI device or the profile is
      // otherwise not sendable, swallow the exception so opening a song in
      // the viewer does not trigger a global error.
      try {
        await _midiProfileService.sendProfile(midiProfile);
      } catch (_) {}
    }

    // Send MIDI clock stream if enabled
    if (!_midiService.isDisposed) {
      await _sendMidiClockStreamIfNeeded(bpm);
    }
  }

  /// Send MIDI clock stream if conditions are met
  Future<void> _sendMidiClockStreamIfNeeded(int bpm) async {
    if (_midiService.isConnected && _midiService.sendMidiClockEnabled) {
      await _midiService.sendMidiClockStream(
        durationSeconds: SongViewerConstants.midiClockStreamDuration,
        bpm: bpm,
      );
    }
  }
}
