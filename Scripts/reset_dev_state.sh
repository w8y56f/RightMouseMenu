#!/bin/bash
# Resets RightMouseMenu's macOS state so the next launch behaves like a first install.
# Targets the development build (.dev identity) unless --installed is given.
#   (no flag)    permissions only: Automation (TCC), Finder extension election, registered extension copies
#   --full       also deletes settings and the Finder request folder (and .build for the development build)
#   --installed  reset the installed/Release identity instead of the development one
#   --dry-run    print the commands instead of running them
# Never touches other apps. Deleting /Applications/RightMouseMenu.app is left to the caller.
set -uo pipefail
cd "$(dirname "$0")/.."

full=0 dry=0 installed=0
for arg in "$@"; do
    case "$arg" in
        --full) full=1 ;;
        --installed) installed=1 ;;
        --dry-run) dry=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

# Must match Scripts/generate_project.py and SharedSettings.swift.
if [ "$installed" = 1 ]; then
    app_id="com.stone.rightmousemenu"
    suite="com.stone.RightMouseMenu.shared"
    support="RightMouseMenu"
else
    app_id="com.stone.rightmousemenu.dev"
    suite="com.stone.RightMouseMenu.dev.shared"
    support="RightMouseMenu Dev"
fi
ext_id="$app_id.findersync"
echo "Resetting $app_id"

run() {
    echo "+ $*"
    [ "$dry" = 1 ] || "$@" || echo "  (failed, continuing)"
}

# Stop the app and the extension so nothing re-registers or rewrites settings while we reset.
run osascript -e "if application id \"$app_id\" is running then tell application id \"$app_id\" to quit"

# Privacy permissions (Automation and anything else TCC recorded).
run tccutil reset All "$app_id"
run tccutil reset All "$ext_id"

# Finder extension: forget the user's enable choice (shared by every copy with this identifier)
# and unregister every copy PlugInKit knows about.
run pluginkit -e default -i "$ext_id"
while IFS= read -r path; do
    [ -n "$path" ] || continue
    # Only this identity's extension process; the other identity keeps running.
    run pkill -f "$path/Contents/MacOS/RightMouseMenuFinderSync"
    run pluginkit -r "$path"
done < <(pluginkit -m -A -D -v -i "$ext_id" | awk -F'\t' 'NF > 1 { print $NF }')

if [ "$full" = 1 ]; then
    # Settings: the app's own defaults and the suite shared with the extension.
    run defaults delete "$app_id"
    run defaults delete "$suite"
    run rm -rf "$HOME/Library/Application Support/$support"
    if [ "$installed" = 0 ]; then
        # Old SwiftPM-run domain, and build output (PlugInKit can rediscover extensions still on disk).
        run defaults delete RightMouseMenu
        run rm -rf .build
    fi
fi

run killall Finder

echo
echo "Remaining registrations for $ext_id:"
pluginkit -m -A -D -v -i "$ext_id"
