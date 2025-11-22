class GoogleOAuthConfig {
  // Google OAuth credentials for desktop platforms (Windows/Linux)
  // These are the app's credentials, not each user's credentials
  //
  // To get these credentials:
  // 1. Go to https://console.cloud.google.com/apis/credentials
  // 2. Create a new project or select existing one
  // 3. Set up OAuth consent screen
  // 4. Create OAuth 2.0 Client ID (Web application)
  // 5. Add authorized redirect URI: http://localhost:8000
  // 6. Copy the Client ID and Client Secret here

  static const String clientId =
      '466612959108-8jg6fk21nmj26b2euo2qgc71trkojdtr.apps.googleusercontent.com';
  static const String clientSecret = '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';

  static bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty;
}
