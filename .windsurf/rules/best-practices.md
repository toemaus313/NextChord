---
trigger: always_on
---

# NextChord Workspace Rules

## General

- This is a cross-platform Flutter app (Windows, macOS, iOS, Android).
- Local storage uses Drift/SQLite; Google Drive is used for sync.
- Follow idiomatic Flutter/Dart best practices (null-safety, `const` where possible, `final` for immutables).

## UI & Widget Structure

- Prefer many small, focused widgets over large, monolithic widgets.
- If a widget contains multiple logical sections (header, body, footer, sidebar), strongly consider splitting them into child widgets or helper methods.
- Keep `build()` methods and event handlers short and readable; extract `_buildX()` helpers or child widgets when they grow too large.
- Avoid “God widgets” that handle UI, business logic, and data access all in one place.

## Mobile vs Desktop/Tablet

- Maintain a clear separation between mobile and desktop/tablet layouts.
- Do NOT regress the phone layout into a cramped sidebar + content view.
- On mobile, the Global Sidebar header must be:
  - Fixed at the top.
  - Consistent in height, padding, and style across all sidebar pages.
- Do not alter desktop/tablet layout unless explicitly requested.

## State & Data

- Widgets must not directly access Drift or Google Drive.
- All data access and sync logic must go through services/controllers/notifiers.
- Keep business logic out of UI widgets wherever reasonably possible.

## Build & Commands

- Before completing a Cascade workflow that modifies Dart/Flutter code, run appropriate static analysis/compile checks (for example: `flutter analyze` or `dart analyze`) to catch compilation errors and obvious breakages.
- Do **not** run `flutter run` automatically. Respect that I prefer to run the app manually myself.
- It is acceptable to run other `flutter` commands automatically when needed, such as:
  - `flutter pub get`
  - `flutter pub run build_runner ...`
  - `flutter test`
  - `flutter analyze`
  as long as they directly support the change being made.

## Debugging & Temporary Logs

- When adding temporary debug code (for example: `print` / `debugPrint`, logging statements, test buttons, or other debug-only paths), record each one in `debugs_active.md` at the project root.
- In `debugs_active.md`, include at least:
  - The file path (and widget or method name, if useful).
  - A short description of what the debug is for.
- When a debug is no longer needed and is removed, also remove or update the corresponding entry in `debugs_active.md`.
- Treat `debugs_active.md` as the single source of truth to help Cascade quickly locate and clean up all active debugs.

## Project Structure & Organization

- Place new features under `lib/features/` in clearly named folders (e.g., `features/setlists/`, `features/sidebar/`, `features/metronome/`, `features/tuner/`).
- Avoid adding new “misc” or “utils” files at the root without a clear, focused responsibility.
- When adding a new feature, prefer the same layering pattern used elsewhere in the app (e.g., `presentation/`, `application/`, `domain/`, `infrastructure/` inside a feature folder, when applicable).

## Cross-Platform & Platform-Specific Code

- Do not delete, regenerate, or heavily modify platform folders (`ios/`, `macos/`, `android/`, `windows/`, `linux/`) unless explicitly requested.
- When updating CocoaPods, Gradle, or other platform config, preserve any existing customizations and comments rather than overwriting wholesale.
- If a change requires altering platform-specific files (like Podfiles, Xcode project settings, or Android manifests), clearly explain what was changed and why in the Cascade explanation.

## Sync & Data Safety

- Any operation that overwrites the local database with cloud data (or vice versa) must:
  - Be clearly labeled in the UI as destructive or “replace data”.
  - Require explicit user confirmation before proceeding.
- Reuse the existing sync model:
  - Keep using `nextchord_backup.db` as the full backup file in Google Drive.
  - Keep using `library.json` (or equivalent) for metadata/change tracking, and avoid inventing new filenames without a good reason.
- When modifying sync logic, ensure:
  - The app handles “no network”, “no Drive auth”, and “file missing” states gracefully without crashing.
  - User-facing errors are clear and non-technical.

## Performance & Realtime Features (Metronome, Tuner, MIDI)

- For metronome and MIDI tempo functionality, prioritize **timing accuracy** over extra UI animations. Avoid expensive rebuilds or heavy work on the UI thread that might cause stutter.
- For the tuner and stroboscopic visualizations, keep the **audio input and pitch detection code** cleanly separated from the drawing/visual logic.
- Any new visual effects for metronome or tuner must not significantly degrade performance on lower-end devices.

## Experimental / Temporary Code

- If you introduce experimental or “spike” code that is not meant to be permanent:
  - Clearly mark it with a comment including the word `EXPERIMENTAL` or `SPIKE`.
  - Prefer placing it in a clearly named file or section rather than mixing it invisibly into production logic.
- Experimental code should either be:
  - Promoted to a proper, cleaned-up implementation, or
  - Removed once its purpose has been served.
- When removing experimental code, also remove any related entries in `debugs_active.md` or additional notes.
