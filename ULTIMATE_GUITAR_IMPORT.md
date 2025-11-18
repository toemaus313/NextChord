# Ultimate Guitar Import Feature

## Overview

Phase 1 implementation of importing chord sheets from Ultimate Guitar tabs into NextChord.

## Features

- Import songs directly from Ultimate Guitar URLs
- Automatic conversion from Ultimate Guitar format to ChordPro format
- Extracts song title and artist automatically
- Preserves chord positioning and lyrics
- Handles section markers (Intro, Verse, Chorus, etc.)

## How to Use

### 1. Get a Ultimate Guitar URL

1. Go to [Ultimate Guitar](https://www.ultimate-guitar.com/)
2. Search for a song
3. Click on a chord tab (look for "Chords" type)
4. Copy the URL from your browser
   - Example: `https://tabs.ultimate-guitar.com/tab/icehouse/crazy-chords-125754`

### 2. Import in NextChord

1. Open NextChord
2. Tap the **"+"** button to create a new song
3. In the Song Editor, tap the **cloud download icon** (☁️⬇️) in the top right
4. Paste the Ultimate Guitar URL
5. Tap **Import**
6. Wait for the import to complete
7. Review the imported song and make any adjustments
8. Tap **Save** to add it to your library

## What Gets Imported

- ✅ Song title
- ✅ Artist name
- ✅ Lyrics with chords positioned inline
- ✅ Section markers (Intro, Verse, Chorus, Bridge, etc.)
- ❌ Chord diagrams (not in Phase 1)
- ❌ Tuning information (not in Phase 1)
- ❌ Capo settings (not in Phase 1)

## Format Conversion

Ultimate Guitar uses a custom format with special tags:

**Ultimate Guitar Format:**
```
[Verse]
[tab][ch]G[/ch]   [ch]C[/ch]
Amazing grace[/tab]
```

**Converted to ChordPro:**
```
{start_of_verse}
[G]   [C]
Amazing grace
```

## Supported Tab Types

- ✅ **Chords** - Best supported, designed for this format
- ⚠️ **Tabs** - May work but not optimized
- ❌ **Guitar Pro** - Not supported (requires Pro subscription)
- ❌ **Official Tabs** - Not supported (requires Pro subscription)

## Limitations

1. **Internet Required**: You need an active internet connection to import
2. **Public Tabs Only**: Only works with publicly accessible tabs
3. **Format Variations**: Some tabs may not convert perfectly if they use non-standard formatting
4. **Rate Limiting**: Don't import too many tabs rapidly to avoid being blocked by Ultimate Guitar

## Troubleshooting

### "Invalid Ultimate Guitar URL"
- Make sure you're using a URL from `tabs.ultimate-guitar.com`
- The URL should contain `/tab/` in the path
- Example: `https://tabs.ultimate-guitar.com/tab/artist/song-chords-123456`

### "Could not find song data on the page"
- The page format may have changed
- Try a different tab for the same song
- Make sure the tab is publicly accessible (not Pro-only)

### "Failed to fetch page"
- Check your internet connection
- The Ultimate Guitar website may be down
- Try again in a few minutes

### Chords Not Positioned Correctly
- This is a known limitation of the conversion process
- You can manually adjust chord positions after import
- Ultimate Guitar's spacing doesn't always translate perfectly to ChordPro

## Technical Details

### Files Created

1. **`lib/core/utils/ultimate_guitar_parser.dart`**
   - Converts Ultimate Guitar format to ChordPro
   - Handles chord tags, section markers, and lyric blocks

2. **`lib/services/import/ultimate_guitar_import_service.dart`**
   - Fetches pages from Ultimate Guitar
   - Extracts JSON data from HTML
   - Orchestrates the import process

3. **`test/ultimate_guitar_parser_test.dart`**
   - Unit tests for the parser
   - Ensures conversion accuracy

### Dependencies Added

- `http: ^1.1.0` - For fetching web pages
- `html: ^0.15.4` - For parsing HTML content

## Future Enhancements (Not in Phase 1)

- Import chord diagrams and fingering positions
- Extract tuning and capo information
- Support for importing entire setlists
- Batch import multiple songs
- Import from other chord websites
- Offline caching of imported tabs

## Legal Considerations

**Important**: Ultimate Guitar's Terms of Service may prohibit automated scraping. This feature is provided for:

- Personal use only
- Educational purposes
- Importing tabs you have permission to use

**Do not**:
- Redistribute imported content
- Use this for commercial purposes
- Import copyrighted material without permission
- Overwhelm Ultimate Guitar's servers with rapid requests

Users are responsible for ensuring they have the right to import and use any content.

## Testing

Run the parser tests:
```bash
flutter test test/ultimate_guitar_parser_test.dart
```

All tests should pass (7 tests).

## Example Import

Try importing this tab to test the feature:
- **Song**: Crazy by Icehouse
- **URL**: `https://tabs.ultimate-guitar.com/tab/icehouse/crazy-chords-125754`
- **Expected Result**: Song with verses, chorus, and properly positioned chords

---

**Phase 1 Complete** ✅

Next steps: Add chord diagram support, tuning detection, and batch import capabilities.
