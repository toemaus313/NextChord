# Active Debug Logs - NextChord Complete Codebase

This document tracks ALL active debug logs across the entire NextChord codebase for easy maintenance and troubleshooting.

**Total Active Debug Statements**: 141 debugPrint calls across 13 files
**Last Audit Date**: 2025-11-23
**Audit Method**: `Grep` search for `debugPrint` pattern across entire codebase

## Cloud Database Backup Service Logs
**Location**: `lib/services/sync/cloud_db_backup_service.dart`
- `[timestamp] CloudDbBackup: Starting cloud backup maintenance`
- `[timestamp] CloudDbBackup: Google Drive not signed in - skipping backup maintenance`
- `[timestamp] CloudDbBackup: Failed to create/find backup folder`
- `[timestamp] CloudDbBackup: No cloud backup found - creating initial backup`
- `[timestamp] CloudDbBackup: Cloud backup found, age: X minutes`
- `[timestamp] CloudDbBackup: Backup is older than 1 hour - refreshing`
- `[timestamp] CloudDbBackup: Backup is recent - no action needed`
- `[timestamp] CloudDbBackup: Backup maintenance failed: X`
- `[timestamp] CloudDbBackup: Starting database restore from cloud`
- `[timestamp] CloudDbBackup: Cloud backup found - downloading`
- `[timestamp] CloudDbBackup: Backup downloaded to: X`
- `[timestamp] CloudDbBackup: Failed to download backup: X`
- `[timestamp] CloudDbBackup: Backup file is too small or does not exist`
- `[timestamp] CloudDbBackup: Backup file does not have valid SQLite header`
- `[timestamp] CloudDbBackup: Backup file validation passed`
- `[timestamp] CloudDbBackup: Backup file validation failed: X`
- `[timestamp] CloudDbBackup: Created safety backup: X`
- `[timestamp] CloudDbBackup: Closing database connection`
- `[timestamp] CloudDbBackup: Replacing database file`
- `[timestamp] CloudDbBackup: Database file replaced successfully - app restart required`
- `[timestamp] CloudDbBackup: Database replacement failed, attempting restore: X`
- `[timestamp] CloudDbBackup: Restored original database from backup`
- `[timestamp] CloudDbBackup: Failed to restore original database: X`
- `[timestamp] CloudDbBackup: Warning: Failed to clean up safety backup: X`
- `[timestamp] CloudDbBackup: Failed to replace local database: X`
- `[timestamp] CloudDbBackup: Database restore completed successfully`
- `[timestamp] CloudDbBackup: Database restore failed: X`
- `[timestamp] CloudDbBackup: Uploading database backup (X bytes)`
- `[timestamp] CloudDbBackup: Updating existing backup file`
- `[timestamp] CloudDbBackup: Creating new backup file`
- `[timestamp] CloudDbBackup: Database backup uploaded successfully`
- `[timestamp] CloudDbBackup: Failed to upload database backup: X`
- `[timestamp] CloudDbBackup: Failed to check for cloud backup: X`
- `[timestamp] CloudDbBackup: Warning: Failed to delete temp file: X`

## Sync Lifecycle Logs
**Location**: `lib/services/sync/google_drive_sync_service.dart`
- `[timestamp] Using GoogleSignIn for mobile platform`
- `[timestamp] Using web OAuth for desktop platform`
- `[timestamp] Library metadata retrieved: modified=X, md5=Y`
- `[timestamp] Local DB change detected - starting sync`
- `[timestamp] Remote change detection started`
- `[timestamp] Remote library file found, downloading`
- `[timestamp] Remote change detected - JSON downloaded and validated`
- `[timestamp] Current sync state - Last remote version: X, Last sync: Y`
- `[timestamp] Merge started - processing remote changes`
- `[timestamp] Merge completed - remote changes integrated`
- `[timestamp] Local library exported - size: X characters`
- `[timestamp] Uploading merged library to remote`
- `[timestamp] Remote upload completed`
- `[timestamp] Sync completed successfully`
- `[timestamp] Starting metadata polling (10s interval)`
- `[timestamp] Metadata polling already active`
- `[timestamp] Stopping metadata polling`
- `[timestamp] 🔍 Metadata poll: checking remote file changes`
- `[timestamp] 🔄 Remote changes detected, triggering full sync`
- `[timestamp] ✅ No remote changes detected`
- `[timestamp] ⚠️ Error during metadata poll: X`
- `Library metadata: No remote file found`
- `No remote library file found`
- `Library changes detected - will upload`
- `No library changes - skipping upload`

## Authentication & OAuth Logs
**Location**: `lib/services/sync/google_drive_sync_service.dart`
- `[timestamp] Sign in failed: X`
- `[timestamp] OAuth server started on port 8000`
- `[timestamp] OAuth authentication failed: X`
- `[timestamp] Sign out error: X`
- `[timestamp] Token refresh successful`
- `Failed to create Drive API: X`

## Sync Provider & App Lifecycle Logs
**Location**: `lib/providers/sync_provider.dart`
- `Remote library change detected, triggering full sync`
- `Remote library unchanged, skipping sync`
- `Error during metadata polling: X`
- `App resumed, starting metadata polling`
- `App paused, stopping metadata polling`

## Database Change Detection Logs
**Location**: `lib/core/services/database_change_service.dart`
- `🔍 DB CHANGE DETECTED: operation=X, table=Y`
- `⏭️ Skipping DB change notification during sync operation`
- `⏰ Scheduling auto-sync in 500ms...`
- `🚀 Triggering auto-sync after database change`
- `🔄 Sync in progress: X`
- `✅ Sync completed - cancelled pending change notifications`
- `🔍 DatabaseChangeService already initialized`
- `🔍 DatabaseChangeService initialized with database`
- `🔍 Starting reactive database monitoring`
- `🔍 Stopping reactive database monitoring`
- `🔍 Songs table changed: X songs`
- `🔍 Setlists table changed: X setlists`
- `🔍 Song count changed: X`
- `🔍 Setlist count changed: X`
- `🔍 Deleted song count changed: X`
- `🔍 Emitting DB change event: DbChangeEvent(table: X, type: Y, recordId: Z, timestamp: T)`
- `🔍 Disposing DatabaseChangeService`

## Song Provider Reactive Update Logs
**Location**: `lib/presentation/providers/song_provider.dart`
- `🎵 SongProvider received DB change: X`
- `🎵 SongProvider refreshing from database change`
- `🎵 Error refreshing from database change: X`
- `🎵 Error refreshing songs list: X`
- `🎵 Error refreshing deleted songs list: X`
- `🎵 SongProvider.loadSongs() called - checking if in build phase`
- `🎵 About to call notifyListeners() in loadSongs()`
- `🎵 notifyListeners() completed in loadSongs()`
- `🎵 SongProvider: Database change monitoring temporarily disabled for debugging`

## Setlist Provider Reactive Update Logs
**Location**: `lib/presentation/providers/setlist_provider.dart`
- `📋 SetlistProvider received DB change: X`
- `📋 SetlistProvider refreshing from database change`
- `📋 Error refreshing from database change: X`
- `📋 Error refreshing setlists list: X`
- `📋 Active setlist refreshed: X`
- `📋 Active setlist was deleted, clearing state`
- `📋 Error refreshing active setlist: X`
- `📋 SetlistProvider: Database change monitoring temporarily disabled for debugging`

## Global Sidebar Provider Reactive Update Logs
**Location**: `lib/presentation/providers/global_sidebar_provider.dart`
- `📱 GlobalSidebarProvider received DB change: X`
- `📱 Sidebar counts updated, notifying listeners`
- `📱 GlobalSidebarProvider: Database change monitoring temporarily disabled for debugging`

## Song Viewer Provider State Preservation Logs
**Location**: `lib/presentation/providers/song_viewer_provider.dart`
- `🎵 SongViewerProvider updating song content only: X`
- `🎵 SongViewerProvider received DB change: X`
- `🎵 SongViewerProvider refreshing current song from database`
- `🎵 Song content change detected for current song: X`
- `🎵 Error refreshing current song from database: X`
- `🎵 SongViewerProvider: Skipping self-triggered event`
- `🎵 SongViewerProvider received DB change: table=X, recordId=Y, currentSongId=Z`
- `🎵 SongViewerProvider: RecordId MATCHES current song - refreshing!`
- `🎵 SongViewerProvider: RecordId does NOT match current song (X != Y) - ignoring`

## Setlist Navigation & Sidebar Controller Logs
**Location**: `lib/presentation/controllers/global_sidebar_controller.dart`
- `GlobalSidebarController: Initializing with SetlistProvider`
- `GlobalSidebarController: navigateToView called with view=X, setlistId=Y`
- `GlobalSidebarController: Clearing active setlist`
- `GlobalSidebarController: Activating setlist X`
- `GlobalSidebarController: Setlist activation completed`
- `GlobalSidebarController: navigateToMenu called - clearing active setlist`
- `GlobalSidebarController: navigateToMenuKeepSongsExpanded called - clearing active setlist`

## App Initialization & Build-Phase Debugging Logs
**Location**: `lib/main.dart`
- `🔄 onSyncCompleted callback triggered - checking if in build phase`
- `🔄 Post-frame callback executing - calling loadSongs()`
- `🔄 All provider load methods called in post-frame callback`
- `🏗️ NextChordApp.build() called - platform-specific build phase`
- `🏗️ App initializing - showing loading indicator`
- `🏗️ App initialization completed after frame delay`
- `🏗️ App initialization complete - building widget tree`

## Sidebar Menu View Debugging Logs
**Location**: `lib/presentation/widgets/sidebar_views/sidebar_menu_view.dart`
- `Building setlists section...`
- `Setlists section tapped`
- `Loading setlists...`
- `Setlists loaded successfully`
- `Error loading setlists: X`
- `Error loading song counts: X`

## Detailed Merge Delta Logs
**Location**: `lib/services/sync/library_sync_service.dart`
- `[timestamp] Merge analysis started - parsing remote JSON`
- `[timestamp] Local vs Remote comparison - Songs: X local vs Y remote`
- `[timestamp] Local vs Remote comparison - Setlists: X local vs Y remote`
- `[timestamp] Local vs Remote comparison - MidiMappings: X local vs Y remote`
- `[timestamp] Local vs Remote comparison - MidiProfiles: X local vs Y remote`
- `[timestamp] Merge completed with detailed deltas:`
- Detailed delta summary showing:
  - `Songs: X added, Y deleted, Z updated`
  - `Song changes: Song Name: tags removed, Song Name: key changed from C to G, etc.`
  - `Setlists: X added, Y deleted, Z updated`
  - `MIDI Mappings: X added, Y deleted, Z updated`
  - `MIDI Profiles: X added, Y deleted, Z updated`
- `Successfully imported and merged library from JSON`

## Song ID Tracking & Database Change Event Logs
**Location**: `lib/services/sync/library_sync_service.dart`
- `[timestamp] 📝 Tracking updated song ID for change event: X`
- `[timestamp] ⚠️ WARNING: Song has null ID, cannot track for change event`
- `[timestamp] 📡 Emitting database change events for X updated songs`
- `[timestamp] 📡 Updated song IDs: X, Y, Z`
- `[timestamp] 📡 Emitting change event for song ID: X`
- `[timestamp] 📡 All change events emitted successfully`
- `[timestamp] ℹ️ No song IDs to emit change events for`

## Hash Comparison Logs
**Location**: `lib/services/sync/library_sync_service.dart`
- `⚠️ Library content has changed - upload needed`
- `✅ Library content identical - skipping upload`

## Error Handling Logs
**Location**: `lib/services/sync/library_sync_service.dart`
- `Error checking if library changed: X`
- `Error checking if merged library changed: X`
- `Error extracting library content: X`
- `Error storing uploaded library hash: X`
- `Error getting last seen metadata: X`
- `Error exporting library to JSON: X`
- `Error importing library from JSON: X`
- `No previous sync state - remote file considered as change`
- `Remote file has changed - new MD5 or timestamp detected`
- `Remote file unchanged - same MD5 and timestamp`
- `Error checking remote changes: X`

**Location**: `lib/services/sync/google_drive_sync_service.dart`
- `Error saving universal tokens: X`
- `Error clearing universal tokens: X`
- `Error getting library metadata: X`
- `Sync failed: X`
- `Merge failed: X`
- `Error uploading library JSON: X`

**Location**: `lib/providers/sync_provider.dart`
- `Error during metadata polling: X`

**Location**: `lib/data/database/migrations/migrations.dart`
- `Migration 8->9: sync_state.lastRemoteFileId column already exists: X`
- `Migration 8->9: sync_state.lastRemoteModifiedTime column already exists: X`
- `Migration 8->9: sync_state.lastRemoteMd5Checksum column already exists: X`
- `Migration 8->9: sync_state.lastRemoteHeadRevisionId column already exists: X`
- `Migration 8->9: sync_state.lastUploadedLibraryHash column already exists: X`

## Removed Debug Logs (Historical)
The following verbose debug logs have been removed for cleaner output:
- Hash comparison details (🔍 Hash comparison: merged=..., remote=...)
- Content size comparisons (📏 Content sizes: ...)
- Normalized JSON content previews (📄 MERGED normalized content: ...)
- First difference position analysis (🔍 First difference at position X: ...)
- Verbose merge progress logs (Starting songs merge - analyzing deltas, etc.)

## Quick Reference for Future Changes

### To Add New Debug Logs:
1. Use `debugPrint()` instead of `print()`
2. Include relevant context (operation, table, record names)
3. Use consistent emoji prefixes for easy scanning:
   - 🔍 for analysis/comparison
   - ⚠️ for warnings/changes detected
   - ✅ for success/skipped operations
   - 🔄 for state changes
   - 📏 for size/measurements
   - 📄 for content previews

### To Remove/Modify Debug Logs:
1. Update this document immediately after changes
2. Consider impact on troubleshooting capabilities
3. Maintain essential sync lifecycle logs
4. Keep error handling logs for production debugging

### Sync Troubleshooting Flow:
1. **Metadata polling**: Look for "Library metadata retrieved" and "Remote library change detected"
2. **Database changes**: Look for "🔍 DB CHANGE DETECTED" with operation/table info
3. **Merge analysis**: Look for detailed delta summary showing specific field changes
4. **Upload decisions**: Look for "⚠️ Library content has changed" vs "✅ Library content identical"
5. **Sync completion**: Look for "Sync completed successfully" or error messages

## File Locations Summary
- **Sync Provider**: `lib/providers/sync_provider.dart` (12 statements)
- **Google Drive Service**: `lib/services/sync/google_drive_sync_service.dart` (47 statements)
- **Library Sync Service**: `lib/services/sync/library_sync_service.dart` (36 statements)
- **Database Change Service**: `lib/core/services/database_change_service.dart` (9 statements)
- **Song Provider**: `lib/presentation/providers/song_provider.dart` (13 statements)
- **Setlist Provider**: `lib/presentation/providers/setlist_provider.dart` (8 statements)
- **Global Sidebar Provider**: `lib/presentation/providers/global_sidebar_provider.dart` (3 statements)
- **Song Viewer Provider**: `lib/presentation/providers/song_viewer_provider.dart` (9 statements)
- **Global Sidebar Controller**: `lib/presentation/controllers/global_sidebar_controller.dart` (8 statements)
- **Database Migrations**: `lib/data/database/migrations/migrations.dart` (16 statements)
- **Sidebar Menu View**: `lib/presentation/widgets/sidebar_views/sidebar_menu_view.dart` (7 statements)
- **App Initialization (main.dart)**: `lib/main.dart` (7 statements)
- **Other Files**: Various additional files with debug statements

## New Reactive Database Monitoring System
**Added**: 17 new debugPrint statements for reactive UI updates
- Database change detection and event emission
- Provider-specific reactive update handling
- State preservation during automatic updates
- Non-disruptive UI refresh mechanisms

## Song Viewer Auto-Refresh Debug System (NEW)
**Added**: 8 new debugPrint statements for song viewer remote sync auto-refresh
- Song ID tracking during merge operations (`📝 Tracking updated song ID`)
- Database change event emission with specific song IDs (`📡 Emitting change event`)
- Event reception and filtering in SongViewerProvider (`🎵 received DB change`)
- Record ID matching logic (`🎵 RecordId MATCHES` vs `🎵 RecordId does NOT match`)
- Null ID warning handling (`⚠️ WARNING: Song has null ID`)
- Complete flow tracing from remote sync to UI refresh

## VS Code Debug Configuration Documentation
**Location**: `PROJECT_SETUP.md` - "VS Code Debug Configuration (Windows)" section
- Documents optimized debug settings for Windows "Connected to VM Service" hangs
- Includes `.vscode/settings.json` and `.vscode/launch.json` configurations
- Troubleshooting steps for debug connection issues
- Alternative command-line debugging approaches

---
*Last Updated: 2025-11-23*
*Purpose: Document active debug logs for sync system and reactive UI maintenance*
