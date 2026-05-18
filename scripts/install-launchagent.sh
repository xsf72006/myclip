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
UID_NUM="$(id -u)"
launchctl bootout  "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST_DEST"

# Force LaunchServices to re-index the bundle so the icon refreshes
# immediately in Finder / System Settings (otherwise needs a logout).
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

echo
echo "myclip is installed and running."
echo "  • Press ⌘⇧C to open it."
echo "  • Click the clipboard icon in the menu bar for settings."
echo "  • Uninstall with: make uninstall"
