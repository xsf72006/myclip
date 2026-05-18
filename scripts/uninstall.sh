#!/usr/bin/env bash
set -euo pipefail

LABEL="com.myclip.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ -f "$PLIST" ]; then
    echo "==> unloading LaunchAgent"
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
fi

if [ -d "/Applications/myclip.app" ]; then
    echo "==> removing /Applications/myclip.app"
    rm -rf "/Applications/myclip.app"
fi

echo
echo "myclip uninstalled."
echo "Your history at ~/Library/Application Support/myclip was left in place."
echo "Remove it manually if you want a clean slate."
