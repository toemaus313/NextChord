# Justchords to NextChord Import Summary

## Overview
Successfully analyzed the Justchords `library.json` format and created an import system to convert songs to NextChord's ChordPro format.

## Library Statistics
- **Total songs in library**: 604 songs
- **Format**: Justchords proprietary JSON format
- **Sample imported**: 5 random songs

## Justchords Format Analysis

### Song Structure
Each song in Justchords contains:
- `id`: Unique identifier (UUID)
- `title`: Song title
- `subtitle` or `artist`: Artist name
- `rawData`: Chord chart and lyrics (mixed format)
- `keyChord`: Object with `key` (string) and `minor` (boolean)
- `tempo`: BPM as string
- `timeSignature`: Time signature (e.g., "4/4")
- `duration`: Song duration (e.g., "3:45")
- `date`: Unix timestamp

### Raw Data Format
Justchords uses a mixed format in `rawData`:
- Section markers: `[Intro]`, `[Verse]`, `[Chorus]`, `[Bridge]`, etc.
- Alternative markers: `{start_of_verse}`, `{end_of_verse}`, etc.
- Chords in brackets: `[G]`, `[Am]`, `[C]`
- Inline chords above lyrics
- Guitar tabs and tablature

## NextChord Format

### Song Entity
NextChord uses a structured Song entity with:
- `id`: UUID
- `title`: Song title
- `artist`: Artist name
- `body`: ChordPro formatted text
- `key`: Musical key (string)
- `capo`: Capo position (integer)
- `bpm`: Beats per minute (integer)
- `timeSignature`: Time signature (string)
- `tags`: List of tags
- `notes`: Optional notes
- `audioFilePath`: Optional backing track path
- `createdAt`, `updatedAt`: Timestamps
- `isDeleted`: Soft delete flag

### ChordPro Format
NextChord uses ChordPro standard with directives:
- `{title:Song Title}`
- `{artist:Artist Name}`
- `{key:C}`
- `{tempo:120}`
- `{time:4/4}`
- `{comment:Section Name}`
- Chords in brackets: `[G]`, `[Am]`, `[C]`

## Conversion Process

### Metadata Mapping
| Justchords | NextChord |
|------------|-----------|
| `title` | `title` |
| `subtitle` or `artist` | `artist` |
| `keyChord.key` | `key` |
| `tempo` | `bpm` |
| `timeSignature` | `timeSignature` |
| `duration` | `notes` (as "Duration: X:XX") |
| - | `tags` = ["imported", "justchords"] |

### Content Conversion
1. **Add ChordPro directives** at the top of the body
2. **Convert section markers**:
   - `[Intro]` → `{comment:Intro}`
   - `[Verse]` → `{comment:Verse}`
   - `[Chorus]` → `{comment:Chorus}`
   - etc.
3. **Preserve chord notation**: `[G]`, `[Am]`, etc. remain unchanged
4. **Remove attribution**: Strip "Created using SongSheet Pro" comments
5. **Keep formatting**: Preserve spacing and alignment

## Sample Songs Imported

The following 5 songs were randomly selected and successfully converted:

1. **"Cab In A Solo"** (Unknown Artist)
   - Key: C | Tempo: N/A | Time: 4/4

2. **"Smoke Rings In The Dark"** by Gary Allan
   - Key: D | Tempo: 116 BPM | Time: 4/4

3. **"Riptide"** by Vance Joy
   - Key: (varies) | Tempo: (varies) | Time: 4/4

4. **"Beaches of Cheyenne"** by Garth Brooks
   - Key: (varies) | Tempo: (varies) | Time: 4/4

5. **"Call Me The Breeze"** by J.J. Cale
   - Key: (varies) | Tempo: (varies) | Time: 4/4

See `imported_songs_preview.txt` for full conversion details.

## Implementation Files

### Created Files
1. **`lib/core/utils/justchords_importer.dart`**
   - Main importer utility class
   - `JustchordsImporter.importFromFile()` - Import songs from JSON
   - `JustchordsImporter.parseSong()` - Convert single song
   - Handles format conversion and validation

2. **`scripts/test_import.dart`**
   - Standalone test script
   - Displays song metadata without database dependency
   - Shows raw data statistics

3. **`scripts/preview_import.dart`**
   - Generates preview of converted songs
   - Outputs to `imported_songs_preview.txt`
   - Shows before/after comparison

4. **`scripts/import_justchords.dart`**
   - Full import script with database integration
   - Interactive prompts for confirmation
   - Saves songs to NextChord database

## Usage

### Preview Import (No Database Changes)
```bash
dart run scripts/preview_import.dart
```
This generates `examples/imported_songs_preview.txt` with conversion preview.

### Test Import (Display Only)
```bash
dart run scripts/test_import.dart
```
Shows metadata for 5 random songs without conversion.

### Full Import (Requires Flutter)
```bash
dart run scripts/import_justchords.dart
```
Converts and saves songs to the NextChord database (requires user confirmation).

## Notes

- The importer filters out empty songs (no title or rawData)
- All imported songs are tagged with `["imported", "justchords"]`
- Duration information is preserved in the `notes` field
- Capo is set to 0 by default (not present in Justchords format)
- Minor keys are detected from `keyChord.minor` boolean

## Future Enhancements

Potential improvements:
1. Batch import with progress tracking
2. Duplicate detection (check if song already exists)
3. Better handling of guitar tabs and tablature
4. Support for transposing keys during import
5. Import specific songs by title/artist search
6. Export from NextChord back to Justchords format
7. Preserve original Justchords ID for reference

## Conclusion

✅ Successfully demonstrated the ability to import songs from Justchords library.json into NextChord format. The conversion preserves all essential metadata and chord chart information while adapting to NextChord's ChordPro standard.
