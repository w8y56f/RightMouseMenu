#!/bin/bash
# Builds a Release RightMouseMenu.app and packages it as .build/release/RightMouseMenu-<version>[-<arch>].dmg
# The arch label is "universal" only when the binary really contains both arm64 and x86_64; otherwise the label is
# the single architecture found. Prints the dmg path on the last line.
set -euo pipefail
cd "$(dirname "$0")/.."

out=".build/release"
rm -rf "$out"
mkdir -p "$out"

xcodebuild -quiet -project RightMouseMenu.xcodeproj -scheme RightMouseMenu -configuration Release \
    -destination "generic/platform=macOS" ONLY_ACTIVE_ARCH=NO -derivedDataPath "$out/DerivedData" build
app="$PWD/$out/DerivedData/Build/Products/Release/RightMouseMenu.app"
appex="$app/Contents/PlugIns/RightMouseMenuFinderSync.appex"

archs() { lipo -archs "$1/Contents/MacOS/$(basename "${1%.*}")"; }
app_archs=$(archs "$app")
ext_archs=$(archs "$appex")
if [ "$app_archs" != "$ext_archs" ]; then
    echo "App ($app_archs) and extension ($ext_archs) architectures differ." >&2
    exit 1
fi
case "$app_archs" in
    *arm64*x86_64* | *x86_64*arm64*) label="-universal" ;;
    *) label="" ;;
esac

plist="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
revision=$(/usr/libexec/PlistBuddy -c "Print :GitRevision" "$plist" 2>/dev/null || true)
echo "Version $version ($revision), architectures: $app_archs" >&2

codesign --verify --deep --strict "$app"
# Building registers this copy's extension with PlugInKit, where it would compete with an installed copy
# that has the same identifier. Only the installed app should provide the Release extension.
pluginkit -r "$appex" || true

stage="$out/dmg-stage"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
dmg="$out/RightMouseMenu-$version$label.dmg"
hdiutil create -quiet -volname "RightMouseMenu $version" -srcfolder "$stage" -format UDZO -ov "$dmg"
rm -rf "$stage"
echo "$PWD/$dmg"
