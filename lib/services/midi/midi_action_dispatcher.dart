import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../domain/entities/app_control_action.dart';
import '../../domain/entities/midi_message.dart';
import 'midi_device_manager.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/song_repository.dart';

/// Dispatches MIDI messages to app actions based on pedal mappings
class MidiActionDispatcher {
  static final MidiActionDispatcher _instance =
      MidiActionDispatcher._internal();
  factory MidiActionDispatcher() => _instance;
  MidiActionDispatcher._internal() {
    // No initialization needed in constructor
  }

  final MidiDeviceManager _deviceManager = MidiDeviceManager();
  late final StreamSubscription<MidiMessage> _messageSubscription;

  // Repository for accessing pedal mappings
  SongRepository? _repository;
  List<PedalMappingModel> _activeMappings = [];

  bool _isInitialized = false;

  /// Initialize the dispatcher with repository
  Future<void> initialize(SongRepository repository) async {
    if (_isInitialized) return;

    _repository = repository;
    await _loadActiveMappings();

    // Listen for MIDI messages
    _messageSubscription =
        _deviceManager.messageStream.listen(_handleMidiMessage);

    // Listen for device changes to reload mappings
    _deviceManager.deviceListStream.listen((_) {
      _loadActiveMappings();
    });

    _isInitialized = true;
    debugPrint('MidiActionDispatcher initialized');
  }

  /// Handle incoming MIDI messages and trigger matching actions
  void _handleMidiMessage(MidiMessage message) {
    try {
      // Find matching mappings
      final matchingMappings = _findMatchingMappings(message);

      for (final mapping in matchingMappings) {
        _executeAction(mapping, message);
      }
    } catch (e) {
      debugPrint('Error handling MIDI message: $e');
    }
  }

  /// Find all mappings that match the incoming MIDI message
  List<PedalMappingModel> _findMatchingMappings(MidiMessage message) {
    return _activeMappings.where((mapping) {
      // Check if mapping is enabled
      if (!mapping.isEnabled) return false;

      // Check if mapping is for MIDI (not legacy keyboard)
      if (mapping.messageType == null) return false;

      // Check device filter - since flutter_midi_command doesn't provide device info,
      // we only filter by device if no device is specified (any device)
      // or if the mapping is for the generic "unknown" device
      if (mapping.deviceId != null &&
          mapping.deviceId != 'unknown' &&
          message.device.id != 'unknown') {
        return false;
      }

      // Check message type
      final expectedType = mapping.messageType;
      if (expectedType == 'cc' && message.type != MidiMessageType.cc)
        return false;
      if (expectedType == 'pc' && message.type != MidiMessageType.pc)
        return false;

      // Check channel
      if (mapping.channel != null && mapping.channel != message.channel)
        return false;

      // Check number
      if (mapping.number != null && mapping.number != message.number)
        return false;

      // Check value range (for CC messages)
      if (message.type == MidiMessageType.cc && message.value != null) {
        final value = message.value!;
        if (mapping.valueMin != null && value < mapping.valueMin!) return false;
        if (mapping.valueMax != null && value > mapping.valueMax!) return false;
      }

      return true;
    }).toList();
  }

  void _executeAction(PedalMappingModel mapping, MidiMessage message) {
    try {
      // Parse the action from JSON
      final action = AppControlAction.fromLegacyJson(mapping.action);

      debugPrint(
          'Executing MIDI action: ${action.description} from ${message.device.name}');

      // Execute the appropriate action
      switch (action.type) {
        case AppControlActionType.previousSong:
          _executePreviousSong();
          break;
        case AppControlActionType.nextSong:
          _executeNextSong();
          break;
        case AppControlActionType.previousSection:
          _executePreviousSection();
          break;
        case AppControlActionType.nextSection:
          _executeNextSection();
          break;
        case AppControlActionType.scrollUp:
          _executeScrollUp(action.params);
          break;
        case AppControlActionType.scrollDown:
          _executeScrollDown(action.params);
          break;
        case AppControlActionType.scrollToTop:
          _executeScrollToTop();
          break;
        case AppControlActionType.scrollToBottom:
          _executeScrollToBottom();
          break;
        case AppControlActionType.startMetronome:
          _executeStartMetronome();
          break;
        case AppControlActionType.stopMetronome:
          _executeStopMetronome();
          break;
        case AppControlActionType.toggleMetronome:
          _executeToggleMetronome();
          break;
        case AppControlActionType.repeatCountIn:
          _executeRepeatCountIn();
          break;
        case AppControlActionType.startAutoscroll:
          _executeStartAutoscroll();
          break;
        case AppControlActionType.stopAutoscroll:
          _executeStopAutoscroll();
          break;
        case AppControlActionType.toggleAutoscroll:
          _executeToggleAutoscroll();
          break;
        case AppControlActionType.autoscrollSpeedFaster:
          _executeAutoscrollSpeedFaster();
          break;
        case AppControlActionType.autoscrollSpeedSlower:
          _executeAutoscrollSpeedSlower();
          break;
        case AppControlActionType.toggleSidebar:
          _executeToggleSidebar();
          break;
        case AppControlActionType.transposeUp:
          _executeTransposeUp();
          break;
        case AppControlActionType.transposeDown:
          _executeTransposeDown();
          break;
        case AppControlActionType.capoUp:
          _executeCapoUp();
          break;
        case AppControlActionType.capoDown:
          _executeCapoDown();
          break;
        case AppControlActionType.zoomIn:
          _executeZoomIn();
          break;
        case AppControlActionType.zoomOut:
          _executeZoomOut();
          break;
      }
    } catch (e) {
      debugPrint('Error executing action for mapping ${mapping.id}: $e');
    }
  }

  /// Load active pedal mappings from the database
  Future<void> _loadActiveMappings() async {
    if (_repository == null) return;

    try {
      final allMappings = await _repository!.getAllPedalMappings();
      _activeMappings = allMappings
          .where((m) =>
                  m.isEnabled &&
                  !m.isDeleted &&
                  m.messageType != null // Only MIDI mappings
              )
          .toList();

      debugPrint('Loaded ${_activeMappings.length} active MIDI mappings');
    } catch (e) {
      debugPrint('Error loading MIDI mappings: $e');
    }
  }

  /// Refresh mappings (call after database changes)
  Future<void> refreshMappings() async {
    await _loadActiveMappings();
  }

  // Action implementation methods
  // These will need to be connected to the actual app state management

  void _executeScrollUp(AppControlActionParams params) {
    final amount = params.get<int>('amount') ?? 1;
    // TODO: Connect to song viewer scrolling
    debugPrint('Action: Scroll up $amount lines');
  }

  void _executeScrollDown(AppControlActionParams params) {
    final amount = params.get<int>('amount') ?? 1;
    // TODO: Connect to song viewer scrolling
    debugPrint('Action: Scroll down $amount lines');
  }

  void _executeScrollToTop() {
    // TODO: Connect to song viewer scrolling
    debugPrint('Action: Scroll to top');
  }

  void _executeScrollToBottom() {
    // TODO: Connect to song viewer scrolling
    debugPrint('Action: Scroll to bottom');
  }

  void _executeStartMetronome() {
    // TODO: Connect to metronome provider
    debugPrint('Action: Start metronome');
  }

  void _executeStopMetronome() {
    // TODO: Connect to metronome provider
    debugPrint('Action: Stop metronome');
  }

  void _executeToggleMetronome() {
    // TODO: Connect to metronome provider
    debugPrint('Action: Toggle metronome');
  }

  void _executeRepeatCountIn() {
    // TODO: Connect to metronome provider for count-in functionality
    debugPrint('Action: Repeat count-in');
  }

  void _executeStartAutoscroll() {
    // TODO: Connect to autoscroll functionality
    debugPrint('Action: Start autoscroll');
  }

  void _executeStopAutoscroll() {
    // TODO: Connect to autoscroll provider
    debugPrint('Action: Stop autoscroll');
  }

  void _executeToggleAutoscroll() {
    // TODO: Connect to autoscroll provider
    debugPrint('Action: Toggle autoscroll');
  }

  void _executeAutoscrollSpeedFaster() {
    // TODO: Connect to autoscroll provider
    debugPrint('Action: Autoscroll speed faster');
  }

  void _executeAutoscrollSpeedSlower() {
    // TODO: Connect to autoscroll provider
    debugPrint('Action: Autoscroll speed slower');
  }

  void _executeToggleSidebar() {
    // TODO: Connect to app state
    debugPrint('Action: Toggle sidebar');
  }

  void _executeTransposeUp() {
    // TODO: Connect to transposition provider
    debugPrint('Action: Transpose up');
  }

  void _executeTransposeDown() {
    // TODO: Connect to transposition provider
    debugPrint('Action: Transpose down');
  }

  void _executeCapoUp() {
    // TODO: Connect to capo provider
    debugPrint('Action: Capo up');
  }

  void _executeCapoDown() {
    // TODO: Connect to capo provider
    debugPrint('Action: Capo down');
  }

  void _executeZoomIn() {
    // TODO: Connect to zoom provider
    debugPrint('Action: Zoom in');
  }

  void _executeZoomOut() {
    // TODO: Connect to zoom provider
    debugPrint('Action: Zoom out');
  }

  void _executePreviousSong() {
    // TODO: Connect to song provider
    debugPrint('Action: Previous song');
  }

  void _executeNextSong() {
    // TODO: Connect to song provider
    debugPrint('Action: Next song');
  }

  void _executePreviousSection() {
    // TODO: Connect to song provider
    debugPrint('Action: Previous section');
  }

  void _executeNextSection() {
    // TODO: Connect to song provider
    debugPrint('Action: Next section');
  }

  /// Dispose the dispatcher
  void dispose() {
    _messageSubscription.cancel();
    _isInitialized = false;
    debugPrint('MidiActionDispatcher disposed');
  }
}
