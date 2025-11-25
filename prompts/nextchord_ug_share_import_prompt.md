# Prompt for Windsurf – Ultimate Guitar Share Import & Tab Parser

You are an expert Flutter/Dart engineer and a strong native iOS/Android developer working in my **NextChord** app. You are running in **Cascade** and must follow my previously defined **Best Practices** and **Debugging Rules** at all times (small, modular changes; safe refactors only; thoughtful commits; minimal, purposeful debugging that is cleaned up at the end; don’t spam logs; and don’t run the app automatically unless I explicitly ask).

I want you to implement **end‑to‑end support for importing songs shared from the Ultimate Guitar (UG) app**, on both iOS and Android, including a new “UG tab” import path that wraps tab blocks in `{sot}` / `{eot}` tags while preserving the original formatting.

---

## High‑Level Goals

1. **Share integration (iOS + Android)**  
   - Make NextChord appear as a valid **Share target**:
     - iOS: in the standard **Share sheet** (Share Extension / equivalent).
     - Android: in the standard **Share → App chooser**.
   - When the user shares a UG chart to NextChord, the app should:
     - Receive the data (text and/or URL).
     - Detect whether the share is a **UG tab** vs **chord‑over‑lyric**.
     - Route to the correct importer.

2. **Chord‑over‑lyric imports (re‑use existing logic)**  
   - For “normal” UG chord charts that are chord‑over‑lyric text, call our **existing chord parser**, preserving all current behavior.

3. **New Ultimate Guitar tab parser**  
   - Implement a new **UG tab parser** that:
     - Preserves the original **ASCII tab formatting** from the UG export.
     - Detects **tab blocks** and wraps them in `{sot}` / `{eot}` tags.
     - Detects **lyrics-only or prose blocks** and intentionally does **not** wrap those in `{sot}` / `{eot}`.
     - If tab sections appear, then lyrics, then more tab, all later tab blocks must also be detected and wrapped.

4. **Automatic routing to the correct parser**  
   - Detect that an incoming share is an **Ultimate Guitar TAB** and call the new tab parser.
   - Detect that the content is a **chord‑over‑lyric chart** and call the existing chord parser instead.

5. **Respect existing architecture and rules**  
   - Keep code **modular and small**.
   - Reuse and extend our **existing parsing logic** (including existing tab‑block detection) wherever possible instead of duplicating it.
   - Add or update tests where appropriate.

---

## Constraints & Best Practices (Important)

When doing all of this, you must:

- **Follow my “Best Practices” and “Debugging Rules” for Cascade**, including but not limited to:
  - Prefer **small, focused changes** over massive refactors.
  - Keep concerns separated (e.g., share handling vs. parsing vs. UI).
  - If you add debugging, use our existing debug helper(s) (e.g. `debugLog` if present) and **remove transient debug logs** before finishing.
  - Use `flutter analyze` and existing tests to ensure you don’t leave the project in a broken state.
  - Don’t run `flutter run` automatically unless absolutely necessary and clearly explained in your Cascade reasoning.
- Do **not** break existing behavior for non‑UG imports. Everything that works today must still work after these changes.

If you need to refactor existing modules, do it incrementally and explain your reasoning in Cascade as you go.

---

## Part 1 – Cross‑Platform Share Intake

### 1.1. Repo reconnaissance

1. Search the repo for any **existing share / intent / extension** related code, such as:
   - Packages like `receive_sharing_intent`, `share_handler`, or any custom platform channels.
   - iOS targets for **Share Extensions** or custom URL schemes.
   - Android `intent-filter`s for `ACTION_SEND` or `ACTION_SEND_MULTIPLE`.
2. Summarize what’s already in place and decide whether to:
   - Extend existing share handling, or
   - Add a new, consistent cross‑platform mechanism.

### 1.2. Unified Dart entry point

Create or reuse a **single Dart entry point** for incoming share data, something like:

```dart
Future<void> handleSharedContent(SharedImportPayload payload);
```

Where `SharedImportPayload` is a small model you define that can represent:

- Plain text
- A URL
- Both URL + text
- (If needed later: file attachments)

Design it so it’s easy to extend in the future.

Make sure you wire this up so that when the app is launched or resumed from a share action on either platform, we eventually call `handleSharedContent(...)` on the Dart side.

### 1.3. iOS – Add NextChord to the Share sheet

On iOS, implement or complete support so that **NextChord appears as a share target** when sharing from Ultimate Guitar:

- Prefer **reusing any existing Share Extension** if we already have one; otherwise:
  - Add a Share Extension target to the iOS project.
  - Configure it to accept **text** (and later, optionally, other types).
  - In the extension’s Swift code, extract the relevant data:
    - Text content
    - URLs (e.g., UG URLs) if present.
  - Marshal this into a small JSON or shared structure and pass it to the main app:
    - Either through a plugin (`receive_sharing_intent` / `share_handler`) that we already use, or
    - A custom URL scheme + shared storage (if that’s our current pattern).
- Make sure the user flow is smooth:
  - From UG, Share → select NextChord → NextChord opens to an import UI.

### 1.4. Android – Share intent integration

On Android:

- Add or update an `intent-filter` for our main activity so NextChord can receive `ACTION_SEND` with `text/plain` (and `ACTION_SEND_MULTIPLE` if needed later).
- Either:
  - Integrate with an existing share-handling plugin (if we already use one), or
  - Add platform channel wiring that converts the incoming `Intent` data into our `SharedImportPayload` model and calls `handleSharedContent(...)`.

Ensure this behavior does **not** conflict with our normal launch flow.

---

## Part 2 – Routing to the Correct Parser (Chord vs Tab)

### 2.1. Detection of Ultimate Guitar source

In `handleSharedContent(...)`, implement robust detection that this is a **UG import**, and further, whether it is a **tab** vs **chord‑over‑lyric**:

1. **Detect UG origin**  
   - Look for a URL or text snippet containing `ultimate-guitar.com`.
   - If the content does not appear to be from UG, fall back to existing generic import behavior and **do not** alter current non‑UG flows.

2. **Detect UG TAB vs other UG content**  
   - UG **tab pages** have URLs matching a pattern like:
     - `*ultimate-guitar.com/tab*`
   - Use this pattern to decide if this is a **TAB import**:
     - If any URL in the shared content matches `*/tab*` under the `ultimate-guitar.com` domain, treat this as a **UG tab import**.
   - If the URL indicates a different type of UG page (e.g., chords, etc.), or if the text appears to be simple chord‑over‑lyric content, treat it as a **chord‑over‑lyric** import and use the existing parser.

3. **Fallback on content heuristics when URL is missing**  
   - If the share somehow has no URL but the text clearly looks like ASCII tab (many lines with e.g. `e|`, `B|`, `G|` prefixes, lots of `-` and digits, etc.), treat it as tab content and call the tab parser as a best effort.

### 2.2. Clear routing API

Create a small orchestrator function, e.g.:

```dart
Future<void> importFromSharedContent(SharedImportPayload payload) async {
  // 1) Identify UG vs non-UG
  // 2) For UG, decide tab vs chord-over-lyric
  // 3) Call the appropriate importer
}
```

This should live in a module that is **pure Dart** (no platform-specific code) and is easy to test.

---

## Part 3 – Reuse Existing Chord Parser for UG Chord‑Over‑Lyric

1. Locate our existing **chord‑over‑lyric parser** (whatever module is responsible for taking text and converting into our internal Song representation).
   - It may be used for other imports (e.g. from the clipboard or files). Reuse that.
2. Do **not** change its behavior in a breaking way.
3. Add a small, UG‑specific adapter function, something like:

```dart
Future<Song> importUltimateGuitarChordSong(String rawText, {Uri? sourceUrl});
```

Responsibilities:

- Strip or normalize any UG‑specific headers/footers we don’t want to store.
- Pass the core song body to the existing parser.
- Attach metadata (source URL, “Imported from Ultimate Guitar”, etc.) if our model supports that.

4. Make sure `importFromSharedContent(...)` calls this function when we detect a UG chord chart (non‑tab).

---

## Part 4 – New Ultimate Guitar Tab Parser

The key requirement: **preserve the original ASCII tab formatting** while wrapping tab blocks in `{sot}` and `{eot}` tags, and not wrapping pure lyric blocks, even if they occur in between tab sections.

### 4.1. Reuse existing tab‑block detection

We already have some functionality that detects tab blocks and automatically wraps them. Before writing new logic:

1. Search the codebase for:
   - Functions / classes related to tab detection and `{sot}` / `{eot}` insertion.
   - Any code that deals with ASCII tabs or GuitarPro/ChordPro imports.
2. Refactor this existing logic (if necessary) into a **reusable helper module** so that both:
   - Our existing import paths, and
   - The new UG tab parser
   can share it.

Avoid duplicating logic; prefer extracting a shared utility and updating call sites.

### 4.2. Define tab vs lyric heuristics for UG exports

UG “non‑official” text exports often mix:

- Preface information (Band, Song, tuning, etc.)
- **ASCII tab blocks**, e.g. lines like:

  ```
  e|----------|------------|----------------|
  B|----------|------------|----------3--3--|
  G|----------|------------|----------------|
  ```

- Lyric or prose sections, including section labels like `[Verse 1]`, `[Chorus]`, and sometimes lines of pure lyrics.
- Commentary blocks at the end explaining symbols (x, h, p, b, /, \, etc.).

Design heuristics that:

- Consider a **line to be a TAB line** if it shows typical tab patterns, such as:
  - Starts with a string indicator like `e|`, `B|`, `G|`, `D|`, `A|`, `E|` followed by `-`, `|`, digits.
  - Or for more general tabs, heavily composed of `-|` and digits across multiple consecutive lines.
- Consider a **TAB block** to be a **contiguous group of TAB lines**, possibly multiple staves stacked (e.g., 6 lines for each string, repeated).
- Treat standalone textual lines (no strong tab patterns) as **lyrics or metadata**, not tab.

### 4.3. Implementation outline

Create a new function/module, for example:

```dart
String convertUltimateGuitarTabExportToChordPro(String rawText);
```

Responsibilities:

1. Split `rawText` into lines.
2. Scan through lines, using a **state machine** to track whether we are currently inside a tab block or not:
   - When entering a tab block (first line that satisfies tab heuristics after a non-tab region):
     - Emit `{sot}` on a separate line before the first tab line.
   - While in a tab block, keep appending lines **unchanged**.
   - When leaving a tab block (the next line that does **not** satisfy tab heuristics):
     - Emit `{eot}` on a separate line after the last tab line.
   - Allow **multiple tab blocks** per file; each gets its own `{sot}`/`{eot}` pair.
3. Lyrics/non-tab lines should pass through **unchanged**, with no `{sot}` / `{eot}` around them.
4. Ensure that if the file ends while inside a tab block, you still emit a final `{eot}`.

### 4.4. Edge cases & “best effort” handling

- Sometimes UG exports will have **mixed content** like timing notation or other grids that look somewhat tab-like. Handle this in a **best-effort** fashion:
  - Prefer wrapping anything that *strongly looks like tab* rather than risking losing a tab section.
- Preserve **blank lines** and **spacing** exactly as received to maintain readability.
- Ensure we **do not wrap purely lyric or comment blocks**, even if they contain a few `-` characters or digits.

### 4.5. Integration with the existing parser

The result of `convertUltimateGuitarTabExportToChordPro` should be a string that complies with our existing `{sot}`/`{eot}` contract and can then be handed off to our **existing “ChordPro-ish” / song text importer**, for example:

```dart
Future<Song> importUltimateGuitarTabSong(String rawText, {Uri? sourceUrl}) async {
  final chordProText = convertUltimateGuitarTabExportToChordPro(rawText);
  return importChordProLikeSong(chordProText, sourceUrl: sourceUrl);
}
```

(Adjust function names to match what we actually have in the codebase.)

Ensure this integration does **not** regress any existing import functionality.

---

## Part 5 – Wiring It All Together

Update the shared import flow so that:

1. `handleSharedContent(...)` → `importFromSharedContent(...)` identifies the content as:
   - Non‑UG → use existing generic flow.
   - UG chord chart → `importUltimateGuitarChordSong(...)`.
   - UG tab text → `importUltimateGuitarTabSong(...)`.

2. After import, present the appropriate NextChord UI (e.g., open the newly imported song in the viewer or navigate to a confirmation/import screen), consistent with how other imports work today.

Make sure there is a **single, well-defined place** in the Flutter code where the choice of importer is made, so we can adjust heuristics later without touching platform-specific code.

---

## Part 6 – Testing & Validation

1. **Unit tests**  
   - Add tests for:
     - `convertUltimateGuitarTabExportToChordPro` with multiple different mixed inputs:
       - Pure tab
       - Tab + lyrics + more tab
       - Tab + headers/footers
       - Content with no tab.
     - Routing logic in `importFromSharedContent(...)`:
       - UG `/tab` URL + tab text → calls tab importer.
       - UG non-tab URL + chord-over-lyric text → calls chord importer.
       - Non‑UG content → uses existing generic path.
   - Prefer to keep tests small and focused; follow our existing test structure and conventions.

2. **Manual test plan (documented briefly in comments or a separate note)**  
   - On iOS:
     - From the UG app, share a non‑official tab page to NextChord and confirm:
       - NextChord appears in the Share sheet.
       - The tab is imported with `{sot}`/`{eot}` around tab blocks.
     - From UG, share a chord‑over‑lyric chart and confirm the chord parser is used.
   - On Android:
     - Perform the same tests using the system Share mechanism and confirm identical behavior.

3. **lint / analyze / format**  
   - Run `flutter analyze` and fix issues introduced by your changes.
   - Run any existing tests.
   - Ensure new code follows the project’s style and organization patterns.

---

## Part 7 – Debugging & Clean‑Up (Cascade Rules)

Throughout this work in Cascade:

- If you add temporary logging, prefer a central, controllable mechanism (`debugLog`, etc.), and **remove or minimize logs** once the feature is stable.
- Keep diffs reviewable:
  - Group related changes in logical commits.
  - Avoid mixing large refactors with functional changes.
- Make sure the project ends in a **clean, compiling state**, with all tests and `flutter analyze` passing.

When you’re done, summarize in Cascade:

- What modules were changed/added.
- How the UG tab detection heuristics work.
- How to maintain or extend this feature (for example, adjusting URL patterns or tab detection rules in the future).
