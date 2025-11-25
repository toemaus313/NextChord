import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../domain/entities/shared_import_payload.dart';
import '../../domain/entities/song.dart';
import '../../services/import/share_import_service.dart';
import '../../core/widgets/loading_wait.dart';
import '../../../main.dart' as main; // Import for myDebug and navigatorKey
import '../screens/song_editor_screen_refactored.dart';

/// Provider for handling share intent events and routing to ShareImportService
class ShareImportProvider extends ChangeNotifier {
  final ShareImportService _shareImportService = ShareImportService();

  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;

  bool _isProcessingShare = false;

  bool get isProcessingShare => _isProcessingShare;

  ShareImportProvider() {
    main.myDebug(
        'ShareImportProvider: CONSTRUCTOR CALLED - Provider instance created');
    _initializeShareHandling();
  }

  void _initializeShareHandling() {
    main.myDebug(
        'ShareImportProvider: Initializing share handling - TESTING DEBUG OUTPUT');

    // Listen for shared media (text, URLs)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedMedia, onError: (error) {
      main.myDebug('ShareImportProvider: Error in share stream: $error');
      _isProcessingShare = false;
      notifyListeners();
    });

    main.myDebug('ShareImportProvider: Share stream listener established');

    // Check for any pending intents when app starts
    _checkInitialIntents();
  }

  Future<void> _checkInitialIntents() async {
    main.myDebug(
        'ShareImportProvider: Checking initial intents - TESTING DEBUG OUTPUT');

    // TEST: Create a fake UG payload to test the import flow
    main.myDebug(
        'ShareImportProvider: CREATING TEST UG PAYLOAD TO VERIFY IMPORT FLOW');
    final testPayload = SharedImportPayload.text(
        'Test song content\n[C]Test [G]chords\nTest lyrics',
        sourceApp: 'TEST_DEBUG');
    main.myDebug('ShareImportProvider: Test payload created: $testPayload');

    try {
      final initialMedia =
          await ReceiveSharingIntent.instance.getInitialMedia();
      main.myDebug(
          'ShareImportProvider: Found ${initialMedia.length} initial media items - TESTING');
      if (initialMedia.isNotEmpty) {
        for (int i = 0; i < initialMedia.length; i++) {
          final media = initialMedia[i];
          main.myDebug(
              'ShareImportProvider: Initial media $i: type=${media.type}, path="${media.path}" - TESTING');
        }
        await _handleSharedMediaList(initialMedia);
      } else {
        main.myDebug('ShareImportProvider: NO initial media found - TESTING');

        // TEST: Process our fake payload to verify the import chain works
        main.myDebug(
            'ShareImportProvider: PROCESSING TEST PAYLOAD TO VERIFY IMPORT CHAIN');
        await _shareImportService.handleSharedContent(testPayload);
        main.myDebug('ShareImportProvider: TEST PAYLOAD PROCESSING COMPLETED');
      }
    } catch (e) {
      main.myDebug(
          'ShareImportProvider: Error checking initial intents: $e - TESTING');
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedMedia) async {
    await _handleSharedMediaList(sharedMedia);
  }

  Future<void> _handleSharedMediaList(List<SharedMediaFile> sharedMedia) async {
    main.myDebug(
        'ShareImportProvider: Handling ${sharedMedia.length} shared media items');
    if (sharedMedia.isEmpty) return;

    _isProcessingShare = true;
    notifyListeners();

    // Wait a frame to ensure UI is ready, then show loading overlay
    await Future.delayed(const Duration(milliseconds: 50));

    final context = main.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      await LoadingWait.show(context);
      // Give dialog a moment to actually render
      await Future.delayed(const Duration(milliseconds: 100));
      main.myDebug(
          'ShareImportProvider: Loading overlay displayed and rendered');
    } else {
      main.myDebug(
          'ShareImportProvider: WARNING - Context not available for loading overlay');
    }

    // Track when loading was shown to ensure minimum display time
    final loadingStartTime = DateTime.now();

    try {
      for (final media in sharedMedia) {
        main.myDebug(
            'ShareImportProvider: Processing media: type=${media.type}, path="${media.path}"');
        final payload = _createPayloadFromSharedMedia(media);
        if (payload != null) {
          main.myDebug('ShareImportProvider: Created payload: $payload');
          final song = await _shareImportService.handleSharedContent(payload);
          if (song != null) {
            main.myDebug(
                'ShareImportProvider: Successfully imported song, preparing editor');

            // Ensure loading overlay is displayed for at least 800ms so user sees it
            final elapsedMs =
                DateTime.now().difference(loadingStartTime).inMilliseconds;
            final remainingMs = 800 - elapsedMs;
            if (remainingMs > 0) {
              main.myDebug(
                  'ShareImportProvider: Waiting ${remainingMs}ms to ensure loading is visible');
              await Future.delayed(Duration(milliseconds: remainingMs));
            }

            // Hide loading overlay
            if (context != null && context.mounted) {
              LoadingWait.hide(context);
              main.myDebug('ShareImportProvider: Loading overlay hidden');
            }

            // Small delay before navigation for smooth transition
            await Future.delayed(const Duration(milliseconds: 100));

            // Navigate to editor
            _navigateToEditor(song);
          } else {
            main.myDebug(
                'ShareImportProvider: Import returned null (unsupported content)');
            // Hide loading on failure (no minimum time for failures)
            if (context != null && context.mounted) {
              LoadingWait.hide(context);
            }
          }
        } else {
          main.myDebug(
              'ShareImportProvider: Failed to create payload from media');
          // Hide loading on failure
          if (context != null && context.mounted) {
            LoadingWait.hide(context);
          }
        }
      }
    } catch (e) {
      main.myDebug('ShareImportProvider: Error processing shared media: $e');
      // Hide loading on error
      if (context != null && context.mounted) {
        LoadingWait.hide(context);
      }
    } finally {
      _isProcessingShare = false;
      notifyListeners();
    }
  }

  /// Navigate to the Editor with the imported Song
  void _navigateToEditor(Song song) {
    main.myDebug(
        'ShareImportProvider: Opening Editor for song: "${song.title}"');

    // Use the global navigator key to navigate
    final context = main.navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SongEditorScreenRefactored(song: song),
        ),
      );
      main.myDebug('ShareImportProvider: Navigation to Editor initiated');
    } else {
      main.myDebug(
          'ShareImportProvider: ERROR - Navigator context is null, cannot navigate');
    }
  }

  SharedImportPayload? _createPayloadFromSharedMedia(SharedMediaFile media) {
    main.myDebug(
        'ShareImportProvider: Creating payload from media type=${media.type}');

    // Note: iOS Share Extension now reads file content and passes it as TEXT
    // We no longer need to handle file:// URLs here
    if (media.type == SharedMediaType.text) {
      final payload =
          SharedImportPayload.text(media.path, sourceApp: 'Ultimate Guitar');
      main.myDebug('ShareImportProvider: Created text payload: $payload');
      return payload;
    } else if (media.type == SharedMediaType.url) {
      final uri = Uri.tryParse(media.path);
      if (uri != null) {
        final payload = SharedImportPayload.url(uri, sourceApp: 'Share Intent');
        main.myDebug('ShareImportProvider: Created URL payload: $payload');
        return payload;
      }
    }
    main.myDebug('ShareImportProvider: Unsupported media type, returning null');
    return null;
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }
}
