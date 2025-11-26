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
      // Handle MIDI message errors silently
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
      // Handle action execution errors silently
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
    } catch (e) {
      // Handle mapping loading errors silently
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
      // Handle action execution errors silently
    }
  }

  // Action implementation methods
  // These will need to be connected to the actual app state management

  void _executeScrollUp(AppControlActionParams params) {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
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
  }

  void _executeScrollDown(AppControlActionParams params) {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
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
  }

  void _executeScrollToTop() {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _executeScrollToBottom() {
    final scrollController = _getCurrentScrollController?.call();
    if (scrollController == null || !scrollController.hasClients) {
      return;
    }

    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _executeStartMetronome() {
    if (_metronomeProvider == null) {
      return;
    }

    _metronomeProvider!.start().then((_) {
      // Handle metronome start silently
    }).catchError((error) {
      // Handle metronome errors silently
    });
  }

  void _executeStopMetronome() {
    if (_metronomeProvider == null) {
      return;
    }

    _metronomeProvider!.stop();
  }

  void _executeToggleMetronome() {
    if (_metronomeProvider == null) {
      return;
    }

    // For MIDI toggle, implement custom logic that skips count-in
    if (_metronomeProvider!.isRunning) {
      // If running, stop it (including during count-in)
      _metronomeProvider!.stop();
    } else {
      // If stopped, start without count-in
      _metronomeProvider!.start(skipCountIn: true).then((_) {
        // Handle metronome start silently
      }).catchError((error) {
        // Handle metronome errors silently
      });
    }
  }

  void _executeRepeatCountIn() {
    if (_metronomeProvider == null) {
      return;
    }

    _metronomeProvider!.playCountInOnly().then((_) {
      // Handle count-in start silently
    }).catchError((error) {
      // Handle count-in errors silently
    });
  }

  void _executeStartAutoscroll() {
    if (_autoscrollProvider == null) {
      return;
    }

    _autoscrollProvider!.start();
  }

  void _executeStopAutoscroll() {
    if (_autoscrollProvider == null) {
      return;
    }

    _autoscrollProvider!.stop();
  }

  void _executeToggleAutoscroll() {
    if (_autoscrollProvider == null) {
      return;
    }

    // Use MIDI-specific toggle behavior with count-in logic
    _autoscrollProvider!.toggleWithMidiBehavior();
  }

  void _executeAutoscrollSpeedFaster() {
    if (_autoscrollProvider == null) {
      return;
    }

    // Decrease duration by 15 seconds to make it faster
    _autoscrollProvider!.adjustDuration(-15);
  }

  void _executeAutoscrollSpeedSlower() {
    if (_autoscrollProvider == null) {
      return;
    }

    // Increase duration by 15 seconds to make it slower
    _autoscrollProvider!.adjustDuration(15);
  }

  void _executeToggleSidebar() {
    if (_globalSidebarProvider == null) {
      return;
    }

    _globalSidebarProvider!.toggleSidebar();
  }

  void _executeTransposeUp() {
    if (_songViewerProvider == null) {
      return;
    }

    if (_songViewerProvider!.canIncrementTranspose()) {
      _songViewerProvider!.updateTranspose(1);
    } else {
      // At maximum transpose level
    }
  }

  void _executeTransposeDown() {
    if (_songViewerProvider == null) {
      return;
    }

    if (_songViewerProvider!.canDecrementTranspose()) {
      _songViewerProvider!.updateTranspose(-1);
    } else {
      // At minimum transpose level
    }
  }

  void _executeCapoUp() {
    if (_songViewerProvider == null) {
      return;
    }

    if (_songViewerProvider!.canIncrementCapo()) {
      _songViewerProvider!.updateCapo(1);
    } else {
      // At maximum capo level
    }
  }

  void _executeCapoDown() {
    if (_songViewerProvider == null) {
      return;
    }

    if (_songViewerProvider!.canDecrementCapo()) {
      _songViewerProvider!.updateCapo(-1);
    } else {
      // At minimum capo level
    }
  }

  void _executeZoomIn() {
    if (_songViewerProvider == null) {
      return;
    }

    final currentFontSize = _songViewerProvider!.fontSize;
    final newFontSize = currentFontSize + 2.0; // Increase by 2 points
    _songViewerProvider!.updateFontSize(newFontSize);
  }

  void _executeZoomOut() {
    if (_songViewerProvider == null) {
      return;
    }

    final currentFontSize = _songViewerProvider!.fontSize;
    final newFontSize = currentFontSize - 2.0; // Decrease by 2 points
    _songViewerProvider!.updateFontSize(newFontSize);
  }

  void _executePreviousSong() {
    if (_setlistNavigationService == null) {
      return;
    }

    if (!_setlistNavigationService!.hasPreviousSong) {
      return;
    }

    _setlistNavigationService!.navigateToPreviousSong().then((song) {
      if (song != null) {
        // Navigation successful
      } else {
        // Navigation failed
      }
    }).catchError((error) {
      // Handle navigation errors silently
    });
  }

  void _executeNextSong() {
    if (_setlistNavigationService == null) {
      return;
    }

    if (!_setlistNavigationService!.hasNextSong) {
      return;
    }

    _setlistNavigationService!.navigateToNextSong().then((song) {
      if (song != null) {
        // Navigation successful
      } else {
        // Navigation failed
      }
    }).catchError((error) {
      // Handle navigation errors silently
    });
  }

  void _executePreviousSection() {
    final scrollController = _getCurrentScrollController?.call();
    final songContent = _getCurrentSongContent?.call();

    if (scrollController == null || songContent == null) {
      return;
    }

    final sectionService = SectionNavigationService(
      scrollController: scrollController,
      chordProContent: songContent,
    );

    if (!sectionService.hasPreviousSection) {
      return;
    }

    sectionService.navigateToPreviousSection().then((success) {
      if (success) {
        // Navigation successful
      } else {
        // Navigation failed
      }
    }).catchError((error) {
      // Handle navigation errors silently
    });
  }

  void _executeNextSection() {
    final scrollController = _getCurrentScrollController?.call();
    final songContent = _getCurrentSongContent?.call();

    if (scrollController == null || songContent == null) {
      return;
    }

    final sectionService = SectionNavigationService(
      scrollController: scrollController,
      chordProContent: songContent,
    );

    if (!sectionService.hasNextSection) {
      return;
    }

    sectionService.navigateToNextSection().then((success) {
      if (success) {
        // Navigation successful
      } else {
        // Navigation failed
      }
    }).catchError((error) {
      // Handle navigation errors silently
    });
  }

  /// Dispose the dispatcher
  void dispose() {
    _messageSubscription.cancel();
    _isInitialized = false;
  }
}
