#!/bin/zsh
# Build Kuarasy (Debug) and launch it. Extra args go to the app, e.g.:
#   Scripts/run.sh --preview settings
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project Kuarasy.xcodeproj -scheme Kuarasy -configuration Debug \
  -derivedDataPath build -destination 'platform=macOS' build -quiet
pkill -x Kuarasy 2>/dev/null || true
sleep 0.3
APP="build/Build/Products/Debug/Kuarasy.app"
if (( $# > 0 )); then open -n "$APP" --args "$@"; else open "$APP"; fi
