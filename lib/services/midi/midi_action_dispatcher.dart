import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/app_control_action.dart';
import '../../domain/entities/midi_message.dart';
import 'midi_device_manager.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/song_repository.dart';
import '../../presentation/providers/metronome_provider.dart';
import '../../presentation/providers/autoscroll_provider.dart';
import '../../presentation/providers/global_sidebar_provider.dart';
import '../../presentation/providers/song_viewer_provider.dart';
import '../../services/setlist_navigation_service.dart';
import '../../services/section_navigation_service.dart';

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

  // Provider dependencies (stable services)
  MetronomeProvider? _metronomeProvider;
  AutoscrollProvider? _autoscrollProvider;
  GlobalSidebarProvider? _globalSidebarProvider;
  SongViewerProvider? _songViewerProvider;
  SetlistNavigationService? _setlistNavigationService;

  // Callbacks for current state (changes per song/context)
  String Function()? _getCurrentSongContent;
  ScrollController Function()? _getCurrentScrollController;

  /// Initialize the dispatcher with repository and providers
  Future<void> initialize({
    required SongRepository repository,
    MetronomeProvider? metronomeProvider,
    AutoscrollProvider? autoscrollProvider,
    GlobalSidebarProvider? globalSidebarProvider,
    SongViewerProvider? songViewerProvider,
    SetlistNavigationService? setlistNavigationService,
    String Function()? getCurrentSongContent,
    ScrollController Function()? getCurrentScrollController,
  }) async {
    if (_isInitialized) {
      return;
    }

    _repository = repository;
    _metronomeProvider = metronomeProvider;
    _autoscrollProvider = autoscrollProvider;
    _globalSidebarProvider = globalSidebarProvider;
    _songViewerProvider = songViewerProvider;
    _setlistNavigationService = setlistNavigationService;
    _getCurrentSongContent = getCurrentSongContent;
    _getCurrentScrollController = getCurrentScrollController;

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
      if (expectedType == 'cc' && message.type != MidiMessageType.cc) {
        return false;
      }
      if (expectedType == 'pc' && message.type != MidiMessageType.pc) {
        return false;
      }

      // Check channel
      if (mapping.channel != null && mapping.channel != message.channel) {
        return false;
      }

      // Check number
      if (mapping.number != null && mapping.number != message.number) {
        return false;
      }

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

  /// Update current state callbacks (call when entering song viewer)
  void updateCurrentStateCallbacks({
    String Function()? getCurrentSongContent,
    ScrollController Function()? getCurrentScrollController,
    SongViewerProvider? songViewerProvider,
  }) {
    _getCurrentSongContent = getCurrentSongContent;
    _getCurrentScrollController = getCurrentScrollController;
    _songViewerProvider = songViewerProvider;
    debugPrint('Updated MIDI dispatcher current state callbacks');
  }

  /// Refresh mappings (call after database changes)
  Future<void> refreshMappings() async {
    await _loadActiveMappings();
  }

  /// Public method for UI to execute actions (uses same logic as MIDI)
  Future<void> executeAction(AppControlActionType action,
      {AppControlActionParams? params}) async {
    if (!_isInitialized) {
      debugPrint(
          'MidiActionDispatcher not initialized - cannot execute action');
      return;
    }

    final actionParams = params ?? const AppControlActionParams();

    try {
      switch (action) {
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
          _executeScrollUp(actionParams);
          break;
        case AppControlActionType.scrollDown:
          _executeScrollDown(actionParams);
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
      debugPrint('Error executing action $action: $e');
    }
  }

  // Action implementation methods
  // These will need to be connected to the actual app state management

  void _executeScrollUp(AppControlActionParams params) {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
      debugPrint('Scroll controller not available for scroll up');
      return;
    }

    final amount = params.get<int>('amount') ?? 1;
    // Scroll 30% of viewport height per requirement
    final viewportHeight = scrollController.position.viewportDimension;
    final scrollDistance = viewportHeight * 0.3 * amount;

    final newOffset = (scrollController.offset - scrollDistance)
        .clamp(0.0, scrollController.position.maxScrollExtent);

    scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    debugPrint('Scrolled up ${scrollDistance.round()}px');
  }

  void _executeScrollDown(AppControlActionParams params) {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
      debugPrint('Scroll controller not available for scroll down');
      return;
    }

    final amount = params.get<int>('amount') ?? 1;
    // Scroll 30% of viewport height per requirement
    final viewportHeight = scrollController.position.viewportDimension;
    final scrollDistance = viewportHeight * 0.3 * amount;

    final newOffset = (scrollController.offset + scrollDistance)
        .clamp(0.0, scrollController.position.maxScrollExtent);

    scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    debugPrint('Scrolled down ${scrollDistance.round()}px');
  }

  void _executeScrollToTop() {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
      debugPrint('Scroll controller not available for scroll to top');
      return;
    }

    scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    debugPrint('Scrolled to top');
  }

  void _executeScrollToBottom() {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
      debugPrint('Scroll controller not available for scroll to bottom');
      return;
    }

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    debugPrint('Scrolled to bottom');
  }

  void _executeStartMetronome() {
    if (_metronomeProvider == null) {
      debugPrint('MetronomeProvider not available for start metronome');
      return;
    }

    _metronomeProvider!.start().then((_) {
      debugPrint('Started metronome');
    }).catchError((error) {
      debugPrint('Error starting metronome: $error');
    });
  }

  void _executeStopMetronome() {
    if (_metronomeProvider == null) {
      debugPrint('MetronomeProvider not available for stop metronome');
      return;
    }

    _metronomeProvider!.stop();
    debugPrint('Stopped metronome');
  }

  void _executeToggleMetronome() {
    if (_metronomeProvider == null) {
      debugPrint('MetronomeProvider not available for toggle metronome');
      return;
    }

    // For MIDI toggle, implement custom logic that skips count-in
    if (_metronomeProvider!.isRunning) {
      // If running, stop it (including during count-in)
      _metronomeProvider!.stop();
      debugPrint('Stopped metronome via MIDI toggle');
    } else {
      // If stopped, start without count-in
      _metronomeProvider!.start(skipCountIn: true).then((_) {
        debugPrint('Started metronome via MIDI toggle (skipped count-in)');
      }).catchError((error) {
        debugPrint('Error starting metronome via MIDI toggle: $error');
      });
    }
  }

  void _executeRepeatCountIn() {
    if (_metronomeProvider == null) {
      debugPrint('MetronomeProvider not available for repeat count-in');
      return;
    }

    _metronomeProvider!.playCountInOnly().then((_) {
      debugPrint('Started count-in only');
    }).catchError((error) {
      debugPrint('Error starting count-in only: $error');
    });
  }

  void _executeStartAutoscroll() {
    if (_autoscrollProvider == null) {
      debugPrint('AutoscrollProvider not available for start autoscroll');
      return;
    }

    _autoscrollProvider!.start();
    debugPrint('Started autoscroll');
  }

  void _executeStopAutoscroll() {
    if (_autoscrollProvider == null) {
      debugPrint('AutoscrollProvider not available for stop autoscroll');
      return;
    }

    _autoscrollProvider!.stop();
    debugPrint('Stopped autoscroll');
  }

  void _executeToggleAutoscroll() {
    if (_autoscrollProvider == null) {
      debugPrint('AutoscrollProvider not available for toggle autoscroll');
      return;
    }

    // Use MIDI-specific toggle behavior with count-in logic
    _autoscrollProvider!.toggleWithMidiBehavior();
    debugPrint('Toggled autoscroll with MIDI behavior');
  }

  void _executeAutoscrollSpeedFaster() {
    if (_autoscrollProvider == null) {
      debugPrint('AutoscrollProvider not available for speed faster');
      return;
    }

    // Decrease duration by 15 seconds to make it faster
    _autoscrollProvider!.adjustDuration(-15);
    debugPrint('Made autoscroll faster (decreased duration by 15 seconds)');
  }

  void _executeAutoscrollSpeedSlower() {
    if (_autoscrollProvider == null) {
      debugPrint('AutoscrollProvider not available for speed slower');
      return;
    }

    // Increase duration by 15 seconds to make it slower
    _autoscrollProvider!.adjustDuration(15);
    debugPrint('Made autoscroll slower (increased duration by 15 seconds)');
  }

  void _executeToggleSidebar() {
    if (_globalSidebarProvider == null) {
      debugPrint('GlobalSidebarProvider not available for toggle sidebar');
      return;
    }

    _globalSidebarProvider!.toggleSidebar();
    debugPrint('Toggled sidebar');
  }

  void _executeTransposeUp() {
    if (_songViewerProvider == null) {
      debugPrint('SongViewerProvider not available for transpose up');
      return;
    }

    if (_songViewerProvider!.canIncrementTranspose()) {
      _songViewerProvider!.updateTranspose(1);
      debugPrint('Transposed up by one half-step');
    } else {
      debugPrint('Cannot transpose up - at maximum');
    }
  }

  void _executeTransposeDown() {
    if (_songViewerProvider == null) {
      debugPrint('SongViewerProvider not available for transpose down');
      return;
    }

    if (_songViewerProvider!.canDecrementTranspose()) {
      _songViewerProvider!.updateTranspose(-1);
      debugPrint('Transposed down by one half-step');
    } else {
      debugPrint('Cannot transpose down - at minimum');
    }
  }

  void _executeCapoUp() {
    if (_songViewerProvider == null) {
      debugPrint('SongViewerProvider not available for capo up');
      return;
    }

    if (_songViewerProvider!.canIncrementCapo()) {
      _songViewerProvider!.updateCapo(1);
      debugPrint('Increased capo by 1');
    } else {
      debugPrint('Cannot increase capo - at maximum');
    }
  }

  void _executeCapoDown() {
    if (_songViewerProvider == null) {
      debugPrint('SongViewerProvider not available for capo down');
      return;
    }

    if (_songViewerProvider!.canDecrementCapo()) {
      _songViewerProvider!.updateCapo(-1);
      debugPrint('Decreased capo by 1');
    } else {
      debugPrint('Cannot decrease capo - at minimum');
    }
  }

  void _executeZoomIn() {
    if (_songViewerProvider == null) {
      debugPrint('SongViewerProvider not available for zoom in');
      return;
    }

    final currentFontSize = _songViewerProvider!.fontSize;
    final newFontSize = currentFontSize + 2.0; // Increase by 2 points
    _songViewerProvider!.updateFontSize(newFontSize);
    debugPrint('Zoomed in (increased font size)');
  }

  void _executeZoomOut() {
    if (_songViewerProvider == null) {
      debugPrint('SongViewerProvider not available for zoom out');
      return;
    }

    final currentFontSize = _songViewerProvider!.fontSize;
    final newFontSize = currentFontSize - 2.0; // Decrease by 2 points
    _songViewerProvider!.updateFontSize(newFontSize);
    debugPrint('Zoomed out (decreased font size)');
  }

  void _executePreviousSong() {
    if (_setlistNavigationService == null) {
      debugPrint('SetlistNavigationService not available for previous song');
      return;
    }

    if (!_setlistNavigationService!.hasPreviousSong) {
      debugPrint('No previous song available');
      return;
    }

    _setlistNavigationService!.navigateToPreviousSong().then((song) {
      if (song != null) {
        debugPrint('Navigated to previous song: ${song.title}');
      } else {
        debugPrint('Failed to navigate to previous song');
      }
    }).catchError((error) {
      debugPrint('Error navigating to previous song: $error');
    });
  }

  void _executeNextSong() {
    if (_setlistNavigationService == null) {
      debugPrint('SetlistNavigationService not available for next song');
      return;
    }

    if (!_setlistNavigationService!.hasNextSong) {
      debugPrint('No next song available');
      return;
    }

    _setlistNavigationService!.navigateToNextSong().then((song) {
      if (song != null) {
        debugPrint('Navigated to next song: ${song.title}');
      } else {
        debugPrint('Failed to navigate to next song');
      }
    }).catchError((error) {
      debugPrint('Error navigating to next song: $error');
    });
  }

  void _executePreviousSection() {
    final scrollController = _getCurrentScrollController?.call();
    final songContent = _getCurrentSongContent?.call();

    if (scrollController == null || songContent == null) {
      debugPrint(
          'Scroll controller or song content not available for section navigation');
      return;
    }

    final sectionService = SectionNavigationService(
      scrollController: scrollController,
      chordProContent: songContent,
    );

    if (!sectionService.hasPreviousSection) {
      debugPrint('No previous section available');
      return;
    }

    sectionService.navigateToPreviousSection().then((success) {
      if (success) {
        debugPrint('Navigated to previous section');
      } else {
        debugPrint('Failed to navigate to previous section');
      }
    }).catchError((error) {
      debugPrint('Error navigating to previous section: $error');
    });
  }

  void _executeNextSection() {
    final scrollController = _getCurrentScrollController?.call();
    final songContent = _getCurrentSongContent?.call();

    if (scrollController == null || songContent == null) {
      debugPrint(
          'Scroll controller or song content not available for section navigation');
      return;
    }

    final sectionService = SectionNavigationService(
      scrollController: scrollController,
      chordProContent: songContent,
    );

    if (!sectionService.hasNextSection) {
      debugPrint('No next section available');
      return;
    }

    sectionService.navigateToNextSection().then((success) {
      if (success) {
        debugPrint('Navigated to next section');
      } else {
        debugPrint('Failed to navigate to next section');
      }
    }).catchError((error) {
      debugPrint('Error navigating to next section: $error');
    });
  }

  /// Dispose the dispatcher
  void dispose() {
    _messageSubscription.cancel();
    _isInitialized = false;
    debugPrint('MidiActionDispatcher disposed');
  }
}
