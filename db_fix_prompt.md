You are an expert Flutter/Dart + Drift/SQLite engineer working inside my existing app codebase. This app is an offline-first chord/lyrics library for musicians. It currently uses a local SQLite DB and has some initial attempts at syncing via Google Drive (including working authentication).

IMPORTANT CONSTRAINT
====================
I ALREADY HAVE GOOGLE DRIVE AUTHENTICATION AND BASIC INTEGRATION WORKING.

- You MUST preserve the existing Google Drive authentication and authorization setup.
- Do NOT delete, disable, or radically rewrite the Google Drive auth/plumbing that is already functioning.
- You MAY refactor or replace the higher-level “sync logic” that currently uses Drive, but the low-level pieces that:
  - handle OAuth,
  - manage Drive client configuration,
  - and obtain authorized access to the user’s Drive
  must remain and be reused.

In other words: keep the current working Google Drive integration as the way we read/write a file in the user’s Drive. We are only changing how we structure and merge the data we read/write (moving to a JSON-based library sync), not how we authenticate or connect to Google Drive.

YOUR GOAL
=========
Implement a robust, **file-based sync system (Option B)** where:

- Each user has their **own personal library** (songs, setlists, etc.).
- The primary store on each device remains **local SQLite**.
- The library is synced across a user’s devices via a **single JSON file** (e.g., `library.json`) stored in the user’s Google Drive, using the existing Google Drive integration.
- In the future, this design should be flexible enough to support other storage backends (like OS file picker / other providers), but for now the concrete implementation should use Google Drive.
- There is **no central backend** and **no per-user cloud DB setup** beyond Google Drive itself.
- Conflicts between devices are resolved using a **last-write-wins** strategy based on `updatedAt` timestamps and a `deleted` flag (soft delete).

HIGH-LEVEL DESIGN
=================
Implement Option B as follows, **reusing the existing Google Drive auth and Drive client**:

1. **Local DB remains main source of truth**
   - Keep using SQLite/Drift as the authoritative store when the app is running.
   - Every entity that should sync (e.g., `songs`, `setlists`, `setlist_songs` or equivalent) MUST have:
     - a stable `id` (prefer UUID or existing primary key),
     - an `updatedAt` `DateTime` field,
     - a `deleted` boolean flag for soft deletes.
   - If these fields do not exist yet, add them in a migration-safe way.

2. **Sync metadata**
   - Add a small `sync_state` table (or extend an existing settings/state table) that stores:
     - `id` (single row, e.g. always 1),
     - `deviceId` (a locally-generated persistent UUID string for this device),
     - `lastRemoteVersion` (int, default 0),
     - `lastSyncAt` (DateTime?).
   - Generate and persist `deviceId` once on first launch and reuse it.

3. **JSON file format (`library.json`)**
   - Define a single JSON document that represents the entire “library” for a user. Example (adapt to our real schema):
     ```json
     {
       "schemaVersion": 1,
       "libraryVersion": 42,
       "exportedAt": "2025-01-01T12:34:56Z",
       "devices": [
         {
           "deviceId": "some-uuid",
           "lastSyncAt": "2025-01-01T12:34:56Z"
         }
       ],
       "songs": [
         {
           "id": "...",
           "title": "...",
           "artist": "...",
           "body": "...",
           "updatedAt": "2025-01-01T12:34:56Z",
           "deleted": false
         }
       ],
       "setlists": [
         {
           "id": "...",
           "name": "...",
           "updatedAt": "2025-01-01T12:34:56Z",
           "deleted": false
         }
       ],
       "setlistSongs": [
         {
           "id": "...",
           "setlistId": "...",
           "songId": "...",
           "position": 1,
           "updatedAt": "2025-01-01T12:34:56Z",
           "deleted": false
         }
       ]
     }
     ```
   - Derive the JSON schema from my actual SQLite schema. Key requirements:
     - A top-level `schemaVersion`.
     - A top-level `libraryVersion` integer that increments each time we write a merged library.
     - Arrays for each synced entity type.
     - Each record has `id`, `updatedAt`, and `deleted`.

4. **Sync service architecture**
   - Create a dedicated service class, e.g. `LibrarySyncService`, in the appropriate layer.
   - Responsibilities:
     - `Future<void> exportLibraryToJson();`  // export current local DB to a JSON string or bytes
     - `Future<void> importAndMergeLibraryFromJson(String json);`
     - `Future<void> syncWithGoogleDrive();` which:
       - Uses the EXISTING Google Drive-authenticated client to:
         - Locate or create the `library.json` file (e.g., in a specific folder, or wherever current sync code already puts files).
         - Download its contents (if it exists).
         - Upload the new merged JSON back to that same file.
       - Handles all other logic locally (merge, update DB, etc).

   - Internally, split responsibilities:
     - A “transport” layer that reads/writes `library.json` via Google Drive (reusing existing Drive code).
     - A “merge” layer that doesn’t care about Drive and just merges local vs remote JSON.

5. **Reuse existing Google Drive code**
   - Examine current GDrive-related code and identify:
     - How authentication is done.
     - How an authorized Drive client is obtained.
     - How files are currently read/written.
   - Reuse those parts to:
     - Locate or create `library.json` (or adapt current file naming/location).
     - Download the file contents as a string/bytes.
     - Upload updated contents.
   - Do NOT remove or break the auth flow. If necessary, refactor minimally to support the new sync abstraction, but do so without losing functionality.

6. **Merge logic (last-write-wins)**
   - On sync:
     1. **Load local library** from SQLite into in-memory lists/maps per entity type.
     2. **Attempt to load remote JSON** from Google Drive:
        - If `library.json` does not exist yet, treat remote library as empty.
     3. Parse remote JSON (if present) into in-memory structures.
     4. For each entity type:
        - Build maps keyed by `id` for local and remote.
        - Take the union of all IDs.
        - For each `id`:
          - If exists only locally → merged record is local version.
          - If exists only remotely → merged record is remote version.
          - If exists in both → compare `updatedAt`:
            - Newer `updatedAt` wins (including `deleted` flag and fields).
     5. Deletions:
        - Records with `deleted == true` in the winning version should:
          - Be marked deleted in local DB (soft delete) or removed according to the app’s conventions.
     6. Apply merged result to local DB via Drift:
        - Upsert/insert/update active records.
        - Mark/handle deleted records correctly.
     7. Construct merged `library.json` from merged entities:
        - Increment `libraryVersion` (starting from existing remote version if present, otherwise from 1).
        - Set `exportedAt` to current UTC time.
        - Update or append the current `deviceId` in the `devices` list.
     8. Serialize merged JSON and upload via Google Drive to the same `library.json` file.
     9. Update `sync_state` with:
        - `lastRemoteVersion = merged.libraryVersion`
        - `lastSyncAt = DateTime.now().toUtc()`.

   - Ensure that any local modifications (create/update/delete) always update `updatedAt` (and `deleted` for deletes) so that sync works correctly.

7. **Error handling & UX**
   - Handle:
     - Missing Drive file (create new `library.json` from local DB).
     - Corrupted JSON or incompatible `schemaVersion` (show a clear error, don’t overwrite local DB; optionally back up the bad file in Drive).
     - Drive connectivity issues or auth failures (surface friendly errors, but don’t crash).
   - In the UI:
     - Keep or enhance any existing “Sync” UI to call `syncWithGoogleDrive()`.
     - Show last sync time and basic status messages.

8. **Refactor old sync attempts (but KEEP auth)**
   - Find existing code that:
     - Uploads/downloads the raw SQLite `.db` file to/from Google Drive.
     - Or otherwise tries to sync by copying DB files.
   - Replace that logic so that it uses:
     - `LibrarySyncService.syncWithGoogleDrive()` and the JSON-based merge instead.
   - While doing this:
     - Do NOT remove or break the working Drive auth and client setup.
     - Only change how we use Drive (what file we read/write and how we build its contents).

9. **Testing and validation**
   - Add unit tests for merge logic:
     - Local-only changes.
     - Remote-only changes.
     - Conflicting changes with local newer.
     - Conflicting changes with remote newer.
     - Deletes vs updates.
   - Add tests for JSON serialization/deserialization.
   - If feasible, add an integration-style test that:
     - Simulates a remote JSON payload.
     - Simulates local DB data.
     - Runs `importAndMergeLibraryFromJson()` and verifies local DB state.

10. **Code quality and documentation**
    - Keep architecture consistent with the current codebase (layers, repos, services).
    - Use existing patterns/naming where possible.
    - Add doc comments to:
      - `LibrarySyncService`,
      - DTOs/models for the JSON,
      - New DB columns/tables related to sync.
    - Add a short `SYNC_DESIGN.md` or similar summarizing:
      - The file-based Drive-backed sync design.
      - JSON format and versioning.
      - Conflict-resolution rules.
      - How the Google Drive integration is used by the sync service.

WORKFLOW FOR YOU (WINDSURF)
===========================
1. Scan the repo to understand:
   - Current DB schema (Drift tables/entities).
   - Existing Google Drive auth and file I/O code.
   - Existing sync attempts and where they hook into the UI.
2. Propose a concrete plan in brief comments if helpful, then implement the new sync system.
3. Implement the JSON library format and `LibrarySyncService`, reusing the Drive auth/client code to read/write `library.json` in Google Drive.
4. Wire the sync service into existing “Sync” or related UI.
5. Add or update tests for merge behavior and basic Drive sync flows (mocked where necessary).
6. Ensure the Drive auth still works as before, and that users do NOT need to reconfigure any complex backend—only sign in to Google Drive as they do now.

Please now proceed to implement this Option B file-based sync system in my current codebase following these instructions, preserving and reusing the existing Google Drive authentication and integration.
