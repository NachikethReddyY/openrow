#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
for tool in swift codesign plutil; do
    command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
swift build -c release
binary_dir=$(swift build -c release --show-bin-path)
identity=${OPENROW_SIGNING_IDENTITY:--}
keychain=${OPENROW_SIGNING_KEYCHAIN:-}
local_signing="$HOME/.auth/openrow-signing"
if [ "$identity" = - ] && [ -f "$local_signing/openrow.keychain-db" ]; then
    identity='OpenRow Local Development'
    keychain="$local_signing/openrow.keychain-db"
    python3 - "$local_signing" <<'PY'
from pathlib import Path
import subprocess, sys
folder = Path(sys.argv[1])
subprocess.run(['security', 'unlock-keychain', '-p', (folder / 'keychain-password').read_text(),
                str(folder / 'openrow.keychain-db')], check=True, stdout=subprocess.DEVNULL)
PY
fi
for name in OpenRow OpenRowFixture; do
    staging=$(mktemp -d ".build/$name-stage.XXXXXX")
    bundle="$staging/$name.app"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
    cp "$binary_dir/$name" "$bundle/Contents/MacOS/$name"
    cp Resources/Info.plist "$bundle/Contents/Info.plist"
    if [ "$name" = OpenRowFixture ]; then
        plutil -replace CFBundleIdentifier -string dev.openrow.OpenRowFixture "$bundle/Contents/Info.plist"
        plutil -replace CFBundleExecutable -string OpenRowFixture "$bundle/Contents/Info.plist"
        plutil -replace CFBundleName -string OpenRowFixture "$bundle/Contents/Info.plist"
        plutil -replace CFBundleDisplayName -string 'OpenRow Fixture' "$bundle/Contents/Info.plist"
        plutil -replace LSUIElement -bool NO "$bundle/Contents/Info.plist"
    fi
    if [ -n "$keychain" ]; then
        codesign --force --sign "$identity" --keychain "$keychain" --options runtime "$bundle"
    else
        codesign --force --sign "$identity" --options runtime "$bundle"
    fi
    codesign --verify --strict "$bundle"
    plutil -lint "$bundle/Contents/Info.plist"
    # Never overwrite pages mapped by a running signed process. Preserve the old inode tree.
    if [ -e ".build/$name.app" ]; then
        mkdir -p .build/bundle-backups
        mv ".build/$name.app" ".build/bundle-backups/$name-$(date +%Y%m%d-%H%M%S)-$$.app"
    fi
    mv "$bundle" ".build/$name.app"
    rmdir "$staging"
    echo "Built and signed ($identity): .build/$name.app"
done
