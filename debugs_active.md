# Active Debug Logs - NextChord Codebase

## Status: DEBUG CLEANUP COMPLETED

**Updated**: 2025-11-28  
**Purpose**: Document the global debug helper; all feature-specific debugs have been removed from the codebase.

---

## Global Debug Foundation (Still Available)

- **File**: `lib/main.dart`
- **Function**: `myDebug(String message)`
- **Flag**: `bool isDebug = true`
- **Format**: `[$timestamp] $message` (HH:MM:SS format)
- **Description**: Standardized debug helper with timestamps for consistent logging across the app. This helper remains available for targeted future investigations and should be recorded here when new debugs are introduced.

## Current Active Debug Statements

### Active Debug Locations

1. lib/data/database/migrations/migrations.dart (1-5, 17-24, 27-35, 37-45, 48-56, 58-66, 68-76, 83-91, 93-101, 107-119, 124-136, 141-155, 160-167, 172-207)
2. lib/data/repositories/setlist_repository.dart (7, 181-186)
3. lib/data/repositories/song_repository.dart (9, 299-301, 334-336, 467-468)
4. lib/presentation/providers/setlist_provider.dart (4, 83-96, 100-107, 114-127)
5. lib/providers/sync_provider.dart (12, 136-157, 203-205, 231-237)
6. lib/services/midi/midi_device_manager.dart (6, 283-291)
7. lib/services/midi/midi_service.dart (6, 133-143, 145-156, 158-167, 173-182)
8. lib/services/setlist/setlist_service.dart (7, 136-143)
9. lib/services/sync/icloud_db_backup_service.dart (7, 107-113, 209-214)
10. lib/services/sync/icloud_sync_service.dart (13, 444-450, 468-470, 497-509)
11. lib/services/sync/library_sync_service.dart (7, 636-648)
12. lib/services/sync/windows_icloud_utils.dart (5, 177-207)

When you add new `main.myDebug(...)` calls for focused troubleshooting, please:

- Add a short entry under this section with:
  - File path
  - Function or logical area
  - Purpose of the debug
- Remove the entry again when the debug is no longer needed (and delete the corresponding code).
