import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../domain/entities/shared_import_payload.dart';
import '../../domain/entities/song.dart';
import '../../services/import/share_import_service.dart';
import '../../core/widgets/loading_wait.dart';
import '../../../main.dart' as main; // Import for myDebug and navigatorKey
import '../screens/song_editor_screen_refactored.dart';
import 'song_provider.dart';

/// Provider for handling share intent events and routing to ShareImportService
class ShareImportProvider extends ChangeNotifier {
  final ShareImportService _shareImportService = ShareImportService();

  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;

  bool _isProcessingShare = false;

  bool get isProcessingShare => _isProcessingShare;

  ShareImportProvider() {
    _initializeShareHandling();
  }

  void _initializeShareHandling() {
    // Listen for shared media (text, URLs)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleSharedMedia, onError: (error) {
      _isProcessingShare = false;
      notifyListeners();
    });

    // Check for any pending intents when app starts
    _checkInitialIntents();
  }

  Future<void> _checkInitialIntents() async {
    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialMedia.isNotEmpty) {
      await _handleSharedMediaList(initialMedia);
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> sharedMedia) async {
    await _handleSharedMediaList(sharedMedia);
  }

  Future<void> _handleSharedMediaList(List<SharedMediaFile> sharedMedia) async {
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
    }

    // Track when loading was shown to ensure minimum display time
    final loadingStartTime = DateTime.now();

    try {
      for (final media in sharedMedia) {
        final payload = _createPayloadFromSharedMedia(media);
        if (payload != null) {
          final song = await _shareImportService.handleSharedContent(payload);
          if (song != null) {
            // Ensure loading overlay is displayed for at least 800ms so user sees it
            final elapsedMs =
                DateTime.now().difference(loadingStartTime).inMilliseconds;
            final remainingMs = 800 - elapsedMs;
            if (remainingMs > 0) {
              await Future.delayed(Duration(milliseconds: remainingMs));
            }

            // Hide loading overlay
            if (context != null && context.mounted) {
              LoadingWait.hide(context);
            }

            // Small delay before navigation for smooth transition
            await Future.delayed(const Duration(milliseconds: 100));

            // Navigate to editor
            _navigateToEditor(song);
          } else {
            // Hide loading on failure
            if (context != null && context.mounted) {
              LoadingWait.hide(context);
            }
          }
        } else {
          // Hide loading on failure
          if (context != null && context.mounted) {
            LoadingWait.hide(context);
          }
        }
      }
    } catch (e) {
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
  Future<void> _navigateToEditor(Song song) async {
    // Use the global navigator key to navigate
    final context = main.navigatorKey.currentContext;
    if (context != null) {
      main.myDebug(
          'ShareImportProvider: Opening song editor for imported song ID: ${song.id}');
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SongEditorScreenRefactored(song: song),
        ),
      );
      main.myDebug('ShareImportProvider: Song editor returned result: $result');

      // Refresh the song list if the song was saved successfully
      if (result == true && context.mounted) {
        main.myDebug(
            'ShareImportProvider: Refreshing song list after successful save');
        try {
          final songProvider =
              Provider.of<SongProvider>(context, listen: false);
          await songProvider.loadSongs();
          main.myDebug('ShareImportProvider: Song list refresh completed');
        } catch (e) {
          main.myDebug('ShareImportProvider: Error refreshing song list: $e');
        }
      } else {
        main.myDebug(
            'ShareImportProvider: Not refreshing - result was not true or context not mounted');
      }
    }
  }

  SharedImportPayload? _createPayloadFromSharedMedia(SharedMediaFile media) {
    // Note: iOS Share Extension now reads file content and passes it as TEXT
    // We no longer need to handle file:// URLs here
    if (media.type == SharedMediaType.text) {
      final payload =
          SharedImportPayload.text(media.path, sourceApp: 'Ultimate Guitar');
      return payload;
    } else if (media.type == SharedMediaType.url) {
      final uri = Uri.tryParse(media.path);
      if (uri != null) {
        final payload = SharedImportPayload.url(uri, sourceApp: 'Share Intent');
        return payload;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }
}
