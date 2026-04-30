#!/bin/bash
# Builds DesktopToggle and packages it as a proper .app bundle.
# Run this on your Mac: bash build-app.sh
set -e

APP="DesktopToggle.app"

echo "Building DesktopToggle (release)..."
swift build -c release

echo "Packaging $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp ".build/release/DesktopToggle" "$APP/Contents/MacOS/DesktopToggle"
cp "Resources/Info.plist"         "$APP/Contents/Info.plist"

echo ""
echo "Done — $APP is ready."
echo ""
echo "To run:  open $APP"
echo "         (or drag to /Applications for permanent install)"
echo ""
echo "First run: macOS may ask for Input Monitoring access in"
echo "System Settings → Privacy & Security → Input Monitoring."
echo "Enable DesktopToggle there so it can detect desktop clicks."
