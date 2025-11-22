# Google Drive Sync Setup for Desktop Platforms

This guide explains how to enable Google Drive sync on Windows and Linux platforms for NextChord.

## Why Setup is Required

Desktop platforms (Windows/Linux) require OAuth 2.0 credentials to authenticate with Google services. This is a standard requirement for desktop applications and **only needs to be done once by the developer**, not by each user.

## Quick Setup Steps

### 1. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Sign in with your Google account
3. Create a new project or select an existing one
4. Enable the **Google Drive API**:
   - Go to "APIs & Services" → "Library"
   - Search for "Google Drive API"
   - Click "Enable"

### 2. Configure OAuth Consent Screen

1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose **"External"** for user type
3. Fill in required information:
   - **App name**: NextChord
   - **User support email**: Your email
   - **Developer contact information**: Your email
4. Continue through the steps (you can skip optional fields for testing)
5. Add test users (your Google account) for testing

### 3. Create OAuth Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. Select **"Web application"** as application type
4. Under "Authorized redirect URIs", add:
   ```
   http://localhost:8000
   ```
5. Click "Create"

### 4. Update Configuration

1. Open the file: `lib/core/config/google_oauth_config.dart`
2. Replace the empty strings with your credentials:

```dart
class GoogleOAuthConfig {
  static const String clientId = 'YOUR_CLIENT_ID.apps.googleusercontent.com';
  static const String clientSecret = 'YOUR_CLIENT_SECRET';
  
  static bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}
```

### 5. Test the Setup

1. Run the app on Windows or Linux
2. Open Storage settings
3. The Google Drive sync toggle should now be available
4. Click the toggle to sign in with Google

## Important Notes

- **Security**: Never commit your actual client secret to version control. Consider using environment variables for production builds.
- **Distribution**: When distributing your app, these are YOUR app's credentials, not each user's credentials.
- **Testing**: Add your Google account as a test user in the OAuth consent screen during development.
- **Production**: For production deployment, you'll need to publish your app and remove the testing restrictions.

## Troubleshooting

### "Desktop Setup Required" Message
This appears when OAuth credentials are not configured. Follow the setup steps above.

### Authentication Fails
- Ensure the redirect URI `http://localhost:8000` is exactly as shown (no trailing slash)
- Check that your Google account is added as a test user
- Verify the Google Drive API is enabled

### Still Having Issues?
- Check the debug console for detailed error messages
- Ensure you're using the latest version of the `google_sign_in_all_platforms` package
- Make sure no firewall is blocking localhost:8000

## Mobile Platforms

No setup is required for Android, iOS, or Web - these platforms use Google's built-in authentication system.
