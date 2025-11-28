# NextChord – AI Coding Instructions

- **Architecture:** Strict 3-layer cake:
  - `lib/presentation/` – Flutter UI, widgets, `ChangeNotifier` providers only
  - `lib/domain/` – Pure Dart entities and business rules (no Flutter/DB imports)
  - `lib/data/` – Drift DB, repositories, external APIs
  - `lib/services/` – Integrations (sync, MIDI, audio, import, metadata)
  - **Never** let presentation talk directly to Drift/Google Drive; always go through services/repositories/providers.

- **Repositories & DB:**
  - Repositories live in `lib/data/repositories/` (see `song_repository.dart`, `setlist_repository.dart`).
  - Drift setup in `lib/data/database/app_database.dart` and `.../tables/tables.dart`.
  - User entities usually have `id`, `updatedAt`, `isDeleted` for sync.
  - After schema changes: run `flutter pub run build_runner build`.

- **State management (Provider):**
  - Use `ChangeNotifier` + `notifyListeners()` (see `lib/presentation/providers/*`).
  - Providers depend on repositories/services via constructor injection.
  - UI reads state via `Consumer`/`Selector` widgets, not static singletons.

- **ChordPro & Songs:**
  - Domain models in `lib/domain/entities/song.dart`.
  - ChordPro parsing/transposition via `lib/core/utils/chordpro_parser.dart`.
  - Treat `Song.body` as immutable source; for transposition use helpers, e.g. `ChordProParser.transposeChordProText` when rendering.

- **Sync model (high level):**
  - Drift DB is the runtime source of truth.
  - Sync services under `lib/services/sync/` talk to Google Drive / iCloud.
  - Cloud uses a single logical snapshot file (`library.json`) plus DB backups; don’t invent new sync file formats.

- **Debugging rules (critical):**
  - All logging must go through `main.myDebug("...")`; **never** introduce raw `print`, `debugPrint`, or other loggers.
  - Global toggle lives in `lib/main.dart` (`isDebug` + `myDebug`).
  - Any temporary debug added must be recorded in `debugs_active.md` with file + purpose.
  - When asked to remove debugs, delete only `main.myDebug(...)` lines and run the `flutter analyze` loop until clean (see `docs/debugging_cleanup_enforcement_rule.md`).

- **Commands & workflow:**
  - Safe to run automatically: `flutter analyze`, `flutter test`, `flutter pub get`, `flutter pub run build_runner ...`.
  - **Do not** auto-run `flutter run` – the user starts the app manually.

- **UI conventions:**
  - Keep widgets small and focused; extract sections into helpers or child widgets.
  - Maintain distinct mobile vs desktop/tablet layouts; don’t cram mobile into sidebar-style UIs.
  - Widgets must not reach into Drift/Drive directly; let them talk to controllers/providers.
  - **AppearanceProvider:** new UI that needs app theming or gradients should consume `AppearanceProvider` (see `global_sidebar.dart`, `appearance_settings_modal.dart`, modal templates) rather than hard-coding colors. Use `context.watch<AppearanceProvider>()` or pass it into helpers like `StandardModalTemplate.buildModalContainer` / `ConciseModalTemplate.showConciseModal` and dropdowns.

- **Project organization:**
  - New feature code goes under `lib/features/<feature_name>/` when appropriate, following the same layering.
  - Avoid new root-level “misc/utils” files; prefer placing utilities under `lib/core/` or the relevant feature.

- **Cross‑platform safety:**
  - Don’t delete or regenerate `ios/`, `macos/`, `android/`, `windows/`, `linux/` without explicit instruction.
  - If you must touch platform configs, keep edits minimal and explain them clearly.

- **Key references for deeper context:**
  - `ARCHITECTURE.md` – overall design and rationale.
  - `.windsurf/rules/best-practices.md` – workspace-wide rules.
  - `docs/debugging_cleanup_enforcement_rule.md` – detailed debug cleanup + logging constraints.
  - `debugs_active.md` – current active debugs that must be cleaned up later.

Last updated: 2025‑11‑28.
