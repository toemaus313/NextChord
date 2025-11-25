You are an expert Flutter engineer working in a multi-platform Flutter app (Android, iOS, macOS, Windows). The project is my chord/lyrics app currently named NextChord with bundle/package ID com.example.nextchord.

I want you to rename the app to “Troubadour” and change all platform bundle IDs / package IDs to us.antonovich.troubadour, while keeping the existing logo and functionality unchanged.

Hard requirements

New user-visible app name everywhere: Troubadour.

New bundle / application ID everywhere: us.antonovich.troubadour.

Do not modify app logic, UI behavior, or assets beyond what is strictly necessary for the rename.

Do not run flutter run automatically. You may run flutter analyze as needed.

Make sure the changes cover Android, iOS, macOS, and Windows support files.

Specific tasks

Understand current config

Locate the project root (where pubspec.yaml lives).

Confirm the current name: in pubspec.yaml, current Android applicationId / namespace, and current iOS/macOS PRODUCT_BUNDLE_IDENTIFIER values.

Identify all occurrences of the old display name “NextChord” and bundle ID com.example.nextchord in platform folders.

Optionally rename the Flutter package

In pubspec.yaml, change:
name: nextchord → name: troubadour.

Update all Dart imports that use package:nextchord/… to use package:troubadour/….

Do not change any other code semantics while doing this refactor.

Android changes

In android/app/build.gradle (or build.gradle.kts), set:

namespace "us.antonovich.troubadour"
defaultConfig {
    applicationId "us.antonovich.troubadour"
}


In android/app/src/main/res/values/strings.xml, change the app label:
<string name="app_name">NextChord</string> → Troubadour.

Update the Kotlin/Java package:

Rename directories under android/app/src/main/kotlin/... (or java/...) from com/example/nextchord to us/antonovich/troubadour.

Update the package declaration in MainActivity.kt (and any other app entry files) from com.example.nextchord to us.antonovich.troubadour.

In android/app/src/main/AndroidManifest.xml, update the package attribute and any references that still say com.example.nextchord.

iOS changes

Update all PRODUCT_BUNDLE_IDENTIFIER settings for the iOS Runner target from com.example.nextchord to us.antonovich.troubadour. Prefer editing the relevant .xcconfig files if the template uses them.

In ios/Runner/Info.plist, change:

CFBundleDisplayName from NextChord to Troubadour.

If CFBundleName exists and uses the old name, change that too.

If there are test targets (RunnerTests, RunnerUITests) with bundle IDs referencing com.example.nextchord, either update them to a consistent pattern (like us.antonovich.troubadour.tests) or leave them clearly commented as test-only.

macOS changes

In macos/Runner/Configs/AppInfo.xcconfig, update:

PRODUCT_BUNDLE_IDENTIFIER = us.antonovich.troubadour

APP_NAME = Troubadour

Check other macos/Runner/Configs/*.xcconfig (Debug/Release) for any remaining references to com.example.nextchord and update them.

In macos/Runner/Info.plist, update any CFBundleName or CFBundleDisplayName values that still say NextChord to Troubadour.

Windows changes

In windows/runner/Runner.rc, update all user-visible strings:

Any "NextChord" values (e.g., FileDescription, ProductName) → Troubadour.

In windows/runner/main.cpp or windows/runner/flutter_window.cpp, update the window title from "NextChord" to "Troubadour" if present.

Cleanup and verification

Run:

flutter clean
flutter pub get
flutter analyze


Fix any analysis errors introduced by the rename (e.g., import paths, package declarations).

Summarize:

All files that were changed.

The final bundle/application IDs per platform.

Any follow-up manual steps I need to perform in Xcode or Android Studio before I can register these IDs in App Store Connect / Google Play Console.

Work directly in the repo files and show me the diffs for the key config files when you’re done, so I can review them before running any builds.