# NextChord Project Setup - What's Been Created

## Project Foundation ✅

Your NextChord Flutter project is now set up with a professional, scalable architecture. Here's what exists:

### Root Files
- **pubspec.yaml** — All dependencies (Provider, Drift, MIDI, Audio, etc.)
- **.gitignore** — Proper Git setup (ignores build files, generated code, etc.)
- **README.md** — Project overview and folder structure explanation
- **WINDSURF_GUIDE.md** — Step-by-step tasks with Windsurf prompts (your next steps!)
- **ARCHITECTURE.md** — Deep dive into design patterns and best practices

### Folder Structure (`lib/`)

#### `/core`
- **`constants/music_constants.dart`** — Chromatic scale, music theory utilities
- **`utils/chordpro_parser.dart`** — Parse, transpose, and manipulate ChordPro format

#### `/domain`
- **`entities/song.dart`** — Core domain models:
  - `Song` (title, artist, ChordPro body, key, capo, tags, etc.)
  - `Setlist` (collection of songs)
  - `MidiMapping` (MIDI program changes and control changes)
  - Helper classes for setlist items and MIDI CCs

#### `/data`
- Empty folders ready for Phase 1:
  - `database/` — Will contain Drift database setup
  - `models/` — Will contain database models (auto-generated)
  - `repositories/` — Will contain SongRepository, SetlistRepository, etc.

#### `/presentation`
- **`screens/home_screen.dart`** — Main navigation screen (Library, Setlists, Settings)
- Empty folders for:
  - `screens/` — For library, editor, viewer, settings screens
  - `widgets/` — For reusable UI components
  - `providers/` — For state management (Provider package)

#### `/services`
- Empty folders ready for:
  - `midi/` — MIDI service for hardware integration
  - `audio/` — Audio playback service

#### `/main.dart`
- App entry point with Material 3 theme setup

---

## What's NOT Here Yet (Phase 1+)

These will be built as you work through WINDSURF_GUIDE.md:

### Phase 1: Core Database & Library UI
- [ ] Drift database setup (`app_database.dart`)
- [ ] Song repository (`song_repository.dart`)
- [ ] Library screen with search/filter
- [ ] Song editor screen
- [ ] Song viewer screen
- [ ] State management providers

### Phase 2: ChordPro & Transpose
- [ ] Enhanced ChordPro parser (sections, metadata)
- [ ] Transpose controls in viewer
- [ ] Capo adjustment

### Phase 3: MIDI
- [ ] MIDI service initialization
- [ ] MIDI settings screen
- [ ] MIDI mapping for songs
- [ ] Send PC/CC from viewer

### Phase 4: Audio & Polish
- [ ] Audio playback service
- [ ] Backing track support
- [ ] Setlist management
- [ ] Quality of life features (auto-scroll, stage mode, etc.)

---

## Key Design Decisions

### 1. **Clean Architecture**
- Domain logic (Entities) is completely independent of Flutter/databases
- Data layer (Database, Repositories) abstracts storage
- Presentation layer (UI) depends only on repositories, not database directly

### 2. **State Management: Provider**
- Simple, lightweight, well-supported
- Great for beginners while remaining powerful
- Not bloated compared to other state managers

### 3. **Database: Drift ORM**
- Type-safe SQL queries
- Auto-generates code (less boilerplate than raw SQL)
- Works well with Flutter for mobile + desktop

### 4. **MIDI: flutter_midi_command**
- Cross-platform (iOS, Android, macOS, Windows, Linux)
- Handles complex platform differences behind one API
- Perfect for "send CC/PC" use case

### 5. **Audio: just_audio**
- Simple, reliable audio playback
- Works for backing tracks and click tracks
- Community-maintained

---

## Next Steps (In Order)

1. **Read WINDSURF_GUIDE.md** — This is your roadmap for the next phase

2. **Open NextChord in your editor** (VS Code or Android Studio)

3. **Run initial commands**:
   ```bash
   cd /Users/tommy/Library/Mobile\ Documents/com~apple~CloudDocs/Dev/NextChord
   flutter pub get
   ```
   This installs all dependencies.

4. **Start Phase 1, Task 1.1**: Use the Windsurf prompt for setting up the Drift database

5. **Build incrementally**: Each task is designed to be completable in 30-60 minutes with AI help

---

## File Organization Philosophy

You asked about best practices for a project of this magnitude. Here's what we've done:

### Problem: "Where do I put this code?"
**Solution**: Layered architecture + clear folder structure

- **By Layer**: First, ask "Is this UI, business logic, or storage?" That determines top-level folder.
- **By Feature**: Then, within each layer, group related code.
- **By Concern**: Keep unrelated things separate (MIDI ≠ Audio ≠ Database).

### Benefits:
- **Scalability**: As you add features, the structure stays clean
- **Clarity**: New developers (or you in 6 months) can find things quickly
- **Testability**: Each layer can be tested independently
- **Flexibility**: Swap out implementations without rewriting everything

### As You Grow:
- If you add 100 songs? Database scales, UI stays responsive.
- If you add 50 screens? Each screen folder is self-contained.
- If you switch audio library? Change one service, rest of app works.

---

## Technology Stack Summary

| Need | Solution | Why |
|------|----------|-----|
| UI | Flutter + Material 3 | Cross-platform, beautiful |
| State | Provider | Simple, battle-tested |
| Database | Drift + SQLite | Type-safe, scalable, portable |
| ChordPro | Custom parser in Dart | Flexible, embedded |
| MIDI | flutter_midi_command | Cross-platform hardware access |
| Audio | just_audio | Reliable, simple API |

---

## Questions to Ask Yourself

As you build Phase 1, think about:

1. **"How do I load all songs without blocking the UI?"** 
   → Use async/await and Future builders in Presentation layer

2. **"How do I search songs efficiently?"**
   → Query the database, don't filter in memory

3. **"How do I handle song edits—should I update the database immediately?"**
   → Let user click "Save", then update. Don't auto-save during typing.

4. **"Where should I validate form input—presentation or domain?"**
   → Presentation (UI validation), but also consider domain rules (e.g., BPM must be > 0)

5. **"Should I cache songs in memory?"**
   → Keep it simple initially—load from database each time. Cache later if it's slow.

---

## Troubleshooting

### "I don't understand why we're splitting domain/data/presentation"
→ Read the first section of ARCHITECTURE.md. The "3-layer cake" analogy helps.

### "How do I know what goes in which file?"
→ Use the "Quick Reference" table in ARCHITECTURE.md.

### "My Windsurf prompt isn't working"
→ Make sure you've described your context clearly (what files exist, what you're trying to do).

### "Should I use Riverpod instead of Provider?"
→ Stick with Provider for now. It's simpler and does everything you need.

### "Can I skip Phase 1 and jump to MIDI?"
→ No. Build the foundation first. MIDI is fun but won't work without a database and UI.

---

## You're Ready!

Your project is ready for development. The hard architectural decisions have been made. Now it's about building features one task at a time.

**Next action**: Open WINDSURF_GUIDE.md and start Phase 1, Task 1.1. 🎸

Good luck!
