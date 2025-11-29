# NextChord: Online Song Metadata Lookup (SongBPM + MusicBrainz)

You are an expert Flutter/Dart engineer working inside my **NextChord** application repository. You will add an **online song metadata lookup** feature that uses **SongBPM (GetSongBPM API)** plus **MusicBrainz** to retrieve tempo, key, time signature, and duration for a song *after* the user manually enters **Title** and **Artist**.

Your work MUST respect my existing **Rules / Best Practices / Debugging** standards and integrate cleanly with the current codebase and UI.

---

## 0. Global Expectations

Before making any changes:

1. **Locate and read my rules documents.**
   - Search the repo for files like:
     - `RULES.md`
     - `BEST_PRACTICES.md`
     - `DEBUG_RULES.md`
     - `CONTRIBUTING.md`
     - Or any `RULES_*` / `DEBUG_*` files.
   - Carefully read them and follow all guidance, especially regarding:
     - Code organization and modularity.
     - Naming conventions.
     - Logging / debugging practices.
     - Error-handling style.

2. **Respect my Debug Rules.**
   - Use the existing logging / debugging utilities defined in the project.
   - Do **not** introduce noisy `print()` spam or ad‑hoc debug code.
   - If new debug logging is needed, implement it in the minimal, rule-compliant way.

3. **Keep code modular and small.**
   - Prefer **small, focused functions** over large monoliths.
   - Keep UI widgets lean by moving non-UI logic into services/helpers.

4. **Leave the app compiling and clean.**
   - At the end, run the project’s standard static checks:
     - Always run `flutter analyze` and fix **all** resulting errors.
     - If the project has tests (e.g. `flutter test`), run them and fix failures.
   - Do not exit with any new analyzer warnings or TODOs unless explicitly approved by my rules.

---

## 1. High-Level Feature Description

Implement a feature that:

1. **Uses online APIs to look up song metadata**, specifically:
   - **SongBPM / GetSongBPM API** (for BPM, key, time signature, year, etc.).
   - **MusicBrainz API** (for track duration in milliseconds).

2. **When to attempt lookup (very important):**
   - Only attempt online lookup **IF all of the following are true**:
     1. The **Title** and **Artist** fields were **not auto-populated by a parser/importer**.
        - I.e., the user has manually typed them.
     2. The user has **entered both** a non-empty Title **and** Artist.
     3. We have **not already successfully imported online metadata** for this song instance.
   - DO NOT trigger lookup for songs that already had Title/Artist set by an existing parser.
   - DO NOT re-run lookup automatically if:
     - The user changes any field **after** a successful import. At that point, user overrides must be respected.

3. **User experience constraints:**
   - The lookup process must be **non-blocking**:
     - The user must remain free to keep editing metadata and content.
     - The user must be able to save and continue even if lookup fails or is still in progress.
   - The user must be able to **override any imported values**:
     - Once imported, all fields remain fully editable.
     - No background logic should silently overwrite user edits.
   - If lookup fails (network error, no match, etc.), the user is **not blocked** in any way.

4. **UI status message (small text under metadata fields):**
   - Just below the existing metadata fields (Title/Artist/Tempo/Key/etc.), add a **small status line** indicating lookup status, for example:
     - **Idle / no lookup yet:** show nothing or subtle text like “Song info: not fetched”.
     - **While searching:** “Song info: searching online…”
     - **On success:** “Song info: details imported from online sources.”
     - **On no match:** “Song info: no online match found.”
     - **On error:** “Song info: error retrieving data. You can continue editing manually.”
   - Style this status text to be visually subtle but readable, using the existing theme’s “small” / caption style (or the closest equivalent used elsewhere).

---

## 2. Discover the Relevant Code

1. **Find song import and editor flows.**
   - Search for code related to:
     - Song import from sites like Ultimate Guitar.
     - Copy/paste song import.
     - Manual song creation / editing UI.
   - Identify:
     - Data models representing a song and its metadata (e.g. `Song`, `SongMetadata`, etc.).
     - Widgets/screens used to edit songs and metadata (e.g. song editor, metadata form, etc.).
     - Any existing logic that tracks whether Title/Artist were set by a parser vs manually.

2. **Identify metadata fields.**
   - Confirm where these are defined and displayed:
     - **Title** (string)
     - **Artist** (string)
     - **Tempo / BPM**
     - **Key**
     - **Time signature**
     - **Duration**
   - If some of these are not yet represented in the model, add them in a minimal, backwards-compatible way, consistent with existing patterns.

3. **Determine if we track “auto-populated vs manual”.**
   - Look for any fields or flags that distinguish parser-populated metadata from manual entry.
   - If such tracking exists:
     - Reuse it.
   - If it does not exist:
     - Introduce lightweight tracking in the editor state or song model, for example:
       - `bool titleArtistAutoPopulated` or separate flags like:
         - `bool titleFromImport`
         - `bool artistFromImport`
     - Make sure this is done in a minimal, non-breaking way, with sensible defaults for legacy songs.

---

## 3. Design the Metadata Lookup Service

Create a **new service class** to encapsulate online lookups, for example:

- File: `lib/services/song_metadata_service.dart` (or the most appropriate services directory in the existing structure).
- Class name: `SongMetadataService` (or similar; follow existing naming conventions).

### 3.1. Service Responsibilities

The service’s responsibilities:

1. Perform **combined lookups** against:
   - **SongBPM / GetSongBPM API** for:
     - Tempo (BPM)
     - Key (e.g. “Em”)
     - Time signature
     - (Optionally) album year or other fields.
   - **MusicBrainz API** for:
     - Track **duration in milliseconds**.

2. Merge the results to produce a **single metadata object or map** that can be applied to a `Song` or `SongMetadata` model.

3. Provide a **simple async API** for the UI layer, e.g.:

   ```dart
   class SongMetadataLookupResult {
     final double? tempoBpm;
     final String? key;
     final String? timeSignature;
     final int? durationMs;
     // Add any other useful fields (year, etc.) as needed.
   }

   class SongMetadataService {
     Future<SongMetadataLookupResult> fetchMetadata({
       required String title,
       required String artist,
     });
   }
   ```

   - This `fetchMetadata` should:
     - Fire both network requests in parallel.
     - Merge results.
     - Handle errors gracefully and surface enough info for the UI status message.
     - Never throw uncaught exceptions to the UI; return a safe failure result instead.

### 3.2. SongBPM / GetSongBPM client

Implement a small client inside the service or in a dedicated helper file, adhering to best practices in the repo.

- Use the documented GetSongBPM API (often referred to as SongBPM).
- Expected behavior:
  - Search by title + artist:
    - Use a `search` endpoint with `type=both` and a combined query like `song:TITLE artist:ARTIST`, or the closest documented equivalent.
  - Choose the **best matching entry** based on:
    - Highest relevance score if provided.
    - Exact or near-exact case-insensitive match on title and artist where possible.
  - Extract fields:
    - `tempo` (BPM)
    - `key_of` (key)
    - `time_sig` (time signature)
    - Optionally `album.year`
- Read the API key from the **existing configuration or secrets path** used elsewhere.
  - If the repo does not yet have a place for SongBPM API keys:
    - Add a minimal, documented configuration mechanism (e.g., a config file or env var mapping).
    - Do NOT hardcode actual secrets into the repo.
- Respect the project’s HTTP / network abstraction pattern:
  - If there’s a shared HTTP client wrapper, use it.
  - If not, use the standard `http` package in a clean, testable way.

### 3.3. MusicBrainz client (duration)

Implement a simple client for **MusicBrainz**:

- Use the **recording search** endpoint with a query of the form:

  - `recording:"TITLE" AND artist:"ARTIST"`

- Request JSON, and reasonable `limit` (e.g. 5).
- In the response:
  - Select the best matching recording (highest score, matching title/artist).
  - Use the `length` field (duration in milliseconds) as the duration.
- Set a proper, project-appropriate `User-Agent` header (MusicBrainz requires a descriptive User-Agent string).
- Handle rate limiting politely:
  - If the project already has generic rate-limit handling, follow that pattern.
  - Otherwise, implement minimal error handling and backoff so we don’t hammer the service.

### 3.4. Parallel requests and merging

In `fetchMetadata`:

1. Fire both calls in parallel (e.g. using `Future.wait`).
2. Merge their results:
   - Prefer SongBPM for tempo, key, time signature.
   - Use MusicBrainz for duration.
3. Return a `SongMetadataLookupResult` that can represent:
   - Full success (all fields present).
   - Partial success (e.g. only tempo/key were found).
   - Failure (no usable fields; but still a valid object with flags/warnings).

Include enough internal information so the UI layer can show:
- Success vs. partial vs. failure (for the status message).

---

## 4. Integrate with the Song Editor / Metadata UI

### 4.1. Determine where to trigger lookup

In the song editing / creation flow:

1. Identify the state object or controller that manages:
   - The **Title** and **Artist** text fields.
   - The song’s metadata fields (tempo, key, duration, etc.).

2. Add state needed to manage lookup:
   - Flags such as:
     - `bool hasAttemptedOnlineLookup` (per song instance).
     - `bool onlineLookupCompletedSuccessfully`.
     - `bool titleArtistAutoPopulated` (or reuse an existing equivalent).
   - A status enum for the UI, e.g.:

     ```dart
     enum OnlineMetadataStatus {
       idle,
       searching,
       found,
       notFound,
       error,
     }
     ```

   - Store the current status in the editor state.

3. Implement the **trigger rule**:

   - After each relevant change to the Title or Artist fields, check:
     - If `titleArtistAutoPopulated == true`, **do nothing** (no lookup).
     - If either Title or Artist is empty, **do nothing**.
     - If `hasAttemptedOnlineLookup == true`, **do not auto-trigger again**.
     - If we have already successfully imported metadata and the user has edited fields afterwards, **do not auto-trigger again**.
   - When all conditions are satisfied (user manually enters both Title and Artist and we haven’t tried yet):
     - Set status to `OnlineMetadataStatus.searching`.
     - Invoke `SongMetadataService.fetchMetadata(title: ..., artist: ...)` asynchronously.
     - When it completes:
       - Based on the result:
         - If at least one useful field is returned, apply them (see 4.2) and set status to `found`.
         - If no usable fields are returned (e.g. no match), set status to `notFound`.
         - If there is an error (network, etc.), set status to `error`.
       - Set `hasAttemptedOnlineLookup = true`.

   > Important: This must never block the UI thread or prevent the user from editing fields.

### 4.2. Applying imported metadata

When a successful lookup returns metadata:

1. **Apply fields in a user-respecting way:**
   - Only update fields if they are currently:
     - Empty, OR
     - Still at a default/placeholder value that clearly indicates “no value yet”.
   - If the user has already manually entered a value in a field, **do not overwrite that field**.
   - Fields to consider:
     - Tempo/BPM
     - Key
     - Time signature
     - Duration
     - Any others you choose to use (e.g. year).

2. **Mark that we have imported online metadata.**
   - Set a flag, e.g. `onlineLookupCompletedSuccessfully = true`.
   - Subsequent auto-lookup attempts should respect this and **not run again** for the same song instance.

3. **User overrides:**
   - After the metadata is filled, user can freely edit any of these fields.
   - Their manual edits should be considered authoritative.
   - Do not re-issue automatic lookups when fields change after a successful import.

4. (Optional, if consistent with UX patterns): Add a **manual “Refresh from online sources”** button or menu action that:
   - Only runs **when explicitly pressed** by the user.
   - Is disabled/hidden if it conflicts with existing UX rules.
   - Does **not** auto-trigger on every edit.

### 4.3. UI status message

In the metadata UI (under the existing metadata fields):

1. Add a widget that displays a small line of status text based on `OnlineMetadataStatus` and any associated info.

2. Use the smallest appropriate text style (caption/small/subtitle) that matches the app’s design system, for example:

   - `idle` (no lookup yet, or user hasn’t typed both fields):
     - Either render nothing or something subtle like:
       - “Song info: not fetched.”
   - `searching`:
     - “Song info: searching online…”
     - Optionally show a small, unobtrusive progress indicator if consistent with the design.
   - `found`:
     - “Song info: details imported from online sources.”
   - `notFound`:
     - “Song info: no online match found.”
   - `error`:
     - “Song info: error retrieving data. You can continue editing manually.”

3. Ensure this status text:
   - Does **not** interfere with inputs.
   - Is updated reactively whenever the state changes.
   - Respects dark/light theming and contrast rules.

---

## 5. Failure Modes & Non-Blocking Behavior

Carefully ensure that all error conditions are **non-blocking**:

1. **Network failure / server error / timeout:**
   - Catch exceptions in the service layer.
   - Return a result or status that marks the lookup as failed.
   - Update UI status to `error` with the message described above.
   - Do **not** show intrusive dialogs unless this matches existing UX norms; prefer a status-line hint.

2. **No song match found:**
   - Treat this as a normal, non-error case.
   - Status: `notFound`.
   - All fields remain editable.

3. **Partial data (e.g., tempo but no duration):**
   - Apply whatever fields are present.
   - Consider this a “found” state for the purposes of not re-running automatically.
   - Let the user fill in missing fields manually.

4. **User interaction is always allowed:**
   - At no point should the user be prevented from:
     - Editing Title/Artist.
     - Editing tempo, key, duration, or other metadata.
     - Editing the song’s content/lyrics.
     - Saving the song.

5. **No repeated automatic lookups after user override:**
   - If the user changes any metadata after a successful import:
     - Treat their edits as final.
     - Do **not** auto-trigger another lookup for that song instance.

---

## 6. Testing & Verification

1. **Unit and/or widget tests (if test suite exists):**
   - Add tests for:
     - `SongMetadataService.fetchMetadata`:
       - Success (tempo+key+duration).
       - Partial success (only one service returns).
       - Network error / exception.
     - Editor logic for when lookups are triggered:
       - Only when Title and Artist are both non-empty.
       - Not when `titleArtistAutoPopulated` is true.
       - Not after `hasAttemptedOnlineLookup` is true.
     - Applying metadata to fields:
       - Empty fields are populated.
       - User-entered values are not overwritten.
   - Follow the project’s existing testing patterns.

2. **Manual test scenarios (document briefly in comments or a small dev note):**
   - Create a new song by **copy/paste** where Title/Artist are **empty**:
     - Manually type Title and Artist.
     - Confirm lookup runs once and fills in tempo/key/duration.
   - Import a song where Title/Artist are auto-populated by a parser:
     - Confirm that **no** automatic online lookup is triggered.
   - Simulate network failure:
     - Confirm status shows success/failure appropriately and user can continue editing.
   - After successful import:
     - Manually tweak tempo or key.
     - Confirm no further auto-lookups run.

3. **Final cleanup:**
   - Run `flutter analyze` and fix all issues.
   - Run any existing tests (e.g. `flutter test`) and ensure they pass.
   - Make sure no temporary debug code or noisy logs remain.

---

## 7. Style & Code Quality

Throughout this work:

- Use clear, descriptive names following the project’s conventions.
- Avoid large, deeply nested methods — refactor into smaller helpers as needed.
- Prefer immutable data patterns where appropriate.
- Keep all new code documented with concise comments where behavior might not be obvious (especially around the “when to trigger lookup” rules).
- Do not change unrelated logic or UI behavior unless absolutely necessary to support this feature.

Once complete, the app should:

- Allow manual song entry as before.
- **Optionally enrich metadata** automatically once the user enters Title + Artist (when not auto-populated).
- Keep the user fully in control, with a clear, unobtrusive status showing what the online lookup is doing.
