#!/bin/bash

# =======================================================
# Flutter SDK Setup Script for macOS
# This script downloads the Flutter SDK and runs flutter doctor.
# NOTE: You will need to manually update your shell's PATH 
#       variable after running this script. See the README.md.
# =======================================================

FLUTTER_ROOT="$HOME/development"
FLUTTER_SDK_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.22.0-stable.zip"
FLUTTER_SDK_ZIP="flutter.zip"

echo "--- 🚀 Starting Flutter Installation ---"

# 1. Create the installation directory if it doesn't exist
if [ ! -d "$FLUTTER_ROOT" ]; then
    echo "Creating directory: $FLUTTER_ROOT"
    mkdir -p "$FLUTTER_ROOT"
else
    echo "Using existing directory: $FLUTTER_ROOT"
fi

# 2. Download the Flutter SDK
# We are using a temporary directory to download the zip
cd "$FLUTTER_ROOT"
echo "Downloading Flutter SDK..."
curl -O "$FLUTTER_SDK_URL"

# 3. Unzip the SDK
echo "Unzipping Flutter SDK..."
unzip "$FLUTTER_SDK_ZIP"

# 4. Clean up the zip file
echo "Cleaning up..."
rm "$FLUTTER_SDK_ZIP"

# 5. Verify the Flutter folder is present
if [ -d "$FLUTTER_ROOT/flutter" ]; then
    echo "✅ Flutter SDK successfully installed in: $FLUTTER_ROOT/flutter"
else
    echo "❌ Error: Flutter directory not found after unzipping."
    exit 1
fi

echo ""
echo "=========================================================="
echo "    NEXT STEP: Update your shell's PATH variable!         "
echo "=========================================================="
echo "Add the following line to your shell configuration file (e.g., ~/.zshrc or ~/.bash_profile):"
echo 'export PATH="$PATH:'$FLUTTER_ROOT'/flutter/bin"'
echo ""
echo "Then, run 'source ~/.zshrc' (or your file name) to apply the changes."
echo ""
echo "After updating your PATH, run 'flutter doctor' manually."
echo "--- Installation Script Complete ---"

# The script does NOT run flutter doctor because the PATH is not set yet.
# The user must follow the instructions above.
