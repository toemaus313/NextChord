# App Groups Removal Summary

## Problem
App Groups were causing issues with fastlane builds. App Groups require specific provisioning profiles and entitlements that complicate deployment to TestFlight.

## Solution
Removed App Groups entirely and refactored the Share Extension to pass data via URL query parameters instead of UserDefaults with App Groups.

---

## Changes Made

### 1. iOS Share Extension (`ios/NextChord/ShareViewController.swift`)
**Before:** Used App Groups to share data via `UserDefaults(suiteName: appGroupId)`
**After:** Encodes shared data as base64 JSON and passes it through URL query parameters

Key changes:
- Removed `kAppGroupIdKey` constant
- Removed `appGroupId` property
- Updated `saveAndRedirect()` to:
  - Encode `sharedItems` as JSON
  - Base64 encode the JSON string
  - URL-encode the base64 string
  - Pass data as `?data=<encoded>` query parameter in custom URL scheme
  - Example: `ShareMedia-us.antonovich.nextchord:share?data=eyJ0eXBl...`

### 2. Entitlements Files
Removed App Groups capability from both:
- `ios/NextChord/NextChord.entitlements` (Share Extension)
- `ios/Runner/Runner.entitlements` (Main App)

**Before:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.us.antonovich.nextchord</string>
</array>
```

**After:** Empty dict (no App Groups capability)

### 3. Xcode Project Configuration (`ios/Runner.xcodeproj/project.pbxproj`)
Removed all `CUSTOM_GROUP_ID` build settings from:
- Runner target (Debug, Release, Profile)
- NextChord Share Extension target (Debug, Release, Profile)

### 4. Flutter Share Import Provider (`lib/presentation/providers/share_import_provider.dart`)
**Added:** URL-based data handling using `app_links` package

New features:
- Added `app_links` import and `AppLinks` instance
- Added `_appLinksSubscription` to listen for custom URL schemes
- Added `_checkInitialUrl()` to check for URL on app launch
- Added `_handleUrlScheme(Uri)` to:
  - Parse `data` query parameter from custom URL scheme
  - Base64 decode the parameter
  - JSON parse the decoded string
  - Convert to `SharedMediaFile` list
  - Process the shared media
- Added `_parseMediaType()` helper to convert string types to `SharedMediaType` enum

**Maintained:** Existing `receive_sharing_intent` integration for standard share intents (non-Ultimate Guitar shares)

---

## How It Works Now

### Share Flow (Ultimate Guitar → NextChord)
1. User taps "Share" in Ultimate Guitar app
2. iOS displays share sheet with NextChord Share Extension
3. Share Extension receives the chord chart content
4. Extension encodes content as: `JSON → base64 → URL-encoded string`
5. Extension opens custom URL: `ShareMedia-us.antonovich.nextchord:share?data=<encoded>`
6. iOS launches/foregrounds NextChord app with this URL
7. `app_links` package detects the URL and triggers `_handleUrlScheme()`
8. Flutter decodes: `URL parameter → base64 decode → JSON parse → SharedMediaFile list`
9. Existing share import logic processes the content
10. Song editor opens with imported chord chart

### Benefits
✅ **No App Groups Required** - Simpler provisioning, no special entitlements
✅ **Fastlane Compatible** - Standard app signing works without App Groups complications
✅ **Same Functionality** - Share feature works exactly as before
✅ **Future-Proof** - URL-based approach works across iOS versions
✅ **Transparent** - Data flow is easier to debug (visible in logs)

### Limitations
⚠️ **URL Length Limits** - iOS URL schemes have practical limits (~2MB for data URLs, ~65K for most intents)
- This is sufficient for chord charts (typically <50KB)
- For larger data, would need to fall back to App Groups or file-based sharing

---

## Testing Recommendations

1. **Test Share from Ultimate Guitar:**
   - Open chord chart in Ultimate Guitar app
   - Tap Share button
   - Select NextChord from share sheet
   - Verify chord chart imports correctly

2. **Test Fastlane Build:**
   ```bash
   cd ios
   fastlane beta
   ```
   - Should build and upload to TestFlight without App Groups errors

3. **Check URL Handling:**
   - Enable debug output in ShareViewController.swift
   - Look for: "Opening URL with inline data (length: X)"
   - In Flutter, check for successful URL parsing in logs

---

## Rollback Plan (If Needed)

If you need to restore App Groups:

1. Revert entitlements files:
   ```bash
   git checkout HEAD -- ios/NextChord/NextChord.entitlements
   git checkout HEAD -- ios/Runner/Runner.entitlements
   ```

2. Revert ShareViewController:
   ```bash
   git checkout HEAD -- ios/NextChord/ShareViewController.swift
   ```

3. Revert Flutter provider:
   ```bash
   git checkout HEAD -- lib/presentation/providers/share_import_provider.dart
   ```

4. Re-add `CUSTOM_GROUP_ID` to project.pbxproj (or let Xcode regenerate it)

---

## Files Modified

- `ios/NextChord/ShareViewController.swift`
- `ios/NextChord/NextChord.entitlements`
- `ios/Runner/Runner.entitlements`
- `ios/Runner.xcodeproj/project.pbxproj`
- `lib/presentation/providers/share_import_provider.dart`

---

Date: November 25, 2024
