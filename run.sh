#!/bin/bash
# Builds and (re)launches Island. Usage: ./run.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
cd "$(dirname "$0")"

./build.sh "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▶︎ Restarting Island…"
killall Island 2>/dev/null || true
open "$BIN_PATH/Island.app"
echo "✅ Island запущен (иконка появится в меню-баре)"
