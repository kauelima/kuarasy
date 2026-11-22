#!/bin/zsh
# Build a universal Release copy of Kuarasy and package it as
# dist/Kuarasy-<version>.dmg: the app on the left and an Applications shortcut on
# the right, over the day-to-night background in Scripts/dmg/. The version comes
# from MARKETING_VERSION.
#
# Finder lays out the window, so the DMG window opens and closes on its own while
# this runs, and the first run asks to let your terminal control Finder.
#   Scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VOLUME="Kuarasy"
MOUNT="/Volumes/$VOLUME"
# Window content size and icon centres. Must match Scripts/dmg/background.swift.
WIDTH=640 HEIGHT=400 TITLE_BAR=32
APP_X=160 APPLICATIONS_X=480 ICONS_Y=185

if [[ -e "$MOUNT" ]]; then
  echo "Eject the $VOLUME disk first, so the new one can mount under that name." >&2
  exit 1
fi

xcodebuild -project Kuarasy.xcodeproj -scheme Kuarasy -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' build -quiet
APP="build/Build/Products/Release/Kuarasy.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")

# What goes on the disk. The background sits in a hidden folder: Finder won't use
# a hidden file at the top of the disk as a window background.
WORK="build/dmg"
rm -rf "$WORK"
mkdir -p "$WORK/stage/.background"
ditto "$APP" "$WORK/stage/Kuarasy.app"
ln -s /Applications "$WORK/stage/Applications"
tiffutil -cathidpicheck Scripts/dmg/background.png Scripts/dmg/background@2x.png \
  -out "$WORK/stage/.background/background.tiff" 2>/dev/null
ICNS="$APP/Contents/Resources/AppIcon.icns"
[[ -f "$ICNS" ]] && cp "$ICNS" "$WORK/stage/.VolumeIcon.icns"

# A writable image, with some room for the layout file Finder writes.
SIZE=$(( $(du -sm "$WORK/stage" | cut -f1) + 20 ))
hdiutil create -srcfolder "$WORK/stage" -volname "$VOLUME" -fs HFS+ -format UDRW \
  -size "${SIZE}m" "$WORK/rw.dmg" -quiet
DEVICE=$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen | awk '/Apple_HFS/ {print $1}')
trap 'hdiutil detach "$DEVICE" -force -quiet 2>/dev/null || true' EXIT
[[ -f "$MOUNT/.VolumeIcon.icns" ]] && xcrun SetFile -a C "$MOUNT"

osascript <<EOF
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set bounds of container window to {200, 120, $((200 + WIDTH)), $((120 + HEIGHT + TITLE_BAR))}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set label position of viewOptions to bottom
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "Kuarasy.app" to {$APP_X, $ICONS_Y}
    set position of item "Applications" to {$APPLICATIONS_X, $ICONS_Y}
    set extension hidden of item "Kuarasy.app" to true
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF

# Wait for Finder to save the layout, then tidy up and eject.
for _ in {1..20}; do [[ -f "$MOUNT/.DS_Store" ]] && break; sleep 0.5; done
[[ -f "$MOUNT/.DS_Store" ]] || { echo "Finder didn't save the window layout." >&2; exit 1; }
rm -rf "$MOUNT/.fseventsd"
sync
for _ in {1..5}; do hdiutil detach "$DEVICE" -quiet && break; sleep 2; done
[[ -e "$MOUNT" ]] && { echo "Couldn't eject $MOUNT." >&2; exit 1; }
trap - EXIT

mkdir -p dist
DMG="dist/Kuarasy-$VERSION.dmg"
rm -f "$DMG"
hdiutil convert "$WORK/rw.dmg" -format ULFO -o "$DMG" -quiet

echo
echo "Built $DMG"
echo "To publish it as a new GitHub release:"
echo "  gh release create v$VERSION $DMG --title \"Kuarasy $VERSION\""
