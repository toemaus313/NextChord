# Active Debug Logs - NextChord Complete Codebase

This document tracks ALL active debug logs across the entire NextChord codebase for easy maintenance and troubleshooting.

**Total Active Debug Statements**: 67 debugPrint calls across 5 files
**Last Audit Date**: 2025-11-23
**Audit Method**: `Grep` search for `debugPrint` pattern across entire codebase

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

## Setlist Navigation & Sidebar Controller Logs
**Location**: `lib/presentation/controllers/global_sidebar_controller.dart`
- `GlobalSidebarController: Initializing with SetlistProvider`
- `GlobalSidebarController: navigateToView called with view=X, setlistId=Y`
- `GlobalSidebarController: Clearing active setlist`
- `GlobalSidebarController: Activating setlist X`
- `GlobalSidebarController: Setlist activation completed`
- `GlobalSidebarController: navigateToMenu called - clearing active setlist`
- `GlobalSidebarController: navigateToMenuKeepSongsExpanded called - clearing active setlist`

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

**Location**: `lib/services/sync/google_drive_sync_service.dart`
- `Error saving universal tokens: X`
- `Error clearing universal tokens: X`
- `Error getting library metadata: X`
- `Sync failed: X`
- `Merge failed: X`
- `Error uploading library JSON: X`

**Location**: `lib/providers/sync_provider.dart`
- `Error during metadata polling: X`

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
- **Sync Provider**: `lib/providers/sync_provider.dart`
- **Google Drive Service**: `lib/services/sync/google_drive_sync_service.dart`
- **Library Sync Service**: `lib/services/sync/library_sync_service.dart`
- **Database Change Service**: `lib/core/services/database_change_service.dart`
- **Global Sidebar Controller**: `lib/presentation/controllers/global_sidebar_controller.dart`
- **Song Repository**: `lib/data/repositories/song_repository.dart`
- **Setlist Repository**: `lib/data/repositories/setlist_repository.dart`

---
*Last Updated: 2025-11-23*
*Purpose: Document active debug logs for sync system maintenance*
