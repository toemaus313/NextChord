# MIDI Pedal Mappings Implementation

## Overview

NextChord supports MIDI pedal mappings that allow external MIDI pedals or keyboard shortcuts to trigger actions within the app, such as navigating between song sections, controlling the metronome, or changing songs in setlists.

## Database Schema

### PedalMappings Table

```sql
CREATE TABLE pedal_mappings (
  id TEXT PRIMARY KEY,
  key TEXT NOT NULL,                    -- Key identifier (e.g., 'upArrow', 'downArrow', MIDI note)
  action TEXT NOT NULL,                 -- JSON object describing the action
  description TEXT,                     -- User-friendly description
  is_enabled INTEGER NOT NULL DEFAULT 1,-- Enable/disable mapping
  created_at INTEGER NOT NULL,         -- Timestamp
  updated_at INTEGER NOT NULL,         -- Timestamp
  is_deleted INTEGER NOT NULL DEFAULT 0 -- Soft delete flag
);
```

### Field Descriptions

- **id**: Unique identifier for the mapping
- **key**: Input key identifier (keyboard keys or MIDI notes)
- **action**: JSON object describing the action to execute
- **description**: Human-readable description of the mapping
- **is_enabled**: Boolean flag to enable/disable mappings
- **created_at/updated_at**: Timestamps for tracking
- **is_deleted**: Soft delete flag for data integrity

## Data Migration

### Source Format

Pedal mappings are imported from `examples/library.json` in the Justchords format:

```json
{
  "pedalMapping": [
    {
      "action": {
        "nextSongSection": {}
      },
      "key": "downArrow",
      "id": "FBD9BD32-EA57-4D56-A12A-FCADA922B591"
    },
    {
      "action": {
        "previousSongSection": {}
      },
      "key": "upArrow", 
      "id": "1AB51AD4-FB56-4D04-98DD-393D40A3A6A8"
    }
  ]
}
```

### Migration Process

1. **Analysis**: Script identifies pedal mappings in library.json
2. **Conversion**: Action objects converted to JSON strings
3. **Description**: Auto-generated descriptions based on action type
4. **Import**: Inserted into `pedal_mappings` table with proper timestamps

### Migration Command

```bash
# Preview migration
dart scripts/migrate_from_library_standalone.dart --dry-run

# Execute migration
dart scripts/migrate_from_library_standalone.dart
```

## Action Types

### Supported Actions

Actions are stored as JSON objects. Currently supported types:

```json
{
  "nextSongSection": {}        // Navigate to next song section
}
```

```json
{
  "previousSongSection": {}   // Navigate to previous song section
}
```

### Future Action Types

Planned actions for future implementation:

```json
{
  "nextSong": {}              // Navigate to next song in setlist
}
```

```json
{
  "previousSong": {}          // Navigate to previous song in setlist
}
```

```json
{
  "toggleMetronome": {}       // Start/stop metronome
}
```

```json
{
  "setTempo": {"bpm": 120}    // Set metronome tempo
}
```

## Key Identifiers

### Keyboard Keys

- `upArrow` - Up arrow key
- `downArrow` - Down arrow key
- `leftArrow` - Left arrow key
- `rightArrow` - Right arrow key
- `space` - Spacebar
- `enter` - Enter/Return key
- `escape` - Escape key

### MIDI Notes

MIDI note identifiers follow the format: `NOTE_OCTAVE` (e.g., `C4`, `G#3`)

- `C3` - Middle C
- `C4` - One octave above middle C
- `G#2` - G sharp in second octave

## Database Operations

### CRUD Methods

```dart
// Get all pedal mappings
Future<List<PedalMappingModel>> getAllPedalMappings()

// Get pedal mapping by ID
Future<PedalMappingModel?> getPedalMappingById(String id)

// Insert new pedal mapping
Future<void> insertPedalMapping(PedalMappingModel mapping)

// Update existing pedal mapping
Future<void> updatePedalMapping(PedalMappingModel mapping)

// Delete pedal mapping (soft delete)
Future<void> deletePedalMapping(String id)
```

### Usage Example

```dart
final db = AppDatabase();

// Get all mappings
final mappings = await db.getAllPedalMappings();

// Create new mapping
final newMapping = PedalMappingModel(
  id: 'custom-mapping-id',
  key: 'space',
  action: '{"toggleMetronome": {}}',
  description: 'Toggle metronome',
  isEnabled: true,
  createdAt: DateTime.now().millisecondsSinceEpoch,
  updatedAt: DateTime.now().millisecondsSinceEpoch,
  isDeleted: false,
);

await db.insertPedalMapping(newMapping);
```

## Implementation Roadmap

### Phase 1: Database Layer ✅
- [x] Database schema (PedalMappings table)
- [x] Migration from library.json
- [x] CRUD operations
- [x] Schema version bump to 10

### Phase 2: Input Detection (Future)
- [ ] MIDI input device detection
- [ ] Keyboard input listener
- [ ] MIDI note to key mapping
- [ ] Input event handling

### Phase 3: Action Execution (Future)
- [ ] Action parser/interpreter
- [ ] Song section navigation
- [ ] Metronome control
- [ ] Setlist navigation

### Phase 4: UI/UX (Future)
- [ ] Pedal mapping configuration screen
- [ ] Test/calibration interface
- [ ] Visual feedback for pedal actions
- [ ] Import/export functionality

## Technical Notes

### Distinction from MIDI Trigger Actions

- **MIDI Trigger Actions**: Found in library.json, represent MIDI message → action mappings for the original Justchords app
- **Pedal Mappings**: NextChord-specific feature for keyboard/MIDI pedal → action mappings
- Both serve similar purposes but use different data structures and implementation approaches

### JSON Action Format

Actions are stored as JSON strings for flexibility:
- Easy to extend with new action types
- Supports parameters (e.g., tempo values)
- Human-readable for debugging
- Forward-compatible with future features

### Soft Delete Pattern

Pedal mappings use soft deletion (`is_deleted` flag) to:
- Preserve data integrity
- Enable sync/backup functionality
- Allow recovery of accidentally deleted mappings
- Maintain audit trail

## Testing

### Migration Testing

```bash
# Test migration with dry run
dart scripts/migrate_from_library_standalone.dart --dry-run

# Verify database contents
sqlite3 nextchord_db.sqlite "SELECT key, description FROM pedal_mappings;"
```

### Expected Results

After migration, the database should contain:

| key      | description              |
|----------|--------------------------|
| upArrow  | Previous song section    |
| downArrow| Next song section        |

## Troubleshooting

### Migration Issues

- **Schema version errors**: Ensure `dart run build_runner build` was run after schema changes
- **Missing table**: Check that migration from version 9 to 10 executed properly
- **Duplicate keys**: Currently not enforced, but consider adding UNIQUE constraint to `key` column

### Performance Considerations

- Pedal mappings table expected to remain small (< 100 entries)
- JSON action parsing is lightweight for simple actions
- Consider indexing `key` column if performance becomes an issue

## Dependencies

- `drift`: Database ORM and migrations
- `sqlite3`: Direct database access for migration script
- `json`: Action serialization/deserialization

## Related Files

- `lib/data/database/tables/tables.dart` - Database schema definition
- `lib/data/database/app_database.dart` - Database operations and migrations
- `lib/data/database/migrations/migrations.dart` - Migration logic
- `scripts/migrate_from_library_standalone.dart` - Migration script
- `examples/library.json` - Source data for migration

---

**Last Updated**: November 24, 2025
**Schema Version**: 10
**Migration Status**: ✅ Complete
