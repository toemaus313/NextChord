# Active Debug Logs - NextChord Codebase

## Status: ACTIVE DEBUG LOGGING ✅

**Updated**: 2025-11-24  
**Purpose**: Minimal debug logging for Google sync functionality

---

## Current Active Debug Statements

### ✅ Global Debug Foundation
- **File**: `lib/main.dart`
- **Function**: `myDebug(String message)`
- **Flag**: `bool isDebug = true`
- **Format**: `[$timestamp] $message` (HH:MM:SS format)
- **Description**: Standardized debug helper with timestamps for consistent logging across the app

### ✅ Google Sync Service Debug Logging
- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Location**: Line 663 (metadata polling)
- **Message**: `"[HH:MM:SS] Remote change detected in Google Drive - triggering sync"`
- **Trigger**: When remote changes are detected during metadata polling

- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Location**: Line 498 (sync application)
- **Message**: `"[HH:MM:SS] Remote changes successfully applied to local database"`
- **Trigger**: When remote changes are successfully merged into the local database

### ✅ Local Database Change Debug Logging
- **File**: `lib/core/services/database_change_service.dart`
- **Location**: Line 79 (change notification)
- **Message**: `"[HH:MM:SS] Local db change detected - sending to cloud"`
- **Trigger**: When local database changes are detected and scheduled for sync

- **File**: `lib/providers/sync_provider.dart`
- **Location**: Line 184 (sync completion)
- **Message**: `"[HH:MM:SS] Local db change successfully sent to cloud"`
- **Trigger**: When local changes are successfully uploaded to Google Drive

---

## Debug Behavior

### What Gets Logged:
1. **Local Change Detection**: When local database changes are detected and scheduled for cloud sync
2. **Remote Change Detection**: When the metadata polling detects changes in Google Drive
3. **Successful Sync Application**: When remote changes are successfully applied to the local database
4. **Successful Local Upload**: When local changes are successfully uploaded to Google Drive

### What Does NOT Get Logged:
- Normal sync operations without changes
- Network errors or authentication issues (handled silently)
- Metadata polling when no changes are found
- Manual sync operations without underlying changes

---

## Implementation Notes

- Uses standardized `myDebug()` function with timestamps (HH:MM:SS format)
- Debug output can be toggled globally via `isDebug` flag in `main.dart`
- Minimal logging approach - only logs key sync events with precise timing
- No performance impact on normal sync operations
- Provides complete visibility into sync flow in both directions with timing information

---

## Future Debug Guidelines

If adding more debug code:
1. Use the standardized `myDebug()` function from `main.dart`
2. Update this file to document new debug statements
3. Keep debug logging minimal and focused on key events
4. Ensure debug code can be easily removed via automated cleanup

---

*Last Updated: 2025-11-24*  
*Status: Active - Complete sync debug logging enabled (local + remote)*
