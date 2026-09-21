#!/bin/bash
# Builds the Swift package and wraps the binary into a proper Island.app bundle
# (with Info.plist + ad-hoc code signature). Usage: ./build.sh [debug|release]
set -euo pipefail

APP_NAME="Island"
BUNDLE_ID="com.katemptiness.island"
CONFIG="${1:-debug}"

cd "$(dirname "$0")"

# Single source of truth for the version: AppInfo.version in main.swift.
VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' Sources/Island/main.swift)"
if [ -z "$VERSION" ]; then
    echo "✗ Could not read AppInfo.version from Sources/Island/main.swift" >&2
    exit 1
fi

# --- SDK selection ----------------------------------------------------------
# The macOS 26 SDK turns SwiftUI's @State (and friends) into macros whose
# compiler plugin, SwiftUIMacros, ships only with the full Xcode. With plain
# Command Line Tools the build dies with "plugin for module 'SwiftUIMacros' not
# found", so fall back to the newest installed SDK that still compiles a plain
# SwiftUI view. Probing costs a couple of seconds, so the answer is cached and
# only recomputed when the default SDK or the toolchain changes.

SDK_CACHE=".build/sdk-choice"

sdk_compiles() {
    local probe_dir status=0
    probe_dir="$(mktemp -d)"
    cat > "$probe_dir/probe.swift" <<'SWIFT'
import SwiftUI
struct Probe: View {
    @State private var flag = false
    var body: some View { Text(flag ? "yes" : "no") }
}
SWIFT
    swiftc -typecheck -sdk "$1" "$probe_dir/probe.swift" >/dev/null 2>&1 || status=1
    rm -rf "$probe_dir"
    return $status
}

pick_sdk() {
    local default_sdk sdk
    default_sdk="$(xcrun --show-sdk-path)"
    if sdk_compiles "$default_sdk"; then
        echo "$default_sdk"
        return 0
    fi
    while IFS= read -r sdk; do
        if sdk_compiles "$sdk"; then
            echo "$sdk"
            return 0
        fi
    done < <(find "$(dirname "$default_sdk")" -maxdepth 1 -name 'MacOSX*.sdk' -not -type l | sort -rV)
    return 1
}

if [ -z "${SDKROOT:-}" ]; then
    sdk_key="$(xcrun --show-sdk-path)|$(swift -version 2>&1 | head -1)"
    if [ -f "$SDK_CACHE" ] && [ "$(head -1 "$SDK_CACHE")" = "$sdk_key" ] \
       && [ -d "$(tail -1 "$SDK_CACHE")" ]; then
        SDKROOT="$(tail -1 "$SDK_CACHE")"
    else
        echo "▶︎ Looking for an SDK that can build SwiftUI…"
        if ! SDKROOT="$(pick_sdk)"; then
            echo "✗ None of the installed SDKs can compile SwiftUI with this toolchain." >&2
            echo "  Install the full Xcode — it ships the SwiftUIMacros compiler plugin." >&2
            exit 1
        fi
        mkdir -p "$(dirname "$SDK_CACHE")"
        printf '%s\n%s\n' "$sdk_key" "$SDKROOT" > "$SDK_CACHE"
        echo "▶︎ Using SDK: $(basename "$SDKROOT")"
    fi
    export SDKROOT
fi

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
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Island controls Apple Music playback.</string>
</dict>
</plist>
PLIST

echo "▶︎ Ad-hoc signing…"
codesign --force --sign - "$APP_DIR"

echo "✅ Built: $APP_DIR (v$VERSION)"
