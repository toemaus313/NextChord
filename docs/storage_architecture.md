# NextChord Storage Architecture

This document describes the storage and sync architecture for NextChord, including support for multiple cloud backends (Google Drive and iCloud Drive).

## Overview

NextChord supports three storage backends:
- **Local Only**: Data stored locally on device with no cloud sync
- **Google Drive**: Cloud sync and backup via Google Drive
- **iCloud Drive**: Cloud sync and backup via iCloud Drive (Apple platforms only)

## Core Components

### Sync Backend Selection

#### `SyncBackend` enum (`lib/core/enums/sync_backend.dart`)
- Defines available storage backends
- Provides platform availability checks
- Handles display names and descriptions for UI

### Sync Services

#### `GoogleDriveSyncService` (`lib/services/sync/google_drive_sync_service.dart`)
- Handles Google Drive authentication and file operations
- Manages metadata polling for change detection
- Coordinates JSON-based library synchronization

#### `ICloudSyncService` (`lib/services/sync/icloud_sync_service.dart`)
- Mirrors GoogleDriveSyncService API for compatibility
- Uses platform channels for iCloud Drive operations
- Manages ubiquity container access for visible NextChord folder

### Database Backup Services

#### `CloudDbBackupService` (`lib/services/sync/cloud_db_backup_service.dart`)
- Handles full database backups to Google Drive
- Uses Google Drive API for file upload/download
- Maintains backup versioning and validation

#### `ICloudDbBackupService` (`lib/services/sync/icloud_db_backup_service.dart`)
- Separate service for iCloud database backups
- Uses platform channels for file operations
- Maintains same backup file structure as Google Drive

### Data Synchronization

#### `LibrarySyncService` (`lib/services/sync/library_sync_service.dart`)
- Backend-agnostic JSON export/import logic
- Handles record merging with last-write-wins strategy
- Manages change detection and hash comparison

### UI and State Management

#### `SyncProvider` (`lib/providers/sync_provider.dart`)
- Central coordinator for sync operations
- Manages backend switching and migration
- Handles app lifecycle events and metadata polling

#### `StorageSettingsModal` (`lib/presentation/widgets/storage_settings_modal.dart`)
- UI for backend selection and sync management
- Platform-gated display of available options
- Sign-in/out and sync action buttons

## File Structure and Naming

### Google Drive
- **Folder**: `NextChord/` (root of user's Google Drive)
- **Library JSON**: `library.json` (incremental sync metadata)
- **Database Backup**: `nextchord_backup.db` (full database backup)

### iCloud Drive
- **Folder**: `NextChord/` (root of user's iCloud Drive, visible in Files app)
- **Library JSON**: `library.json` (same structure as Google Drive)
- **Database Backup**: `nextchord_backup.db` (same structure as Google Drive)

## Platform-Specific Implementation

### iOS/macOS iCloud Integration

#### Platform Channels (`ios/Runner/ICloudDrivePlugin.swift`, `macos/Runner/ICloudDrivePlugin.swift`)
- Native Swift implementations for iCloud Drive access
- Uses NSFileManager ubiquity container APIs
- Handles file upload/download and metadata operations

#### Required Entitlements
- **iOS**: `ios/Runner/Runner.entitlements`
- **macOS**: `macos/Runner/Runner.entitlements`
- **Info.plist**: NSUbiquitousContainers configuration

### Google Drive Integration
- GoogleSignIn for mobile platforms
- Web OAuth flow for desktop platforms
- Universal token persistence across platforms

## Migration Logic

When upgrading from single-backend (Google Drive only) to multi-backend system:
1. Existing Google Drive users default to Google Drive backend
2. New users default to Local storage
3. Backend preference persisted in SharedPreferences
4. Seamless switching between backends without data loss

## Debug Logging

All sync operations use `myDebug()` wrapper:
- **Category**: "Storage" for backend operations
- **Category**: "Sync" for synchronization events
- **Category**: "Auth" for authentication operations

Key logging points:
- Backend selection changes
- Authentication status updates
- File upload/download operations
- Sync completion and errors
- iCloud folder creation/access

## Error Handling

### Google Drive
- OAuth configuration validation
- Token refresh and expiration handling
- Network connectivity issues

### iCloud Drive
- Entitlements validation
- Ubiquity container availability
- File system permissions

### Fallback Behavior
- Graceful degradation when cloud services unavailable
- Local-only operation as fallback
- User-friendly error messages for configuration issues

## Testing Considerations

### Unit Tests
- Backend selection logic
- File path construction
- Migration behavior

### Integration Tests
- Google Drive API integration
- iCloud platform channel operations
- End-to-end sync workflows

### Platform Testing
- iOS: iCloud ubiquity container access
- macOS: iCloud Drive file operations
- Cross-platform backend switching

## Performance Considerations

### Metadata Polling
- 10-second intervals when app is active
- Paused on mobile platforms when app backgrounded
- Efficient change detection using file metadata

### File Operations
- Incremental sync for library JSON
- Full database backup only when needed
- Temporary file cleanup after operations

## Security Considerations

### Google Drive
- OAuth 2.0 authentication
- Secure token storage
- Scoped access to NextChord folder only

### iCloud Drive
- System-level authentication
- App sandbox compliance
- No additional credentials required

## Future Enhancements

### Potential Improvements
- Conflict resolution UI for simultaneous edits
- Selective sync for large libraries
- Offline-first sync with queuing
- Additional cloud providers (OneDrive, Dropbox)

### Scalability
- Large file handling optimization
- Batch operation support
- Background sync improvements
