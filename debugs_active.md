# Active Debug Logs - NextChord Codebase

## Status: ACTIVE DEBUG LOGGING 

**Updated**: 2025-11-25  
**Purpose**: UG Import Flow with loading UI + Existing sync functionality + Global error handling

---

## Current Active Debug Statements

### Global Debug Foundation
- **File**: `lib/main.dart`
- **Function**: `myDebug(String message)`
- **Flag**: `bool isDebug = true`
- **Format**: `[$timestamp] $message` (HH:MM:SS format)
- **Description**: Standardized debug helper with timestamps for consistent logging across the app

### Global Error Handler
- **File**: `lib/main.dart`
- **Function**: Global error handlers in main()
- **Message**: `"[$timestamp] GLOBAL ERROR: $error"` and `"[$timestamp] FRAMEWORK ERROR: $error"`
- **Trigger**: Catches all unhandled exceptions including SQLite errors throughout the app
- **Description**: App-wide error catching to capture SQLite constraint failures and similar exceptions

### UG Import Flow Debug Logging

#### ShareImportProvider (Flutter)
- **File**: `lib/presentation/providers/share_import_provider.dart`
- **Functions**: `_initializeShareHandling()`, `_checkInitialIntents()`, `_handleSharedMediaList()`, `_createPayloadFromSharedMedia()`
- **Messages**: 
  - `"ShareImportProvider: Initializing share handling"`
  - `"ShareImportProvider: Checking initial intents"`
  - `"ShareImportProvider: Found [N] initial media items"`
  - `"ShareImportProvider: Initial media [i]: type=[type], path="[path]""`
  - `"ShareImportProvider: Handling [N] shared media items"`
  - `"ShareImportProvider: Processing media: type=[type], path="[path]""`
  - `"ShareImportProvider: Created payload: [payload]"`
  - `"ShareImportProvider: Creating payload from media type=[type]"`
- **Trigger**: When shared content is received from iOS Share Extension
- **Description**: Traces the complete flow of shared content from iOS to Flutter processing

#### ShareImportService (Flutter)
- **File**: `lib/services/import/share_import_service.dart`
- **Functions**: `handleSharedContent()`, `importFromSharedContent()`, `importUltimateGuitarChordSong()`, `importUltimateGuitarTabSong()`
- **Messages**:
  - `"ShareImportService: handleSharedContent called with payload: [payload]"`
  - `"ShareImportService: importFromSharedContent starting"`
  - `"ShareImportService: UG payload detected"`
  - `"ShareImportService: UG TAB import triggered"`
  - `"ShareImportService: UG chord-over-lyric import triggered"`
  - `"ShareImportService: Importing UG chord song, text length=[length]"`
  - `"ShareImportService: Extracted metadata: [metadata]"`
  - `"ShareImportService: Created song entity: title="[title]", artist="[artist]""`
  - `"ShareImportService: Successfully saved song to database"`
- **Trigger**: When shared content is processed and routed to appropriate parsers
- **Description**: Traces content routing, parsing, and database saving for UG imports

#### ShareViewController (iOS)
- **File**: `ios/NextChord/ShareViewController.swift`
- **Functions**: `viewDidLoad()`, `handleSharedContent()`, `saveAndRedirect()`, `openURL()`, `completeRequest()`
- **Messages**:
  - `"ShareViewController: viewDidLoad called"`
  - `"ShareViewController: handleSharedContent called"`
  - `"ShareViewController: Found [N] extension items"`
  - `"ShareViewController: Found [N] attachments"`
  - `"ShareViewController: Loading URL content"`
  - `"ShareViewController: Loaded URL: [url]"`
  - `"ShareViewController: Detected file URL, attempting to read content"`
  - `"ShareViewController: Successfully read file, content length: [N]"`
  - `"ShareViewController: Failed to read file: [error]"`
  - `"ShareViewController: Loading text content"`
  - `"ShareViewController: Loaded text: [text]..."`
  - `"ShareViewController: saveAndRedirect called with [N] items"`
  - `"ShareViewController: Using app group ID: [appGroupId]"`
  - `"ShareViewController: Saved shared data to UserDefaults"`
  - `"ShareViewController: Opening URL: [url]"`
- **Trigger**: When iOS Share Extension processes shared content from Ultimate Guitar app
- **Description**: Traces iOS Share Extension content extraction, file reading (for file URLs), saving, and app redirection. When UG shares a file URL, the extension reads the file content and passes TEXT to the main app.

### Content Type Detector Debug Logging
- **File**: `lib/services/import/content_type_detector.dart`
- **Location**: Lines throughout `isTabContent` method
- **Messages**: 
  - `"ContentTypeDetector: Analyzing content ([N] chars)"`
  - `"ContentTypeDetector: Found tab line pattern: [line preview]..."`
  - `"ContentTypeDetector: Found [N] tab-like lines out of [total] total"`
  - `"ContentTypeDetector: Content classified as: TAB"` or `"CHORD"`
- **Trigger**: When UG import service analyzes shared content to determine if it's tab or chord notation
- **Description**: Logs content analysis and classification decisions for troubleshooting import routing

### Loading Overlay Debug Logging
- **File**: `lib/presentation/providers/share_import_provider.dart`
- **Location**: Lines 101, 121 in `_handleSharedMediaList`
- **Messages**:
  - `"ShareImportProvider: Loading overlay displayed"`
  - `"ShareImportProvider: Loading overlay hidden"`
  - `"ShareImportProvider: Successfully imported song, preparing editor"`
- **Trigger**: When loading overlay is shown/hidden during UG import process
- **Description**: Tracks loading UI display timing and coordination with import completion

### App Control Modal MIDI Learn Debug Logging
- **File**: `lib/presentation/widgets/app_control_modal.dart`
- **Location**: Lines 184-194 (_handleMidiLearn method)
- **Messages**: 
  - `"[$timestamp] MIDI Learn: Discarded event from [device name] ([device id]) - Only accepting from selected device ID: [selected id]"`
  - `"[$timestamp] MIDI Learn: Accepted event from [device name] ([device id])"`
- **Trigger**: When MIDI Learn mode is active and MIDI messages are received
- **Description**: Logs device filtering for MIDI Learn - shows which events are accepted vs discarded based on selected device

### App Control Modal Device Detection Debug Logging
- **File**: `lib/presentation/widgets/app_control_modal.dart`
- **Location**: Lines 599-608 (_buildDeviceSelection method)
- **Message**: `"[$timestamp] Device selection: Found [N] available devices"` and `"[$timestamp] Device: [device name] (ID: [device id])"`
- **Trigger**: When the device selection dropdown is built/rebuilt
- **Description**: Shows available MIDI devices detected by the system for the device dropdown

### Google Sync Service Debug Logging
- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Location**: Line 663 (metadata polling)
- **Message**: `"[$timestamp] Remote change detected in Google Drive - triggering sync"`
- **Trigger**: When remote changes are detected during metadata polling

- **File**: `lib/services/sync/google_drive_sync_service.dart`
- **Location**: Line 498 (sync application)
- **Message**: `"[$timestamp] Remote changes successfully applied to local database"`
- **Trigger**: When remote changes are successfully merged into the local database

### Local Database Change Debug Logging
- **File**: `lib/core/services/database_change_service.dart`
- **Location**: Line 79 (change notification)
- **Message**: `"[$timestamp] Local db change detected - sending to cloud"`
- **Trigger**: When local database changes are detected and scheduled for sync

- **File**: `lib/providers/sync_provider.dart`
- **Location**: Line 184 (sync completion)
- **Message**: `"[$timestamp] Local db change successfully sent to cloud"`
- **Trigger**: When local changes are successfully uploaded to Google Drive

### Metronome Count-In Debug Logging
- **File**: `lib/presentation/providers/metronome_provider.dart`
- **Location**: Lines 419, 427, 441, 445 (_handleCountInTick method)
- **Messages**: 
  - `"[$timestamp] COUNT-IN: _countInBeatsRemaining=[value], _beatsPerMeasure=[value]"`
  - `"[$timestamp] COUNT-IN: totalBeatsSoFar=[value], _currentCountInBeat=[value]"`
  - `"[$timestamp] COUNT-IN: After decrement _countInBeatsRemaining=[value]"`
  - `"[$timestamp] COUNT-IN: Finished, transitioning to normal operation"`
- **Trigger**: During metronome count-in sequence on each tick
- **Description**: Tracks beat calculation and counting logic to troubleshoot count-in beat numbering issues

### Metronome Warm-up Debug Logging
- **File**: `lib/presentation/providers/metronome_provider.dart`
- **Location**: Lines 114, 120, 162, 259 (warm-up phase)
- **Messages**:
  - `"WARM-UP: Starting [N]-beat warm-up phase for timing stabilization"`
  - `"WARM-UP: Beat [N]/[total] (silent, timing stabilization)"`
  - `"WARM-UP: Complete! Starting MIDI clock and count-in/playback"`
- **Trigger**: During metronome startup warm-up phase before count-in
- **Description**: Tracks the silent warm-up period where timing engine stabilizes before starting MIDI clock and count-in

---

## Debug Behavior

### What Gets Logged:
1. **UG Import Flow**: Complete trace from iOS Share Extension to Flutter processing to Editor navigation with loading overlay
   - Loading overlay shown/hidden events
   - Song entity creation and preparation
   - Navigation to Editor screen
2. **Global Errors**: All unhandled exceptions including SQLite constraint failures
3. **Framework Errors**: Flutter framework errors and exceptions
4. **Local Change Detection**: When local database changes are detected and scheduled for cloud sync
5. **Remote Change Detection**: When the metadata polling detects changes in Google Drive
6. **Successful Sync Application**: When remote changes are successfully applied to the local database
7. **Successful Local Upload**: When local changes are successfully uploaded to Google Drive

### What Does NOT Get Logged:
- Normal sync operations without changes
- Network errors or authentication issues (handled silently)
- Metadata polling when no changes are found
- Manual sync operations without underlying changes

---

## Implementation Notes

- Uses standardized `myDebug()` function with timestamps (HH:MM:SS format)
- iOS Share Extension uses equivalent Swift `myDebug()` function with same format
- Debug output can be toggled globally via `isDebug` flag in `main.dart`
- Global error handlers catch all unhandled exceptions app-wide
- UG import debug provides complete visibility into share flow from iOS to database
- Minimal logging approach - only logs key events with precise timing
- No performance impact on normal operations
- Provides complete visibility into sync flow in both directions with timing information
- SQLite errors and similar database exceptions are now captured globally

---

## Future Debug Guidelines

If adding more debug code:
1. Use the standardized `myDebug()` function from `main.dart` (or equivalent in iOS)
2. Update this file to document new debug statements
3. Keep debug logging minimal and focused on key events
4. Ensure debug code can be easily removed via automated cleanup

---

*Last Updated: 2025-11-25 12:22 PM PST*  
*Status: Debugging UG Import Flow + Content Type Detection*
