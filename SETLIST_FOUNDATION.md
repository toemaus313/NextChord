# Setlist Feature Foundation

## Overview
This document describes the foundation that has been implemented for the Setlist feature, which allows users to create ordered collections of songs with setlist-specific settings (transpose, capo) and attach a 200x200px image to each setlist.

---

## ✅ What's Been Implemented

### 1. Enhanced Domain Entities (`lib/domain/entities/song.dart`)

#### **Setlist Entity**
- Added `imagePath` field (String?) for storing path to 200x200px setlist image
- Updated `copyWith` method to include imagePath
- Updated `props` for equality comparison

#### **SetlistSongItem Entity**
- Added `transposeSteps` (int?) - Setlist-specific transpose setting (null = use song default)
- Added `capo` (int?) - Setlist-specific capo setting (null = use song default)
- Added `copyWith` method for easy updates
- Updated `props` for equality comparison

**Key Concept:** Setlist-specific settings override the base song settings only when that setlist is active, without modifying the original song.

---

### 2. SetlistProvider (`lib/presentation/providers/setlist_provider.dart`)

**Purpose:** State management for setlists

**Features:**
- Load all setlists from repository
- Get single setlist by ID
- Add new setlist
- Update existing setlist
- Delete setlist
- Error handling with messages
- Loading states

**Key Methods:**
```dart
Future<void> loadSetlists()
Future<Setlist?> getSetlistById(String id)
Future<String> addSetlist(Setlist setlist)
Future<void> updateSetlist(Setlist setlist)
Future<void> deleteSetlist(String id)
void clearError()
Future<void> refresh()
```

---

### 3. SetlistRepository (`lib/data/repositories/setlist_repository.dart`)

**Purpose:** Data access layer for setlists

**Features:**
- Converts between domain entities and database models
- JSON serialization/deserialization for setlist items
- Handles setlist-specific song settings (transpose, capo)
- CRUD operations

**Key Implementation Details:**
- Setlist items are stored as JSON in the database
- Each item includes type ('song' or 'divider'), order, and optional settings
- Automatic UUID generation for new setlists
- Automatic timestamp management (createdAt, updatedAt)

---

### 4. Database Schema Updates (`lib/data/database/app_database.dart`)

#### **Changes Made:**
1. Added `imagePath` column to `Setlists` table (nullable text)
2. Updated schema version from 2 to 3
3. Added migration logic for existing databases

#### **Migration Code:**
```dart
if (from <= 2 && to >= 3) {
  // Add imagePath column to setlists table
  await m.addColumn(setlists, setlists.imagePath);
}
```

**Schema Version:** 3

---

### 5. Setlists List Screen (`lib/presentation/screens/setlists_screen.dart`)

**Purpose:** Display all setlists in a grid view

**Features:**
- Grid layout (2 columns)
- Shows setlist image (200x200) or placeholder
- Shows setlist name and song count
- Loading, error, and empty states
- Create new setlist button
- Navigate to setlist editor on tap

**UI States:**
- Loading: Shows CircularProgressIndicator
- Error: Shows error message with retry button
- Empty: Shows "No setlists yet" with create button
- Loaded: Shows grid of setlist cards

---

### 6. Setlist Editor Screen Placeholder (`lib/presentation/screens/setlist_editor_screen.dart`)

**Purpose:** Basic structure for creating/editing setlists

**Current Implementation:**
- Name field
- Notes field
- Save button
- Placeholder text listing features to be implemented

**Status:** Basic placeholder - needs full implementation

---

## ⚠️ CRITICAL: Next Step Required

### Run Database Code Generation

The database schema has been updated but the generated Drift code needs to be regenerated. Run this command:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Why this is needed:**
- The `imagePath` column was added to the database schema
- Drift needs to regenerate the model classes to include this field
- Current errors in SetlistRepository will be resolved after this runs

**Expected Result:**
- `SetlistModel` will include `imagePath` getter
- Migration code will compile correctly
- All type errors will be resolved

---

## 📋 What Still Needs to Be Implemented

### 1. Wire Up Setlists in the App

#### **Add SetlistProvider to app_wrapper.dart**
```dart
MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(
      create: (_) => SetlistProvider(
        SetlistRepository(context.read<AppDatabase>())
      ),
    ),
  ],
)
```

#### **Update Sidebar (`global_sidebar.dart`)**
- Add navigation to SetlistsScreen when "Setlists" menu item is clicked
- Currently it's a placeholder with empty `onTap`

---

### 2. Full Setlist Editor Implementation

The editor needs these major features:

#### **A. Image Management**
- Upload/select 200x200px image
- Display current image
- Remove/replace image
- Store image in app's documents directory
- Validate image dimensions

**Suggested Package:** `image_picker` for selecting images

#### **B. Song List Management**
- Display ordered list of songs in the setlist
- Show song title, artist, and current settings
- Add songs from library (search/browse)
- Remove songs from setlist
- Empty state when no songs added

#### **C. Song Reordering**
- Drag and drop to reorder songs
- Update order numbers automatically
- Visual feedback during drag

**Suggested Package:** `reorderable_list` or Flutter's built-in `ReorderableListView`

#### **D. Setlist-Specific Song Settings**
- Per-song transpose setting (override song default)
- Per-song capo setting (override song default)
- Show indicator when settings differ from song defaults
- Edit dialog for each song's settings

#### **E. Section Dividers**
- Add dividers/section markers between songs
- Edit divider labels
- Reorder dividers along with songs
- Visual distinction from songs

#### **F. Save/Cancel Logic**
- Validate setlist name (required)
- Save to database via SetlistProvider
- Handle errors gracefully
- Return to list screen on success

---

### 3. Setlist Playback/Viewing

**Future Feature:** When a setlist is "active":
- Display songs in order
- Apply setlist-specific transpose/capo settings
- Navigate between songs in the setlist
- Show progress through setlist

---

## 🗂️ File Structure

```
lib/
├── domain/entities/
│   └── song.dart                    # ✅ Updated with imagePath and settings
├── data/
│   ├── database/
│   │   └── app_database.dart        # ✅ Updated schema (v3)
│   └── repositories/
│       └── setlist_repository.dart  # ✅ Created
└── presentation/
    ├── providers/
    │   └── setlist_provider.dart    # ✅ Created
    └── screens/
        ├── setlists_screen.dart     # ✅ Created (basic)
        └── setlist_editor_screen.dart # ✅ Created (placeholder)
```

---

## 🎯 Implementation Priority

### Phase 1 (Essential)
1. ✅ Run `build_runner` to fix compilation errors
2. Wire up SetlistProvider in app
3. Connect Setlists menu in sidebar
4. Test basic list screen

### Phase 2 (Core Features)
1. Implement image upload/selection
2. Implement add songs to setlist
3. Implement remove songs from setlist
4. Basic save functionality

### Phase 3 (Advanced Features)
1. Implement drag-and-drop reordering
2. Implement setlist-specific settings per song
3. Implement section dividers
4. Polish UI/UX

### Phase 4 (Future)
1. Setlist playback mode
2. Export/share setlists
3. Duplicate setlists
4. Setlist templates

---

## 📝 Notes

### Design Decisions

**Why setlist-specific settings?**
- Users often need different transpose/capo for different contexts
- Example: Same song in different keys for different vocalists
- Keeps base song unchanged while allowing flexibility

**Why 200x200px images?**
- Small enough for performance
- Large enough for clear display
- Square format works well in grid layouts
- Easy to generate/resize

**Why JSON for setlist items?**
- Flexible structure for songs and dividers
- Easy to extend with new fields
- Efficient storage in single column
- Maintains order information

### Database Schema

**Setlists Table:**
```sql
CREATE TABLE setlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  items TEXT NOT NULL,      -- JSON array
  notes TEXT,
  imagePath TEXT,           -- NEW in v3
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
);
```

**Items JSON Structure:**
```json
[
  {
    "type": "song",
    "songId": "uuid",
    "order": 0,
    "transposeSteps": 2,     -- Optional
    "capo": 3                -- Optional
  },
  {
    "type": "divider",
    "label": "Worship Set",
    "order": 1
  }
]
```

---

## 🐛 Known Issues / Limitations

1. **Image storage:** Currently stores path as string - need to implement actual file management
2. **Image validation:** No validation of 200x200px dimensions yet
3. **Reordering:** Not implemented - order is managed manually
4. **Setlist playback:** Not implemented - just editing for now

---

## 🔗 Related Files to Review

- `lib/domain/entities/song.dart` - See Setlist, SetlistItem classes
- `lib/presentation/screens/library_screen.dart` - Reference for song list UI
- `lib/presentation/screens/song_editor_screen.dart` - Reference for form UI
- `lib/presentation/widgets/global_sidebar.dart` - Where to add navigation

---

## 📚 Suggested Packages

For full implementation, consider adding:

```yaml
dependencies:
  image_picker: ^1.0.0      # For selecting images
  path_provider: ^2.1.0     # For file storage paths
  image: ^4.1.0             # For image manipulation/resizing
```

---

**Last Updated:** November 18, 2025
**Status:** Foundation Complete - Ready for Full Implementation
