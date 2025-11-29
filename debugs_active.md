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

There are **no active debug log sites** registered at this time.

When you add new `main.myDebug(...)` calls for focused troubleshooting, please:

- Add a short entry under this section with:
  - File path
  - Function or logical area
  - Purpose of the debug
- Remove the entry again when the debug is no longer needed (and delete the corresponding code).
