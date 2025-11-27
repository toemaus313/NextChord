# iCloud Drive Setup for NextChord

This document provides instructions for configuring iCloud Drive support in NextChord on iOS and macOS platforms.

## Prerequisites

- Apple Developer account
- Xcode installed
- NextChord project cloned and configured
- **App ID with iCloud capability enabled** (in Apple Developer Portal under "Certificates, Identifiers & Profiles")

## iOS Configuration

### 1. Enable iCloud Capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project in the navigator
3. Select the Runner target
4. Go to the "Signing & Capabilities" tab
5. Click "+ Capability" and add "iCloud"
6. In the iCloud section:
   - Enable "iCloud Documents"
   - Add "NextChord" to the "Containers" list as `iCloud.us.antonovich.nextchord`

### 2. Update Entitlements File

Ensure `ios/Runner/Runner.entitlements` contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.us.antonovich.nextchord</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)us.antonovich.nextchord</string>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.us.antonovich.nextchord</string>
    </array>
</dict>
</plist>
```

### 3. Update Info.plist

Add to `ios/Runner/Info.plist`:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.us.antonovich.nextchord</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>NextChord</string>
        <key>NSUbiquitousContainerSupportedFolderLevel</key>
        <string>One</string>
    </dict>
</dict>
```

## macOS Configuration

### 1. Enable iCloud Capability

1. Open `macos/Runner.xcworkspace` in Xcode
2. Select the Runner project in the navigator
3. Select the Runner target
4. Go to the "Signing & Capabilities" tab
5. Click "+ Capability" and add "iCloud"
6. In the iCloud section:
   - Enable "iCloud Documents"
   - Add "NextChord" to the "Containers" list as `iCloud.us.antonovich.nextchord`

### 2. Update Entitlements File

Ensure `macos/Runner/Runner.entitlements` contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.us.antonovich.nextchord</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)us.antonovich.nextchord</string>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.us.antonovich.nextchord</string>
    </array>
</dict>
</plist>
```

### 3. Update Info.plist

Add to `macos/Runner/Info.plist`:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.us.antonovich.nextchord</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>NextChord</string>
        <key>NSUbiquitousContainerSupportedFolderLevel</key>
        <string>One</string>
    </dict>
</dict>
```

## App Store Connect Verification

### For Development & TestFlight
- **No action required** - Xcode automatically provisions iCloud containers
- Everything works through Xcode configuration

### For App Store Distribution
1. **Verify App ID has iCloud capability** in Apple Developer Portal
2. **Check App Store Connect** (optional but recommended):
   - Go to your app in App Store Connect
   - Navigate to "Services" section
   - Verify `iCloud.us.antonovich.nextchord` appears as an enabled service
   - Container typically auto-appears within a few minutes of Xcode configuration

### Common Issues
- **Container not appearing**: Wait 5-10 minutes after Xcode configuration, then refresh App Store Connect
- **Missing capability**: Ensure your App ID includes iCloud capability in Developer Portal
- **Provisioning profile**: Regenerate provisioning profile after adding iCloud capability

## Testing iCloud Integration

### 1. Verify Container Access

Run the app on a physical device or simulator with iCloud enabled:
1. Open Settings → Apple ID → iCloud → iCloud Drive and ensure it's enabled
2. Launch NextChord and navigate to Settings → Cloud Storage
3. Select "iCloud Files" as the storage backend
4. Tap "Sign In" - this should succeed without requiring credentials
5. Check that a "NextChord" folder appears in the Files app under iCloud Drive

### 2. Test Sync Operations

1. Create some test data in NextChord
2. Enable iCloud sync and perform a manual sync
3. Verify files appear in the NextChord iCloud Drive folder
4. Install NextChord on another Apple device with the same Apple ID
5. Sign in to iCloud on the second device
6. Verify data syncs correctly

## Troubleshooting

### Common Issues

1. **iCloud container not found**
   - Verify bundle identifier matches entitlements
   - Check that iCloud capability is properly enabled
   - Ensure team is selected in Xcode project settings

2. **Files not visible in Files app**
   - Verify `NSUbiquitousContainerIsDocumentScopePublic` is set to `true`
   - Check container identifier matches exactly
   - Ensure iCloud Drive is enabled in device settings

3. **Authentication failures**
   - iCloud uses system-level authentication - no app-specific sign-in needed
   - Verify user is signed into iCloud on the device
   - Check that iCloud Drive is enabled in system settings

### Debug Logging

Enable debug logging to troubleshoot issues:
- All iCloud operations are logged with `myDebug()` calls
- Check console output for detailed error messages
- Look for "iCloud Drive" prefixed log messages

## Migration from Google Drive

Users can switch between Google Drive and iCloud Drive:
1. Data is preserved during backend switching
2. File structure remains consistent across backends
3. No data loss occurs when switching storage providers

## Security Considerations

- iCloud Drive uses system-level authentication
- No additional credentials required from users
- Files are stored in user's personal iCloud storage
- App sandboxing ensures access only to NextChord container
