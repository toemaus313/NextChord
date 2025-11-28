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

### Song Viewer Adjustment Persistence (NEW)
- **File**: `lib/presentation/providers/song_viewer_provider.dart`
- **Function**: `_persistAdjustments()`
- **Messages**:
  - `"SongViewerProvider: saved setlist-only adjustments …"`
  - `"SongViewerProvider: saved global song adjustments …"`
- **Trigger**: When the capo/transpose buttons persist changes
- **Description**: Differentiates whether adjustments were stored against the active setlist item or written directly to the song record.

### Setlist Deletion Debugging (NEW)
- **File**: `lib/presentation/widgets/sidebar_views/sidebar_menu_view.dart`
- **Function**: `_deleteSetlist()`
- **Messages**: 
  - `[SETLIST_DELETE] Starting deletion for setlist: "name" (ID: id)`
  - `[SETLIST_DELETE] User confirmed deletion, calling provider.deleteSetlist()`
  - `[SETLIST_DELETE] Provider.deleteSetlist() completed successfully`
  - `[SETLIST_DELETE] ERROR: $e`
  - `[SETLIST_DELETE] User cancelled deletion`
- **Trigger**: When user right-clicks setlist and selects delete
- **Description**: Tracks complete UI deletion flow including confirmation and error handling

- **File**: `lib/presentation/providers/setlist_provider.dart`
- **Functions**: `deleteSetlist()` and `loadSetlists()`
- **Messages**:
  - `[SETLIST_PROVIDER] deleteSetlist() called with ID: id`
  - `[SETLIST_PROVIDER] Calling repository.deleteSetlist()`
  - `[SETLIST_PROVIDER] Repository.deleteSetlist() completed, calling loadSetlists()`
  - `[SETLIST_PROVIDER] loadSetlists() completed, setlists count: N`
  - `[SETLIST_PROVIDER] ERROR in deleteSetlist(): $e`
  - `[SETLIST_PROVIDER] loadSetlists() called`
  - `[SETLIST_PROVIDER] getAllSetlists() returned N setlists`
  - `[SETLIST_PROVIDER] - Setlist: "name" (ID: id, deleted: false)`
- **Trigger**: During provider-level deletion operations and list refresh
- **Description**: Tracks provider operations and final setlist state after deletion

- **File**: `lib/data/repositories/setlist_repository.dart`
- **Function**: `deleteSetlist()`
- **Messages**:
  - `[SETLIST_REPO] deleteSetlist() called with ID: id`
  - `[SETLIST_REPO] Calling database.deleteSetlist()`
  - `[SETLIST_REPO] Database.deleteSetlist() completed successfully`
  - `[SETLIST_REPO] ERROR in deleteSetlist(): $e`
  - `[SETLIST_REPO] Notifying database change service`
- **Trigger**: During repository-level deletion operations
- **Description**: Tracks repository operations and database change notifications

- **File**: `lib/data/database/app_database.dart`
- **Functions**: `deleteSetlist()`, `_getDeviceId()`, `_insertDeletionTracking()`
- **Messages**:
  - `[DATABASE] deleteSetlist() called with ID: id`
  - `[DATABASE] Using deviceId: deviceId for deletion tracking`
  - `[DATABASE] Deletion tracking record inserted`
  - `[DATABASE] Hard delete completed successfully for ID: id`
  - `[DATABASE] ERROR in deleteSetlist(): $e`
  - `[DATABASE] ERROR getting deviceId, generating fallback: $e`
  - `[DATABASE] ERROR inserting deletion tracking: $e`
  - `[DATABASE] Deletion tracking inserted: entityType/entityId`
- **Trigger**: During database hard delete operations with sync tracking
- **Description**: Tracks permanent deletion flow including device ID retrieval, tracking record insertion, and hard deletion
