# NextChord Architecture & Best Practices Guide

## Quick Overview for Beginners

Think of your app as a **3-layer cake**:

```
┌─────────────────────────────────────┐
│    PRESENTATION (Screens & UI)      │  ← What users see
├─────────────────────────────────────┤
│  DOMAIN (Business Logic & Rules)    │  ← The "what" and "why"
├─────────────────────────────────────┤
│   DATA (Database & External APIs)   │  ← The "how" and storage
└─────────────────────────────────────┘
```

Each layer only talks to the layer below it. The bottom layer knows nothing about the top layer.

### Why This Matters

- **Changes don't cascade**: If you redesign the UI, your database code doesn't break.
- **Testing is easier**: Test business logic independent of UI.
- **Reusability**: Core logic can be reused in different UIs (mobile, web, desktop).
- **Collaboration**: Each team member can work on a different layer without conflicts.

---

## Layer Breakdown

### 1. PRESENTATION Layer (`lib/presentation/`)

**What**: Everything the user sees and interacts with.

**Includes**:
- Screens (full-page views)
- Widgets (reusable UI components)
- Providers (state management)

**Rules**:
- Never directly access the database.
- Always go through **repositories** or **providers**.
- Use **Provider** package for state management (not global variables).

**Example**: When user taps "Save Song", the screen calls a provider method, not database code directly.

### 2. DOMAIN Layer (`lib/domain/`)

**What**: Core business logic and rules. Pure Dart—no Flutter, no databases.

**Includes**:
- Entities (pure data objects: Song, Setlist, MidiMapping)
- Use cases (if your app gets complex later)

**Rules**:
- No imports from `flutter` or `dart:io`.
- No database calls.
- No UI code.

**Example**: `transposeSong(Song, int semitones) → Song`. Pure logic, no side effects.

### 3. DATA Layer (`lib/data/`)

**What**: Interaction with databases, file systems, and APIs.

**Includes**:
- Database setup (Drift)
- Models (database representations)
- Repositories (CRUD operations)

**Rules**:
- Maps between **domain entities** and **database models**.
- Repositories abstract storage details away.

**Example**: `SongRepository.insertSong(Song song)` hides "write to SQLite" from the caller.

---

## Design Patterns You're Using

### 1. Repository Pattern

**What**: A repository acts as a "middleman" between your UI and data storage.

**Without Repository** (bad):
```dart
// In your UI code
await database.songs.insert(songData);  // Coupled to database
```

**With Repository** (good):
```dart
// In your UI code
await songRepository.insertSong(song);  // Decoupled, clean
```

**Why**: If you switch from SQLite to a REST API later, you only change the repository, not the UI.

### 2. Provider Pattern

**What**: State management. Providers hold data and notify UI when it changes.

**Example**:
```dart
// Provider holds list of songs and methods to modify it
class SongProvider extends ChangeNotifier {
  List<Song> _songs = [];
  
  void addSong(Song song) {
    _songs.add(song);
    notifyListeners();  // Tell UI: "I changed, redraw me"
  }
}

// In your screen, listen to changes
Consumer<SongProvider>(
  builder: (context, provider, _) {
    return ListView(
      children: provider.songs.map((song) => SongTile(song)).toList(),
    );
  },
)
```

### 3. Dependency Injection (Upcoming)

Later, you'll "inject" dependencies rather than hard-coding them. This makes testing easier. For now, don't worry about it—keep it simple.

---

## Workflow: "How to Add a Feature"

Let's say you want to add a "Favorites" feature to songs.

### Step 1: Update Domain

`lib/domain/entities/song.dart`:
```dart
class Song extends Equatable {
  final bool isFavorite;  // ← Add this field
  // ... rest of fields
}
```

### Step 2: Update Data Layer

`lib/data/database/app_database.dart`:
```dart
// Add column to songs table
@override
final isFavorite = BoolColumn().withDefault(Constant(false));
```

`lib/data/repositories/song_repository.dart`:
```dart
// Add method to toggle favorite
Future<void> toggleFavorite(String songId, bool isFavorite) async {
  // Query and update song in database
}
```

### Step 3: Update Presentation

`lib/presentation/providers/song_provider.dart`:
```dart
void toggleFavorite(String songId) async {
  await repository.toggleFavorite(songId, !currentSong.isFavorite);
  loadAllSongs();  // Refresh list
}
```

`lib/presentation/widgets/song_list_tile.dart`:
```dart
// Add a star icon that calls provider.toggleFavorite()
IconButton(
  icon: Icon(song.isFavorite ? Icons.star : Icons.star_outline),
  onPressed: () => songProvider.toggleFavorite(song.id),
)
```

**See?** Each layer gets a small, focused change. No cascading rewrites.

---

## Best Practices Specific to Your App

### 1. Handle ChordPro Parsing Carefully

The ChordPro text is the "source of truth." Never modify it directly in the viewer. Always create a new version for display:

```dart
// ✅ GOOD: Create new version for display
String displayedText = ChordProParser.transposeChordProText(
  song.body,
  transposeSemitones,
);

// ❌ BAD: Modify the original
song.body = ChordProParser.transposeChordProText(song.body, ...);
song.save();  // Corrupts data
```

### 2. MIDI Messaging is Immediate

MIDI commands should fire without database lookups (too slow on stage):

```dart
// ✅ Load mapping once, reuse
MidiMapping? mapping = await repository.getMidiMapping(songId);
midiService.sendProgramChange(mapping?.programChangeNumber);

// Better: cache during song selection
songProvider.selectedSong = song;
if (song.midiMapping != null) {
  midiService.sendProgramChange(song.midiMapping.pc);
}
```

### 3. Use Immutability (copyWith)

Your entities use `copyWith()` to create modified copies. Respect immutability:

```dart
// ✅ Create a new Song
Song updatedSong = song.copyWith(key: 'D');
await repository.updateSong(updatedSong);

// ❌ Don't modify the original
song.key = 'D';  // This violates immutability
```

### 4. Tag Management

Tags are stored as JSON in the database. Keep the model simple:

```dart
// In Song entity
final List<String> tags;  // e.g., ["acoustic", "worship", "upbeat"]

// When saving to database, convert to JSON string
String tagsJson = jsonEncode(song.tags);

// When loading, parse back
List<String> tags = List<String>.from(jsonDecode(tagsJson));
```

---

## File Naming Conventions

- **Entities**: `song.dart`, `setlist.dart` (singular, no prefix)
- **Models**: `song_model.dart`, `setlist_model.dart` (suffix `_model`)
- **Repositories**: `song_repository.dart` (suffix `_repository`)
- **Screens**: `song_editor_screen.dart`, `library_screen.dart` (suffix `_screen`)
- **Widgets**: `song_list_tile.dart`, `chord_renderer.dart` (describe what they do)
- **Providers**: `song_provider.dart` (suffix `_provider`)
- **Services**: `midi_service.dart`, `audio_service.dart` (suffix `_service`)

---

## Testing Strategy (For Later)

Once your app is working, consider adding tests:

```dart
// test/domain/utils/chordpro_parser_test.dart
void main() {
  test('Transpose C major to D major', () {
    final result = ChordProParser.transposeChordProText('[C][F][G]', 2);
    expect(result, '[D][G][A]');
  });
}

// test/data/repositories/song_repository_test.dart
void main() {
  test('Insert and retrieve song', () async {
    final song = Song(...);
    await repository.insertSong(song);
    final retrieved = await repository.getSongById(song.id);
    expect(retrieved, song);
  });
}
```

---

## Common Mistakes to Avoid

### ❌ Mixing Layers
```dart
// DON'T: Call database from UI directly
class SongViewerScreen extends StatelessWidget {
  onSave() async {
    await db.songs.insert(songData);  // ← Tightly coupled
  }
}
```

### ✅ Proper Separation
```dart
// DO: Use repository
class SongViewerScreen extends StatelessWidget {
  onSave() async {
    await repository.updateSong(song);  // ← Decoupled
  }
}
```

### ❌ Modifying Entities
```dart
// DON'T: Mutate during use
song.body = song.body.replace("[C]", "[D]");
```

### ✅ Create New Version
```dart
// DO: Use copyWith or create new object
Song transposed = song.copyWith(body: newBody);
```

### ❌ Blocking on MIDI/Audio
```dart
// DON'T: Wait for MIDI operations in UI
await midiService.sendProgramChange(123);  // Slow
```

### ✅ Fire and Forget (Usually)
```dart
// DO: Let MIDI operation happen in background
midiService.sendProgramChange(123);  // Returns immediately
```

---

## Quick Reference: Where Things Go

| What | Where |
|------|-------|
| A new screen | `lib/presentation/screens/` |
| A reusable button | `lib/presentation/widgets/` |
| State for a screen | `lib/presentation/providers/` |
| Music theory logic | `lib/core/utils/` |
| A new database table | `lib/data/database/` |
| CRUD for songs | `lib/data/repositories/` |
| Entity definition | `lib/domain/entities/` |
| External API call | `lib/services/` |
| Global app constants | `lib/core/constants/` |

---

## Moving Forward

1. **Next**: Build Phase 1, Task 1.1 (Database setup). Use the WINDSURF_GUIDE.md.
2. **Review**: Skim this document if a task feels confusing.
3. **Iterate**: Each task is small. Build, test, move to next.
4. **Ask**: If something doesn't make sense, ask Windsurf or ChatGPT with this document as context.

You've got a solid foundation. The hard part (figuring out architecture) is done. Now it's execution. 🎸
