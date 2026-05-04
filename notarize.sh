#!/bin/bash
# Builds, signs, notarizes, and staples DesktopToggle for direct distribution.
#
# Prerequisites
# ─────────────
# 1. Apple Developer account (developer.apple.com — $99/year)
# 2. "Developer ID Application" certificate installed in Keychain
#    (Xcode → Settings → Accounts → Manage Certificates → +)
# 3. An app-specific password from appleid.apple.com
#    (Sign In → App-Specific Passwords → Generate)
#
# Fill in the three variables below, then run:  bash notarize.sh
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
TEAM_ID="XXXXXXXXXX"                 # 10-char Team ID from developer.apple.com
APPLE_ID="you@example.com"           # Your Apple ID email
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password (NOT your Apple ID password)
BUNDLE_ID="com.yourname.DesktopToggle"  # Must match Info.plist CFBundleIdentifier
# ─────────────────────────────────────────────────────────────────────────────

APP_NAME="DesktopToggle"
DERIVED_DATA="build"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
ZIP_PATH="$APP_NAME.zip"
DMG_PATH="$APP_NAME.dmg"

echo "==> Step 1: Build (Release, hardened runtime, Developer ID signing)"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme  "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  clean build

echo ""
echo "==> Step 2: Package for notarization"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "==> Step 3: Submit to Apple Notary Service (usually < 5 minutes)"
xcrun notarytool submit "$ZIP_PATH" \
  --apple-id    "$APPLE_ID" \
  --password    "$APP_PASSWORD" \
  --team-id     "$TEAM_ID" \
  --wait

echo ""
echo "==> Step 4: Staple the notarization ticket to the app"
xcrun stapler staple "$APP_PATH"

echo ""
echo "==> Step 5: Verify"
spctl --assess --type execute --verbose "$APP_PATH"

echo ""
echo "==> Step 6: Create distributable DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname  "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo ""
echo "────────────────────────────────────────────────"
echo "  Done!  $DMG_PATH is ready to share."
echo "  Users can drag $APP_NAME.app to /Applications."
echo "────────────────────────────────────────────────"
