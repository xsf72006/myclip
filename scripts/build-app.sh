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
# Single-arch build for the current machine. Users build locally, so a
# universal binary isn't worth hiding error output for.
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"

echo "==> assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN_PATH/$APP_NAME" "$MACOS/$APP_NAME"
cp "Bundle/Info.plist" "$CONTENTS/Info.plist"
if [ -f "Bundle/AppIcon.icns" ]; then
    cp "Bundle/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Bundle the brand fonts. Info.plist's ATSApplicationFontsPath=Fonts makes
# macOS auto-register everything under Contents/Resources/Fonts at launch.
if [ -d "Bundle/Fonts" ]; then
    cp -R "Bundle/Fonts" "$RESOURCES/Fonts"
fi

# Copy any SwiftPM-emitted resource bundles into Resources/ (the standard
# nested-bundle location). They must NOT go in Contents/MacOS/ — codesign
# --deep rejects a resource bundle sitting beside the main executable.
for bundle in "$BIN_PATH"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$RESOURCES/"
done

# Ad-hoc sign so Gatekeeper / TCC can identify the bundle stably.
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

echo "==> built $APP_BUNDLE"
