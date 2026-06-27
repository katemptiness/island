#!/bin/bash
# Builds the Swift package and wraps the binary into a proper Island.app bundle
# (with Info.plist + ad-hoc code signature). Usage: ./build.sh [debug|release]
set -euo pipefail

APP_NAME="Island"
BUNDLE_ID="com.katemptiness.island"
CONFIG="${1:-debug}"

cd "$(dirname "$0")"

echo "▶︎ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="$BIN_PATH/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "▶︎ Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_PATH/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Island controls Apple Music playback.</string>
</dict>
</plist>
PLIST

echo "▶︎ Ad-hoc signing…"
codesign --force --sign - "$APP_DIR"

echo "✅ Built: $APP_DIR"
