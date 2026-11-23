#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -quiet -project RightMouseMenu.xcodeproj -scheme RightMouseMenu -configuration Debug -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath .build/DerivedData build
app="$PWD/.build/DerivedData/Build/Products/Debug/RightMouseMenu.app"
pluginkit -a "$app/Contents/PlugIns/RightMouseMenuFinderSync.appex"
if ! pluginkit -m -i com.stone.rightmousemenu.findersync | grep -q 'com.stone.rightmousemenu.findersync'; then
    printf '%s\n' 'macOS did not register the RightMouseMenu Finder extension.' >&2
    exit 1
fi
while read -r pid; do
    kill -TERM "$pid"
    for _ in {1..30}; do
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.1
    done
done < <(ps -axo pid=,command= | awk -v app="$app/Contents/MacOS/RightMouseMenu" '{ pid=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); if ($0==app) print pid }')
open "$app"
