# NextChord

A cross-platform chord book and MIDI controller app for musicians. Manage your song library, create setlists, and control your gear via MIDI.

****SPECIAL ACKNOWLEDGEMENT! Music metadata VERY graciously provided by http://getsongbpm.com and musicbrainz.org. Thank you very much for enabling an important piece of this project!****


## Project Architecture Overview

NextChord follows **Clean Architecture** principles with clear separation of concerns. This makes it easier to test, maintain, and scale.

### Folder Structure Explained

```
lib/
├── main.dart                 # App entry point
│
├── core/                     # Core utilities, constants, and helpers
│   ├── constants/            # App-wide constants
│   │   └── music_constants.dart    # Music theory (chromatic scale, transposition)
│   └── utils/                # Utility functions
│       └── chordpro_parser.dart    # ChordPro format parsing/transpositon
│
├── data/                     # Data layer - interacts with DB, file system, APIs
│   ├── database/             # Database setup and migrations
│   │   └── app_database.dart       # Drift database definition (to create)
│   ├── models/               # Data models (database representations)
│   │   └── song_model.dart         # Database model for Song (to create)
│   └── repositories/         # Repository pattern - abstracts data sources
│       └── song_repository.dart    # CRUD operations for songs (to create)
│
├── domain/                   # Domain layer - business logic and entities
│   └── entities/
│       └── song.dart         # Core Song, Setlist, MidiMapping entities
│
├── presentation/             # UI layer - screens and widgets
│   ├── screens/              # Full-screen views
│   │   └── home_screen.dart        # Main app navigation
│   ├── widgets/              # Reusable UI components
│   │   └── (song_card.dart, etc.) # To create in Phase 1
│   └── providers/            # State management (Provider package)
│       └── (song_provider.dart, etc.) # To create in Phase 1
│
├── services/                 # External service integrations
│   ├── midi/                 # MIDI service
│   │   └── midi_service.dart       # Handles MIDI I/O (to create)
│   └── audio/                # Audio playback service
│       └── audio_service.dart      # Handles audio playback (to create)
│
└── assets/                   # Images, fonts, etc.
    └── chord_diagrams/       # Chord diagram SVGs (future)
```

## Why This Structure?

### 1. **Clean Architecture Layers**

- **Domain** (`lib/domain/`): Pure business logic, no dependencies on Flutter or external packages. If you ever ported to another platform (web, desktop), the domain stays the same.

- **Data** (`lib/data/`): Handles database, file I/O, and API calls. Abstracts details away from the rest of the app.

- **Presentation** (`lib/presentation/`): UI only. Depends on domain/data but not vice versa. Easy to redesign UI without breaking logic.

- **Services** (`lib/services/`): Specialized integrations (MIDI, audio). Kept separate for clarity.

- **Core** (`lib/core/`): Shared utilities and constants used across layers.

### 2. **Scalability**

As your app grows (more features, more screens), you won't have a giant `widgets/` or `models/` folder. Each feature stays organized.

### 3. **Testability**

Separation makes unit testing much easier. Test domain logic independent of UI, mock repositories, etc.

### 4. **Team Friendliness**

If you ever collaborate or inherit this code, the structure is clear and follows Flutter conventions.

## Technology Stack

### Core Dependencies

- **Provider** (`provider`): Simple, lightweight state management. Great for beginners.
- **Drift** (`drift`): SQLite ORM for Dart. Much nicer than raw SQL.
- **flutter_midi_command**: Cross-platform MIDI I/O.
- **just_audio**: Audio playback (backing tracks, metronome, etc.).

### Why These?

- They're mature, well-documented, and widely used in the Flutter community.
- You can feed individual tasks to Windsurf or ChatGPT, and these are well-supported by AI.
- They reduce boilerplate while keeping you in control.

## Development Phases

### Phase 1: Core Library & Basic UI (Weeks 1–2)

- Set up Drift database with Song/Setlist schema.
- Build Library screen (list songs, search, filter).
- Build Song Editor (text area for ChordPro, metadata fields).
- Build Song Viewer (render ChordPro, font size control).
- No MIDI or audio yet — just a functional songbook.

### Phase 2: ChordPro & Transpose (Week 2–3)

- Enhance ChordPro parsing (handle sections, comments).
- Implement transpose logic (apply to displayed chords).
- Add Capo UI control.

### Phase 3: MIDI Integration (Week 3–4)

- Initialize MIDI service.
- Build MIDI device picker screen.
- Link song selection → send Program Change.
- Optional: map CC messages to sections.

### Phase 4: Audio & Polish (Week 4+)

- Integrate audio playback for backing tracks.
- Add setlist management (reorder, add dividers).
- Quality of life: auto-scroll, stage mode, etc.

## Quick Start (Next Steps)

1. **Install Flutter** (if not already done): https://flutter.dev/docs/get-started
2. **Open the project** in VS Code or Android Studio.
3. **Run**:
   ```bash
   flutter pub get
   ```
   This installs all dependencies from `pubspec.yaml`.

4. **Start with Phase 1**: Build the database schema and basic UI.

## Next: Database Schema Design

Once you're ready, we'll create:

- `lib/data/database/app_database.dart`: Drift database with Song, Setlist, and MidiMapping tables.
- `lib/data/models/song_model.dart`: Database representation of Song (will be auto-generated by Drift).
- `lib/data/repositories/song_repository.dart`: CRUD operations wrapper.

This gives you a solid foundation to build the UI on top of.

## Notes for You

- **Don't memorize the structure.** Just know that domain = logic, data = storage, presentation = UI.
- **When adding features**, think: "Which folder does this belong in?" Usually becomes obvious.
- **Use Windsurf to scaffold screens.** Tell it: "Create a new Flutter screen at `lib/presentation/screens/song_editor_screen.dart` that has a TextField for title, a MultilineTextField for lyrics, and a button to save."
- **AI is great at boilerplate.** Focus on the "what" (what should the app do), and let AI handle the "how" (code structure, imports, etc.).

Let me know when you're ready to tackle Phase 1 (database schema) or if you have questions about the structure!
