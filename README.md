# OpenRow

A native macOS 26+ menu-bar utility for keyboard-driven clicking and scrolling. No network, account, screen capture, OCR, or runtime dependencies.

OpenRow stays in the menu bar without a Dock icon. Settings opens on demand; closing it leaves the service running. First launch shows skippable permission setup.

## Use

1. Open OpenRow from Applications and allow **Accessibility** and **Input Monitoring** in General. Use the exact System Settings links if needed, then **Restart Input**.
2. **Control–Option–Shift–Command–J** shows click hints. Type a hint to click its control once. Backspace edits; Escape cancels.
3. **Control–Option–Shift–Command–K** selects a scroll region. Hold H/J/K/L for left/down/up/right, Shift to dash, Tab to cycle, or 1–9 to select. Release to stop; Escape exits.

All configuration is in native Settings: shortcuts, label size, speed, dash multiplier, ignored apps, pause, launch at login, permissions, and privacy details. Unsupported apps may expose fewer targets. OpenRow cancels on app/display changes, secure input, pause, and input failure.

Hints default to compact 9-point labels and mix single, double, and longer codes without ambiguous prefixes. Clickable accessibility actions are recognized even when a popup exposes them as text. Scrolling uses writable accessibility scrollbars and content dimensions to preserve the pointer; regions that omit those controls report that precise scrolling is unavailable.

## Build and test

Requires macOS 26+, Xcode with Swift 6.2 or newer, and the active Xcode command-line tools.

```sh
swift test
sh scripts/build-app.sh
sh scripts/audit.sh
```

Bundles are produced at `.build/OpenRow.app` and `.build/OpenRowFixture.app`. The supplied `artwork/OpenRow.icon` is compiled with Xcode’s asset compiler. Builds stage fresh bundles and preserve old copies under `.build/bundle-backups/`, so rebuilding cannot modify executable pages mapped by a running app.

The fixture contains native controls, a click counter, two independently scrollable regions, and a local WebKit variant. Opt-in integration tests control only that disposable fixture and require Accessibility for the test host plus both permissions for the installed OpenRow app:

```sh
OPENROW_NATIVE_TESTS=1 swift test --filter NativeFlowTests
```

These tests move the pointer and send global fixture keys. Keep the test session in the foreground. They are skipped during ordinary tests and headless CI. Passing unit tests alone does not establish native click/scroll behavior or performance budgets.

Current local validation: native click/scroll and discovery tests pass. The WebKit precise-scroll integration test currently fails because the fixture's web regions do not expose writable scrollbars. Browser scrolling remains incomplete and is a merge blocker pending the v1 scope decision.

## Local installation and stable permissions

```sh
sh scripts/install-app.sh
```

The installer requires a stable code-signing identity, verifies the signature, and installs `/Applications/OpenRow.app`. Quit OpenRow before updating. Previous installed bundles remain in `.build/install-backups/`.

Set `OPENROW_SIGNING_IDENTITY` and optionally `OPENROW_SIGNING_KEYCHAIN` to an existing code-signing identity. On this development machine, the build script also recognizes the OpenRow local-development keychain under `~/.auth/openrow-signing/`; private keys and passwords never enter this repository. Without a configured identity, the build script produces an ad-hoc-signed bundle for temporary development, and installation refuses to imply stable permissions.

macOS identifies permission grants using the signed app’s designated requirement. Use the same certificate, bundle identifier, and Applications location across updates. Changing from an ad-hoc build to the stable signed build requires granting permissions to the new identity once. See [Apple’s code-signing requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

Local self-signing does not provide Developer ID distribution or notarization. A public release needs separate distribution signing and compatibility testing.

## Structure and privacy

`SPEC.md` owns behavior; `DESIGN.md` and `DESIGN.html` describe the accepted native interface. `Sources/OpenRow` separates deterministic domain state, input, AX discovery, overlay drawing, actions, Settings, and the app lifecycle. The input callback uses a bounded allow-list and never traverses AX or renders UI. AX handles remain inside one cancellable actor. The only recurring app timer runs while a scroll key is held.

Preferences stay in local `UserDefaults`. The app reads no UI titles for discovery and logs only counts, durations, and lifecycle status. No production code sends network requests or captures the screen. Local test evidence and app bundles are gitignored.
