# NextChord Database & Sync Operations

This document explains how NextChord manages its local database and how cloud sync works for both Google Drive and iCloud. It focuses on **what** happens conceptually, not implementation details.

---

## 1. Local Database

- The primary data store is a **Drift/SQLite** database in the app sandbox.
- All core entities (songs, setlists, metadata, etc.) live here.
- The UI and services always work against this local database; cloud sync is an overlay on top of it, not a live remote database.

### Key points

- Local DB is always the **source of truth at runtime**.
- Cloud sync periodically pushes/pulls changes to keep other devices in sync.

---

## 2. `library.json` – Logical Library Snapshot

Both Google Drive and iCloud use the same logical artifact:

- **File name:** `library.json`
- **Folder:** `NextChord` (on Drive or in iCloud container)
- **Content:** A JSON export of the current library, produced by `LibrarySyncService`.

`library.json` is **not** just a small incremental signal file; it is a full logical snapshot of:

- Songs and related entities
- Setlists and ordering
- Any other syncable library data

### Why this design?

- Keeps the cloud format backend‑agnostic (Google Drive and iCloud share the same JSON schema).
- Makes merging and conflict resolution simpler; all logic lives in app code.
- Allows the app to reconstruct state from scratch on a new device using a single file.

---

## 3. Incremental Behavior (Without Delta Files)

Even though `library.json` is a full snapshot, sync **behaves incrementally**. This is done through:

1. **Content hash comparison**
   - After exporting `library.json`, the app computes a hash of the JSON content.
   - The last uploaded hash is stored in the local DB (`SyncState`).
   - On the next sync:
     - If the new hash == stored hash → no changes → **no upload**.
     - If the new hash != stored hash → something changed → **upload**.

2. **Remote metadata comparison**
   - For each backend we also store minimal metadata (ID, modified time, checksum, revision ID) in `SyncState`.
   - During metadata polling, we fetch **only remote metadata**, not the full file.
   - If remote metadata indicates the remote file changed since last sync, we trigger a full sync.

3. **Metadata polling loop**
   - Both backends run a 10‑second polling loop when active.
   - Each poll:
     - Fetches metadata for `library.json`.
     - Compares with stored metadata.
     - Only if a change is detected do we proceed to download and merge.

This means there is **no separate incremental/journal file**. The combination of:

- Local content hash, and
- Remote metadata

provides the "incremental" sync behavior.

---

## 4. Google Drive Sync Flow

### Artifact locations

- **Folder name:** `NextChord`
- **File name:** `library.json`

### Sync steps (simplified)

1. **Auth check**
   - Ensure the user is signed in (Google Sign‑In on mobile, OAuth on desktop).

2. **Folder resolution**
   - Find (or create) the `NextChord` folder in Drive.

3. **Download & validate remote file (if any)**
   - Look for `library.json` inside `NextChord`.
   - If found:
     - Download file content.
     - Validate it's well‑formed JSON.
     - Fetch metadata for the file (ID, modifiedTime, md5Checksum, headRevisionId).

4. **Merge into local DB**
   - If remote JSON exists and is valid:
     - Import JSON into the local database via `LibrarySyncService`.
     - Remote changes are applied on top of local data.

5. **Export merged library**
   - Export the **current** local library to JSON (`mergedJson`).

6. **Decide whether to upload**
   - If there is no remote file: always upload.
   - Otherwise:
     - Compare `mergedJson` vs remote JSON (via hash/structural comparison).
     - If unchanged → **skip upload**.
     - If changed → **upload** `mergedJson` to Drive as `library.json`.

7. **Update sync state**
   - Store the hash of the uploaded JSON.
   - Store the latest Drive metadata in `SyncState`.

### Metadata polling

- A background timer periodically calls `getLibraryJsonMetadata()`.
- That method:
  - Fetches only metadata for `library.json`.
  - Compares it to stored metadata.
  - If different, triggers an automatic sync.

---

## 5. iCloud Drive Sync Flow

The iCloud path mirrors the Google Drive behavior but uses a platform channel instead of the Drive API.

### Artifact locations

- **iCloud container folder:** `NextChord` inside the app's iCloud Drive container.
- **File name:** `library.json`.

### Platform channel

- Channel name: `icloud_drive`.
- Native plugins:
  - `ios/Runner/ICloudDrivePlugin.swift`
  - `macos/Runner/ICloudDrivePlugin.swift`

The Dart side calls methods like:

- `isICloudDriveAvailable`
- `getICloudDriveFolderPath`
- `ensureNextChordFolder`
- `uploadFile`
- `downloadFile`
- `getFileMetadata`
- `fileExists`

### Sync steps (simplified)

1. **Auth / availability check**
   - `isSignedIn()` calls `isICloudDriveAvailable` over the channel.
   - If iCloud Drive is not available/enabled at the OS level, sync is blocked.

2. **Folder resolution**
   - `ensureNextChordFolder()` ensures `NextChord` exists in the iCloud container.

3. **Download & validate remote file (if any)**
   - `fileExists('library.json')` checks for the library file.
   - If it exists:
     - `downloadFile('library.json')` copies the file to a temporary local path.
     - App reads the file into a string and validates JSON.
     - `getFileMetadata('library.json')` returns a small map with ID, modified time, checksum, and a simple revision ID.

4. **Merge into local DB**
   - If remote JSON exists and is valid:
     - Import and merge into the local database via `LibrarySyncService`.

5. **Export merged library**
   - Export the current local library to JSON (`mergedJson`).

6. **Decide whether to upload**
   - If there is no remote file: always upload.
   - Otherwise:
     - Compare `mergedJson` vs remote JSON.
     - If unchanged → **skip upload**.
     - If changed → write `mergedJson` to a temp file and call `uploadFile()` to store it as `library.json` in iCloud Drive.

7. **Update sync state**
   - Store hash of uploaded content locally.
   - Mirror `ICloudLibraryMetadata` into the same `DriveLibraryMetadata` structure used for Google Drive and store in `SyncState`.

### Metadata polling

- iCloud uses the same pattern as Google Drive:
  - A timer periodically calls `getLibraryJsonMetadata()`.
  - That checks availability, ensures `NextChord` exists, and then queries `getFileMetadata('library.json')`.
  - If the remote metadata differs from the last stored metadata, automatic sync is triggered.

---

## 6. Local vs Cloud Responsibilities

### Local DB

- Authoritative for **runtime operations**.
- Merging logic (how incoming JSON modifies the DB) lives entirely inside the app.

### Cloud (`library.json` + metadata)

- Stores a **versioned snapshot** of the library.
- Provides enough metadata to detect changes without downloading content every time.
- Does **not** perform any business logic or conflict resolution; all of that is handled by the app using `LibrarySyncService`.

---

## 7. Summary

- The app **does send full `library.json` snapshots** to both Google Drive and iCloud Drive.
- Incremental behavior is achieved by:
  - Comparing local JSON hashes to decide when to **upload**.
  - Comparing remote metadata to decide when to **download & merge**.
- There is no separate incremental/delta file; the intelligence is in the sync services and `LibrarySyncService`, which:
  - Import remote JSON into the local DB when needed.
  - Export and upload a single canonical `library.json` when local changes need to be propagated.
