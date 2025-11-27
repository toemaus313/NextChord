import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Enum representing available sync/storage backends
enum SyncBackend {
  /// Local-only storage (no cloud sync)
  local,

  /// Google Drive cloud storage and sync
  googleDrive,

  /// iCloud Drive cloud storage and sync (Apple platforms only)
  iCloud,
}

/// Extension methods for SyncBackend enum
extension SyncBackendExtension on SyncBackend {
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case SyncBackend.local:
        return 'Local Only';
      case SyncBackend.googleDrive:
        return 'Google Drive';
      case SyncBackend.iCloud:
        return 'iCloud Files';
    }
  }

  /// Get short name for storage/logging
  String get shortName {
    switch (this) {
      case SyncBackend.local:
        return 'local';
      case SyncBackend.googleDrive:
        return 'gdrive';
      case SyncBackend.iCloud:
        return 'icloud';
    }
  }

  /// Check if this backend is available on current platform
  bool get isAvailableOnCurrentPlatform {
    switch (this) {
      case SyncBackend.local:
        return true; // Always available
      case SyncBackend.googleDrive:
        return true; // Available on all platforms with proper setup
      case SyncBackend.iCloud:
        // iCloud available on Apple platforms and Windows with iCloud Drive
        return _isICloudAvailable();
    }
  }

  /// Check if running on Apple platform (iOS/macOS)
  static bool _isApplePlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Check if running on Windows platform
  static bool _isWindowsPlatform() {
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Check if iCloud is available (Apple platforms or Windows with iCloud Drive)
  static bool _isICloudAvailable() {
    return _isApplePlatform() || _isWindowsPlatform();
  }

  /// Get description for UI
  String get description {
    switch (this) {
      case SyncBackend.local:
        return 'Store data locally only, no cloud sync';
      case SyncBackend.googleDrive:
        return 'Sync and backup with Google Drive';
      case SyncBackend.iCloud:
        return 'Sync and backup with iCloud Drive (visible in Files app)';
    }
  }
}
