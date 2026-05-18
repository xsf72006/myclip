#!/usr/bin/env bash
# Install myclip into /Applications and register a LaunchAgent so it auto-starts at login.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="myclip"
SRC_APP="dist/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"
LABEL="com.myclip.agent"
PLIST_SRC="LaunchAgents/$LABEL.plist.template"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ ! -d "$SRC_APP" ]; then
    echo "ERROR: $SRC_APP not found. Run 'make build' first." >&2
    exit 1
fi

echo "==> copying $SRC_APP to $DEST_APP"
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

echo "==> writing $PLIST_DEST"
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__EXEC_PATH__|$DEST_APP/Contents/MacOS/$APP_NAME|g" "$PLIST_SRC" > "$PLIST_DEST"

echo "==> (re)loading LaunchAgent"
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo
echo "myclip is installed and running."
echo "  • Press ⌘⇧C to open it."
echo "  • Click the clipboard icon in the menu bar for settings."
echo "  • Uninstall with: make uninstall"
