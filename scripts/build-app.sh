#!/usr/bin/env bash
# Build a release binary and bundle it into a .app at dist/myclip.app
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="myclip"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> swift build -c release"
swift build -c release --arch arm64 --arch x86_64 2>/dev/null \
    || swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN_PATH/$APP_NAME" "$MACOS/$APP_NAME"
cp "Bundle/Info.plist" "$CONTENTS/Info.plist"

# Copy SwiftPM-emitted resource bundles (e.g. KeyboardShortcuts assets) next to the binary.
for bundle in "$BIN_PATH"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$MACOS/"
done

# Ad-hoc sign so Gatekeeper / TCC can identify the bundle stably.
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

echo "==> built $APP_BUNDLE"
