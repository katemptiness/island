#!/bin/bash
# Builds Island in release mode and installs it into /Applications, so it can be
# launched from Spotlight or the Finder. Usage: ./install.sh
set -euo pipefail

APP_NAME="Island"
DEST_DIR="/Applications"

cd "$(dirname "$0")"

./build.sh release

SRC_APP="$(swift build -c release --show-bin-path)/$APP_NAME.app"
DEST_APP="$DEST_DIR/$APP_NAME.app"

if [ ! -d "$SRC_APP" ]; then
    echo "✗ Nothing to install: $SRC_APP is missing" >&2
    exit 1
fi

echo "▶︎ Installing to ${DEST_APP}…"
killall "$APP_NAME" 2>/dev/null || true
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

# Copying can invalidate an ad-hoc signature, so sign the installed copy in place.
codesign --force --sign - "$DEST_APP"

echo "▶︎ Launching…"
open "$DEST_APP"
echo "✅ Installed: $DEST_APP"
