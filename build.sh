#!/bin/bash
# Builds Clippy.app into ./build.
#   ./build.sh           build only
#   ./build.sh run       build + relaunch from ./build
#   ./build.sh install   build + install to /Applications + launch
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Clippy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Clippy "$APP/Contents/MacOS/Clippy"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force -s - "$APP" >/dev/null 2>&1

echo "Built $APP"

case "${1:-}" in
  run)
    pkill -x Clippy 2>/dev/null || true
    sleep 0.3
    open "$APP"
    echo "Clippy is running — press ⌘1 to open the bar."
    ;;
  install)
    pkill -x Clippy 2>/dev/null || true
    sleep 0.3
    rm -rf /Applications/Clippy.app
    cp -R "$APP" /Applications/Clippy.app
    open /Applications/Clippy.app
    echo "Installed to /Applications/Clippy.app and launched — press ⌘1."
    ;;
esac
