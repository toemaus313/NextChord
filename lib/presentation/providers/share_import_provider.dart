import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:app_links/app_links.dart';
import '../../domain/entities/shared_import_payload.dart';
import '../../domain/entities/song.dart';
import '../../services/import/share_import_service.dart';
import '../../core/widgets/loading_wait.dart';
import '../../../main.dart' as main; // Import for navigatorKey
import '../screens/song_editor_screen_refactored.dart';
import 'song_provider.dart';

/// Provider for handling share intent events and routing to ShareImportService
class ShareImportProvider extends ChangeNotifier {
  final ShareImportService _shareImportService = ShareImportService();

  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;
  final AppLinks _appLinks = AppLinks();

  bool _isProcessingShare = false;

  bool get isProcessingShare => _isProcessingShare;

  ShareImportProvider() {
    initialize();
  }

  void initialize() {
    // Only initialize sharing intent on mobile platforms (iOS/Android)
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      // Listen for URL-based share data (no App Groups needed)
      _appLinksSubscription =
          _appLinks.uriLinkStream.listen(_handleUrlScheme, onError: (error) {
        _isProcessingShare = false;
        notifyListeners();
      });

      // Also keep the standard share intent for other sharing methods
      _intentDataStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(_handleSharedMedia, onError: (error) {
        _isProcessingShare = false;
        notifyListeners();
      });

      // Check for any pending intents when app starts
      _checkInitialIntents();
      _checkInitialUrl();
    }
  }

  Future<void> _checkInitialIntents() async {
    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialMedia.isNotEmpty) {
      await _handleSharedMediaList(initialMedia);
    }
  }

  Future<void> _checkInitialUrl() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUrlScheme(initialUri);
      }
    } catch (e) {
      // Ignore errors when checking initial URL
    }
  }

  Future<void> _handleUrlScheme(Uri uri) async {
    // Check if this is a share URL from our Share Extension
    if (uri.scheme.startsWith('ShareMedia') && uri.host == 'share') {
      final dataParam = uri.queryParameters['data'];
      if (dataParam != null && dataParam.isNotEmpty) {
        try {
          // Decode base64 and parse JSON
          final jsonString = utf8.decode(base64.decode(dataParam));
          final List<dynamic> jsonList = json.decode(jsonString);

          // Convert to SharedMediaFile list
          final sharedMedia = jsonList.map((item) {
            final type = _parseMediaType(item['type']);
            return SharedMediaFile(
              path: item['path'] ?? '',
              thumbnail: null,
              duration: item['duration']?.toDouble(),
              type: type,
              mimeType: item['mimeType'],
            );
          }).toList();

          await _handleSharedMediaList(sharedMedia);
        } catch (e) {
          // Failed to parse URL data
          _isProcessingShare = false;
          notifyListeners();
        }
      }
    }
  }

  SharedMediaType _parseMediaType(String? typeString) {
    switch (typeString) {
      case 'text':
        return SharedMediaType.text;
      case 'url':
        return SharedMediaType.url;
      case 'image':
        return SharedMediaType.image;
      case 'video':
        return SharedMediaType.video;
      case 'file':
        return SharedMediaType.file;
      default:
        return SharedMediaType.text;
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
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SongEditorScreenRefactored(song: song),
        ),
      );

      // Refresh the song list if the song was saved successfully
      if (result == true && context.mounted) {
        try {
          final songProvider =
              Provider.of<SongProvider>(context, listen: false);
          await songProvider.loadSongs();
        } catch (e) {
          // Error refreshing song list
        }
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
    _appLinksSubscription?.cancel();
    super.dispose();
  }
}
