#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
sh scripts/build-app.sh
source_bundle=.build/OpenRow.app
destination=/Applications/OpenRow.app
requirement=$(codesign -d -r- "$source_bundle" 2>&1)
case "$requirement" in
    *'certificate'*|*'anchor'*) ;;
    *) echo 'Installation requires a stable signing identity. See README.md.' >&2; exit 1 ;;
esac
if pgrep -f '^/Applications/OpenRow.app/Contents/MacOS/OpenRow$' >/dev/null; then
    echo 'Quit OpenRow from its menu before installing an update.' >&2
    exit 1
fi
if [ -e "$destination" ]; then
    installed_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$destination/Contents/Info.plist")
    [ "$installed_id" = dev.openrow.OpenRow ] || { echo 'Another app occupies the destination.' >&2; exit 1; }
    mkdir -p .build/install-backups
    mv "$destination" ".build/install-backups/OpenRow-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$source_bundle" "$destination"
codesign --verify --strict "$destination"
echo "Installed: $destination"
