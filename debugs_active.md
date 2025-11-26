# Active Debug Logs - NextChord Codebase

## Status: DEBUG CLEANUP COMPLETED + Two-Step Metadata Lookup Debugging

**Updated**: 2025-11-26  
**Purpose**: SQLite and sync debugging only (general debugging removed) + Two-step metadata lookup flow debugging

---

## Current Active Debug Statements (SQLite/Sync Only + Metadata Lookup + Google Sign-In)

### Global Debug Foundation
- **File**: `lib/main.dart`
- **Function**: `myDebug(String message)`
- **Flag**: `bool isDebug = true`
- **Format**: `[$timestamp] $message` (HH:MM:SS format)
- **Description**: Standardized debug helper with timestamps for consistent logging across the app

### Google Sign-In Debugging (NEW)
- **File**: `lib/providers/sync_provider.dart`
- **Function**: `_loadSyncPreference()`
- **Message**: Sync preference loading and sign-in status verification
- **Trigger**: During app initialization when loading sync settings
- **Description**: Tracks whether sync was previously enabled and actual sign-in status verification

- **File**: `lib/providers/sync_provider.dart`
- **Function**: `signIn()`
- **Message**: Sign-in process start, result, and error tracking
- **Trigger**: When user taps "Sign In" button
- **Description**: Tracks complete sign-in flow including success/failure and initial sync

- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Function**: `isSignedIn()`
- **Message**: Platform-specific sign-in status checking
- **Trigger**: When verifying if user is currently signed in
- **Description**: Tracks GoogleSignIn.isSignedIn() results and token validation

- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Function**: `signIn()`
- **Message**: GoogleSignIn.signIn() execution and results
- **Trigger**: When attempting to sign in with Google
- **Description**: Tracks GoogleSignIn account results and user email on success

### Two-Step Metadata Lookup Debugging
- **File**: `lib/services/song_metadata_service.dart`
- **Function**: `completeTitleOnlyLookup()`
- **Message**: MusicBrainz API query and response tracing
- **Trigger**: When user accepts title-only confirmation dialog
- **Description**: Tracks MusicBrainz API calls, query parameters, and response data for duration lookup

- **File**: `lib/presentation/controllers/song_editor/song_editor_controller.dart`
- **Function**: `confirmTitleOnlyLookup()` and `_applyMetadataResult()`
- **Message**: Metadata application flow and field updates
- **Trigger**: During confirmation acceptance and metadata sync
- **Description**: Tracks controller state changes and metadata field updates

- **File**: `lib/presentation/screens/song_editor_screen_refactored.dart`
- **Function**: `_handleControllerStateChange()`
- **Message**: UI sync from controller to screen controllers
- **Trigger**: When metadata changes need to be reflected in UI
- **Description**: Tracks synchronization between controller and screen state

### Ultimate Guitar Import Debugging (NEW)
- **File**: `lib/presentation/screens/song_editor_screen_refactored.dart`
- **Functions**:
  - `_importFromUltimateGuitar()`
  - `_convertToChordPro()`
- **Messages**:
  - UG import lifecycle (dialog dismissed, start, success/failure, metadata lookup trigger)
  - Content metadata extraction skips when form already populated
- **Trigger**: When user taps "Import from Ultimate Guitar" or runs conversion logic that should skip metadata extraction
- **Description**: Provides visibility into URL import flow, including fetch attempts, validation errors, and follow-on metadata lookups to aid post-launch troubleshooting.

### Global Error Handler
- **File**: `lib/main.dart`
- **Function**: Global error handlers in main()
- **Message**: `"[$timestamp] GLOBAL ERROR: $error"` and `"[$timestamp] FRAMEWORK ERROR: $error"`
- **Trigger**: Catches all unhandled exceptions including SQLite errors throughout the app
- **Description**: App-wide error catching to capture SQLite constraint failures and similar exceptions

### Google Sync Service Debug Logging
- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Location**: Line 663 (metadata polling)
- **Message**: `"[$timestamp] Remote change detected in Google Drive - triggering sync"`
- **Trigger**: When remote changes are detected during metadata polling

- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Location**: Line 498 (sync application)
- **Message**: `"[$timestamp] Remote changes successfully applied to local database"`
- **Trigger**: When remote changes are successfully merged into the local database

### Local Database Change Debug Logging
- **File**: `lib/core/services/database_change_service.dart`
- **Location**: Line 79 (change notification)
- **Message**: `"[$timestamp] Local db change detected - sending to cloud"`
- **Trigger**: When local database changes are detected and scheduled for sync

- **File**: `lib/providers/sync_provider.dart`
- **Location**: Line 184 (sync completion)
- **Message**: `"[$timestamp] Local db change successfully sent to cloud"`
- **Trigger**: When local changes are successfully uploaded to Google Drive

### Song Repository Database Debug Logging
- **File**: `lib/data/repositories/song_repository.dart`
- **Function**: Local `myDebug(String message)` function
- **Messages**: Database operation tracking and SQLite error reporting
- **Trigger**: During database insert/update operations and SQLite failures

---

## What Was Removed (Debug Cleanup)

### General Debugging Removed:
- **Song Editor**: All conversion, save, and validation debugging
- **Song Persistence Service**: All save/update operation debugging
- **Song Metadata Form**: All form validation debugging
- **Share Import Provider**: All import flow debugging
- **Song Provider**: All song loading debugging
- **Library Screen**: All navigation and refresh debugging
- **Main App Initialization**: All app startup debugging

### Files Cleaned:
- `lib/presentation/screens/song_editor_screen_refactored.dart`
- `lib/services/song_editor/song_persistence_service.dart`
- `lib/presentation/widgets/song_editor/song_metadata_form.dart`
- `lib/presentation/providers/share_import_provider.dart`
- `lib/presentation/providers/song_provider.dart`
- `lib/presentation/screens/library_screen.dart`
- `lib/main.dart`

---

## Debug Behavior

### What Gets Logged:
1. **Global Errors**: All unhandled exceptions including SQLite constraint failures
2. **Framework Errors**: Flutter framework errors and exceptions
3. **Local Change Detection**: When local database changes are detected and scheduled for cloud sync
4. **Remote Change Detection**: When the metadata polling detects changes in Google Drive
5. **Successful Sync Application**: When remote changes are successfully applied to the local database
6. **Successful Local Upload**: When local changes are successfully uploaded to Google Drive
7. **Database Operations**: SQLite insert/update operations and errors in song repository

### What Does NOT Get Logged:
- Normal sync operations without changes
- Network errors or authentication issues (handled silently)
- Metadata polling when no changes are found
- Manual sync operations without underlying changes
- Song editor operations, form validation, file imports
- App initialization and provider setup

---

## Implementation Notes

- Uses standardized `myDebug()` function with timestamps (HH:MM:SS format)
- iOS Share Extension uses equivalent Swift `myDebug()` function with same format
- Debug output can be toggled globally via `isDebug` flag in `main.dart`
- Global error handlers catch all unhandled exceptions app-wide
- Minimal logging approach - only logs key SQLite/sync events with precise timing
- No performance impact on normal operations
- Provides complete visibility into sync flow in both directions with timing information
- SQLite errors and similar database exceptions are now captured globally

---

*Last Updated: 2025-11-25 4:05 PM PST*  
*Status: Debug Cleanup Completed - SQLite/Sync debugging preserved*
- **Location**: Line 184 (sync completion)
- **Message**: `"[$timestamp] Local db change successfully sent to cloud"`
- **Trigger**: When local changes are successfully uploaded to Google Drive
**END OF EXCEPTIONS SECTION**

*Last Updated: 2025-11-25 12:22 PM PST*  
*Status: Debugging UG Import Flow + Content Type Detection*
