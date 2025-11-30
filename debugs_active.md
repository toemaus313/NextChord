# Active debug locations

- GoogleDriveSyncService.signIn
  - File: lib/services/sync/google_drive_sync_service.dart
  - Purpose: Log mobile GoogleSignIn flow and exceptions when user taps Sign in

- SyncProvider.signIn
  - File: lib/providers/sync_provider.dart
  - Purpose: Log high-level sign-in attempts and failures for sync backend

- AppDatabase song duration changes
  - File: lib/data/database/app_database.dart
  - Purpose: Log whenever a song's duration is initially set or changed on insert/save/update

- LibrarySyncService song duration changes
  - File: lib/services/sync/library_sync_service.dart
  - Purpose: Log when JSON sync merge changes a song's duration compared to existing local data

