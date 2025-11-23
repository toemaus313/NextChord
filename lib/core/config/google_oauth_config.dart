import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class GoogleOAuthConfig {
  // Google OAuth credentials for desktop platforms (Windows/Linux/macOS)
  // These are the app's credentials, not each user's credentials
  //
  // To get these credentials:
  // 1. Go to https://console.cloud.google.com/apis/credentials
  // 2. Create a new project or select existing one
  // 3. Set up OAuth consent screen
  // 4. Create OAuth 2.0 Client ID (Web application)
  // 5. Add authorized redirect URI: http://localhost:8000
  // 6. Copy the Client ID and Client Secret here

  // Desktop/Web client credentials
  static const String desktopClientId =
      '466612959108-8jg6fk21nmj26b2euo2qgc71trkojdtr.apps.googleusercontent.com';
  static const String desktopClientSecret =
      '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';

  // iOS client credentials (from GoogleService-Info.plist)
  static const String iosClientId =
      '466612959108-fheda65jpk2i2se9pfdloi8a24nm5rki.apps.googleusercontent.com';

  // Android client credentials (from Google Cloud Console)
  // Android-specific client ID for GoogleSignIn SDK
  static const String androidClientId =
      '466612959108-acor920kbln88qab2n65u59mt4okvaoq.apps.googleusercontent.com';

  // Get the appropriate client ID for the current platform
  static String get clientId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidClientId; // Android platform uses Android client ID
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return iosClientId; // iOS and macOS platforms use iOS client ID
    } else {
      return desktopClientId; // Desktop/Web platforms use desktop client ID
    }
  }

  // Get the appropriate client secret for the current platform
  static String get clientSecret {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Mobile and macOS platforms don't use client secret, but return desktop one for consistency
      return desktopClientSecret;
    } else {
      return desktopClientSecret;
    }
  }

  static bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty;

  // Getter for desktop client ID (used by web auth fallback)
  static String get webAuthClientId => desktopClientId;

  // Getter for desktop client secret (used by web auth fallback)
  static String get webAuthClientSecret => desktopClientSecret;
}
