#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
python3 - <<'PY'
from pathlib import Path
import plistlib, re
sources = list(Path('Sources/OpenRow').rglob('*.swift'))
for path in sources:
    text = path.read_text()
    for forbidden in ['URLSession', 'ScreenCaptureKit', 'CGWindowListCreateImage', 'AVCapture', 'NSLog(', 'print(']:
        assert forbidden not in text, f'{path}: prohibited runtime API {forbidden}'
    assert not re.search(r'[\U0001F300-\U0001FAFF]', text), f'{path}: emoji interface icon'
    assert 'Timer.scheduledTimer' not in text, f'{path}: recurring timer needs explicit active-mode ownership'
info = plistlib.loads(Path('Resources/Info.plist').read_bytes())
assert info['LSUIElement'] is True
assert info['CFBundleIdentifier'] == 'dev.openrow.OpenRow'
assert 'WindowGroup' not in Path('Sources/OpenRow/App/OpenRowApp.swift').read_text()
print(f'PASS: {len(sources)} app source files; local-only API audit, SF Symbols-only icon checks, accessory bundle, no routine WindowGroup.')
print('Runtime privacy, idle CPU, input timing, and accessibility still require native observation.')
PY
