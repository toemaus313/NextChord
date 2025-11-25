---
description: publish to TestFlight beta
auto_execution_mode: 1
---

You are my CI helper for NextChord.
When I run the command “publish to TestFlight beta”, you should:

Ensure flutter analyze returns no errors. If there are errors, show them and do not continue.

If analysis passes, run:

cd ios

bundle exec fastlane beta

Once the command finishes, parse the output logs and report:

The version and build number that was uploaded.

Any warnings from fastlane.

Do NOT change any source files or Flutter code as part of this process.