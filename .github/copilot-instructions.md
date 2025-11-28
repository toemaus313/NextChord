# NextChord AI Development Instructions

## Project Overview

**NextChord** is a cross-platform Flutter music app (iOS, Android, macOS, Windows, Linux) that manages song libraries, creates setlists, and controls MIDI gear. It uses **Clean Architecture** with Drift/SQLite for local storage and bidirectional cloud sync (Google Drive + iCloud).

## Architecture: The Three Layers

All code follows a strict **3-layer cake** pattern:

1. **Presentation** (`lib/presentation/`) — UI screens, widgets, and Provider-based state management
2. **Domain** (`lib/domain/`) — Pure business logic, entities; no Flutter/database imports
3. **Data** (`lib/data/`) — Drift database, repositories, external APIs

**Critical rule:** Layers only reference layers below them. Presentation never directly queries the database.

## Data Layer: Core Patterns

### Repository Pattern
Repositories (`lib/data/repositories/*.dart`) provide CRUD operations and abstract storage details:
- `SongRepository` — Song CRUD, transposition, metadata
- `SetlistRepository` — Setlist CRUD
- Always pass repositories to providers, never raw database access

### Drift Database Schema
- **File:** `lib/data/database/app_database.dart` (main class) and `lib/data/database/tables/tables.dart` (schema)
- **Tables:** Songs, Setlists, MidiMappings, MidiProfiles, PedalMappings, SyncState, DeletionTracking
- **Key pattern:** All user-created entities include `updatedAt` (int, epoch ms), `isDeleted` (soft-delete flag), and `id` (UUID)
- **Auto-generation:** Run `flutter pub run build_runner build` after schema changes
- **Migrations:** Add version bumps in `onUpgrade()` within `lib/data/database/migrations/migrations.dart`

### Sync Architecture
- **Local DB is always the source of truth** at runtime
- **Sync metadata:** `SyncState` table tracks `deviceId`, `lastRemoteVersion`, `lastSyncAt`
- **Cloud storage:** Single `library.json` (full logical snapshot) on Google Drive and iCloud; content hash determines if upload needed
- **Metadata polling:** 10-second loop compares remote metadata; only downloads if changed
- **Services:** `GoogleDriveSyncService`, `ICloudSyncService`, `LibrarySyncService` in `lib/services/sync/`

## Provider State Management

Use `Provider` package (not GetX or Riverpod). Pattern:

```dart
class SongProvider extends ChangeNotifier {
  final SongRepository _repository;
  List<Song> _songs = [];
  
  List<Song> get songs => _songs;
  
  Future<void> loadSongs() async {
    _songs = await _repository.getAllSongs();
    notifyListeners();
  }
}
```

- Always use `ChangeNotifier` + `notifyListeners()` for state changes
- Never store async futures directly; load data in methods called from UI
- Use `Consumer<ProviderType>` in build methods, not direct access

## Domain Layer: Entities & Business Logic

**File:** `lib/domain/entities/song.dart` contains core models:
- `Song` — ChordPro body is the "source of truth"; never modify in-place
- `Setlist` — Ordered collection of songs
- `MidiMapping` — MIDI program changes + control changes
- All inherit `Equatable` for value comparison

**ChordPro handling:** Always create a new transposed version; never mutate the stored body:
```dart
String displayed = ChordProParser.transposeChordProText(song.body, semitones);
```

## Development Workflow

### Adding a Feature (Example: Favorites)

1. **Domain:** Add `isFavorite` field to `Song` in `lib/domain/entities/song.dart`
2. **Data:** Add column to songs table in `lib/data/database/tables/tables.dart`, bump schema version
3. **Repository:** Add `toggleFavorite()` method to `SongRepository`
4. **Presentation:** Add toggle method to `SongProvider`, call from UI widget
5. **Build:** Run `flutter analyze`, then `flutter pub run build_runner build`

### Commands
- `flutter analyze` — Must pass before committing (run automatically after changes)
- `flutter pub get` — Update dependencies (safe to run automatically)
- `flutter pub run build_runner build` — Regenerate Drift models (run after schema edits)
- `flutter run` — **User must initiate manually** (see `.windsurf/rules/flutter-run.md`)

## Debug & Logging

- **Single debug system:** Use `main.myDebug("message")` exclusively; never `print()` or `debugPrint()`
- **Global toggle:** `bool isDebug = true;` at top of `main.dart`
- **Tracking:** All temporary debug code must be recorded in `debugs_active.md` with file path, method, and purpose
- **Cleanup:** When removing debug code, also remove the `debugs_active.md` entry and re-run `flutter analyze`

## Cross-Platform & Platform-Specific

- Do not delete or wholesale regenerate platform folders (`ios/`, `macos/`, `android/`, `windows/`, `linux/`)
- Preserve existing customizations when updating CocoaPods, Gradle, or Xcode project settings
- Document platform-specific changes clearly in commit messages

## Conventions & Organization

- **Features:** Place new features in `lib/features/` with folder structure (e.g., `features/setlists/`, `features/tuner/`)
- **Widget size:** Prefer many small, focused widgets; extract helpers or child widgets when `build()` grows large
- **Mobile vs desktop:** Maintain clear separation; don't regress mobile to cramped sidebar layouts
- **Experimental code:** Mark with `// EXPERIMENTAL` or `// SPIKE` comment; either promote to production or remove completely

## Const & Null Safety

- Use `const` for compile-time constants and immutable widget constructors
- Use `final` for fields that don't change after initialization
- Always enable null-safety; use `?` and `!` intentionally, never suppress without explanation

## Testing & Validation

- Domain entities have no dependencies; unit-test them in isolation
- Mock repositories for provider testing
- After modifying Dart/Flutter code, always run `flutter analyze` to catch errors before committing

## Key Files to Reference

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | Deep dive into patterns, design decisions, workflow |
| `lib/data/database/app_database.dart` | Drift database definition & migrations |
| `lib/data/repositories/song_repository.dart` | Example repository pattern |
| `lib/presentation/providers/song_provider.dart` | Example Provider state management |
| `lib/core/utils/chordpro_parser.dart` | ChordPro parsing & transposition logic |
| `docs/db_operations.md` | Detailed sync architecture & cloud flow |
| `.windsurf/rules/best-practices.md` | Cross-platform, sync safety, performance rules |
| `debugs_active.md` | Inventory of active debug code |

## Quick References

- **Schema version:** Currently v13 in `app_database.dart`
- **Provider package version:** `^6.0.0`
- **Drift version:** `^2.16.0`
- **Flutter SDK:** `>=3.0.0 <4.0.0`
- **Main entry:** `lib/main.dart` initializes DB, providers, and error handlers

---

**Last Updated:** November 28, 2025  
For questions about specific patterns or architecture decisions, refer to `ARCHITECTURE.md` and the detailed guides in `docs/`.
