# Song Metadata Lookup Feature - Setup Guide

## Overview
The online song metadata lookup feature automatically fetches song information (tempo, key, time signature, duration) from SongBPM and MusicBrainz APIs when users manually enter title and artist.

## Required Setup

### 1. SongBPM API Key Configuration

The feature requires a SongBPM API key to fetch tempo, key, and time signature data.

#### Getting an API Key
1. Visit [GetSongBPM.com](https://getsongbpm.com/api)
2. Sign up for an API key (free tier available)
3. Copy your API key

#### Configuration
Edit `lib/services/song_metadata_service.dart` and replace the placeholder:

```dart
// Line ~75 in SongMetadataService
static const String _songBpmApiKey = 'YOUR_SONGBPM_API_KEY'; // Replace with your actual key
```

**Example:**
```dart
static const String _songBpmApiKey = 'abc123def456ghi789jkl012mno345';
```

### 2. MusicBrainz API (No Key Required)

MusicBrainz API is used for duration data and doesn't require authentication. No setup needed.

## Integration Points

### For Import Services
If you have import services that auto-populate title/artist fields, call this method to prevent unwanted automatic lookups:

```dart
// In your import service after populating title/artist
songEditorController.setTitleArtistAutoPopulated(true);
```

### For Song Editor Screen
To enable status messages, pass the online metadata status to SongMetadataForm:

```dart
SongMetadataForm(
  // existing parameters...
  onlineMetadataStatus: controller.onlineMetadataStatus, // Optional parameter
)
```

## Feature Behavior

### When Lookup Triggers
✅ **Will trigger**: User manually types title + artist  
✅ **Will trigger**: Both fields are non-empty  
✅ **Will trigger**: Title/artist were not auto-populated by import  
✅ **Will trigger**: No previous successful lookup for this song  

❌ **Won't trigger**: Title/artist auto-populated by parser  
❌ **Won't trigger**: Either field is empty  
❌ **Won't trigger**: Already successfully looked up for this song  
❌ **Won't trigger**: User has edited fields after successful lookup  

### Field Updates
The feature only updates empty/default fields:
- **BPM**: Only if current value is 120 (default) or empty
- **Key**: Only if current value is 'C' (default)
- **Time Signature**: Only if current value is '4/4' (default)
- **Duration**: Only if field is empty

**Never overwrites user-entered values!**

### Status Messages
- **🔍 Searching**: Blue with spinner - "Song info: searching online…"
- **✅ Found**: Green with checkmark - "Song info: details imported from online sources."
- **❌ Not Found**: Orange with info - "Song info: no online match found."
- **⚠️ Error**: Red with warning - "Song info: error retrieving data. You can continue editing manually."
- **Idle**: Hidden (no status shown)

## Database Migration

The feature includes automatic database migration (v11→v12) to add the `duration` column to the Songs table. No manual intervention required.

## Testing

### Manual Test Scenarios
1. **New song**: Create new song, manually type title + artist, verify lookup runs
2. **Imported song**: Import song with auto-populated title/artist, verify no auto-lookup
3. **Network failure**: Test offline behavior, verify status message and manual editing works
4. **User edits**: After successful lookup, edit fields manually, verify no re-trigger

### API Key Validation
If the SongBPM API key is missing/invalid, the feature will show an error status but won't block the user from manual editing.

## Troubleshooting

### Common Issues

**"Song info: error retrieving data"**
- Check SongBPM API key configuration
- Verify internet connection
- Check API key validity and rate limits

**"Song info: no online match found"**
- Try different title/artist combinations
- Check spelling and artist names
- Some songs may not be in the databases

**No automatic lookup happening**
- Ensure title/artist are manually entered (not auto-populated)
- Check that `setTitleArtistAutoPopulated(false)` is being called
- Verify both fields are non-empty

### Debug Logging
Enable debug logging by setting `isDebug = true` in `lib/main.dart` to see API request details.

## Production Considerations

### Rate Limits
- SongBPM: Check your API plan for rate limits
- MusicBrainz: Has rate limiting but no authentication required

### Error Handling
The feature gracefully handles all error conditions:
- Missing API keys
- Network failures
- API rate limits
- No matches found
- Invalid responses

### Performance
- 1.5-second debounce prevents rapid API calls during typing
- Parallel API requests for optimal speed
- Non-blocking UI with status indicators

## Support

For issues with:
- **API Keys**: Contact SongBPM support
- **Feature Implementation**: Check the implementation in `lib/services/song_metadata_service.dart`
- **UI Issues**: Check `lib/presentation/widgets/song_editor/song_metadata_form.dart`
- **Database Issues**: Migration is handled automatically in `lib/data/database/migrations/migrations.dart`
