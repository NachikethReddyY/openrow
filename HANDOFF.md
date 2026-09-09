# OpenRow implementation handoff

Date: 2026-09-09  
Branch: `t3code/create-optimized-macos-app`  
Worktree: `/Users/nr/.t3/worktrees/OpenRow/t3code-e6c5531e`

## Requested outcome

Build the app specified at `https://f8ud3zs4u4rf.postplan.dev` as a highly optimized native macOS utility.

Active contract:

> Outcome: a working native OpenRow menu-bar utility | Allowed changes: this worktree | Protected behavior: the supplied plan plus the user's lifecycle, Settings, and icon corrections | Proof: focused tests, release build, and direct macOS UI/behavior inspection | Stop when: the app runs locally, its core click/scroll flows work, the background lifecycle is observed, and focused checks pass.

The user subsequently requested one local commit of this foundation. No push, PR, publishing, Developer ID signing, or notarization was requested. Keep all further work local unless the user explicitly expands authority.

## Source reference

The supplied URL is a product/build specification, not an existing codebase. The full raw artifact was fetched per the `postplan-read` skill with:

```sh
curl --fail --silent --show-error --location --max-time 30 \
  --output /tmp/postplan.html \
  'https://f8ud3zs4u4rf.postplan.dev/raw'
```

Fetch it again if `/tmp/postplan.html` no longer exists. Do not use web search to retrieve the Postplan artifact.

The plan selects this v1:

- Native SwiftUI Settings and AppKit overlays.
- Accessibility (`AXUIElement`) discovery and revalidation.
- Quartz event tap/posting for global input, pointer click, and scroll.
- Hyper-J click mode and Hyper-K scroll mode.
- No search, OCR, screen capture, grid navigation, chain clicks, Mission Control automation, networking, account, or analytics.
- Direct distribution is a future release step; Mac App Store is out of scope.

## User corrections — protected

These are product-specific guidance and are already recorded in `SPEC.md` and `DESIGN.md`:

1. OpenRow must be a menu-bar background utility with no Dock icon and no routine app window.
2. Settings/onboarding is on demand, except onboarding may appear once on first launch for permissions.
3. Closing Settings must leave the lightweight service running.
4. Idle work must be event-driven with no polling loop.
5. Every editable option must be available in the native app interface shown in the plan; users must never need to edit a file or use Terminal.
6. Use SF Symbols for all interface icons. Do not use emoji, Unicode icon stand-ins, third-party icon packs, or custom-drawn interface icons.

The expected Settings sidebar is General, Shortcuts, Clicking, Scrolling, Ignored Apps, and About. It must expose editable shortcuts, click-label size, scroll speed/dash behavior, ignored apps, launch at login, permissions/repair, and About/privacy details.

## Repository and prerequisites observed

- The repository began with only `README.md` (`# openrow`).
- Current branch is dedicated to this task: `t3code/create-optimized-macos-app`.
- The task began at baseline commit `4904355 first commit`; the files described here are included in the branch's local foundation commit.
- Xcode: 26.6 (`17F113`).
- Swift: 6.3.3, arm64 Apple Silicon.
- Host: macOS 26.6.2.
- `xcodegen`, `swiftformat`, `swiftlint`, and `xcbeautify` were not found.
- A dependency-free Swift Package was chosen so the project builds immediately without installing tooling. A later bundling script still needs to assemble and ad-hoc-sign `OpenRow.app` for local testing.

Before editing, re-run `git status --short` and preserve any later user changes.

## Skills already applied

- `postplan-read`: raw Postplan artifact retrieval.
- `interface-design`: the main skill and all relevant native-interface references were read. Its important remaining requirement is to create `DESIGN.html` as visual proof synchronized with `DESIGN.md`, then verify the real UI.

The reference already settles the high-fidelity direction as “Native Quiet,” so alternate mocks are unnecessary. SF Symbols and the background/settings corrections further settle the direction.

## Current implementation

Planning and contract files:

- `SPEC.md` — behavioral, safety, privacy, persistence, and performance authority.
- `DESIGN.md` — accepted native visual/interaction system and SF Symbols map.
- `TODO.md` — task checklist.
- `Package.swift` — macOS 26, Swift 6, no package dependencies; app, fixture, and test targets.
- `.gitignore` — excludes builds, app bundles, artifacts, and evidence.

Deterministic core implemented under `Sources/OpenRow/Domain/`:

- `HintModel.swift`
  - Physical A/S/D/F/G/H/J/K/L keys.
  - Fixed-length base-9 codes: 1 key through 9, 2 through 81, 3 through 729.
  - Prefix matching/dimming/selection states.
- `InputModel.swift`
  - Typed key codes and modifiers.
  - Persistable physical-key shortcuts.
  - Constant-time allow-list routing for idle/click/scroll modes.
  - Activation, key-up, auto-repeat, region selection, and synchronous fail-open tap-disable behavior.
- `Geometry.swift`
  - Quartz-to-Cocoa and per-screen coordinate conversion, including negative-origin displays.
  - H/J/K/L scroll vectors and dash multiplier.
- `ShortcutValidator.swift`
  - Rejects unmodified, incomplete, reserved, or colliding shortcuts.

`Sources/OpenRow/OpenRowBuild.swift` and `Sources/OpenRowFixture/OpenRowFixtureBuild.swift` are temporary target placeholders, not app implementations.

Tests under `Tests/OpenRowTests/` cover hint boundaries/uniqueness/filtering, idle pass-through, activation consumption, click/scroll allow lists, auto-repeat, mode switching, tap failure, geometry, scroll direction, and shortcut validation.

## Verification observed

Latest command:

```sh
swift test
```

Observed result: **18 tests passed, 0 failures** on 2026-09-09. The deterministic core is implemented and green.

No native app shell, permission flow, event tap, AX traversal, overlay, click/scroll posting, fixture, app bundle, or UI verification exists yet. Do not claim the app is working until those are implemented and directly observed.

## Recommended continuation order

Keep tests ahead of each behavior and use `apply_patch` for edits.

1. Add typed `UserPreferences` plus an injectable `UserDefaults` store and tests. Persist both shortcuts, hint size, scroll speed, dash multiplier, ignored bundle IDs, paused state, launch-at-login intent, and onboarding completion.
2. Implement the background shell:
   - `@main` SwiftUI app with `MenuBarExtra`.
   - accessory activation policy and `LSUIElement = true` in the final app bundle.
   - no `WindowGroup` that opens on ordinary launches.
   - AppKit-owned Settings and onboarding windows shown only on request/first run.
3. Build the full native Settings UI before calling configuration complete. Use `NavigationSplitView`, native `Form`/`Section`/controls, and only the SF Symbol names governed by `DESIGN.md`.
4. Add permission adapters:
   - `AXIsProcessTrustedWithOptions` for Accessibility.
   - `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` for Input Monitoring.
   - exact System Settings repair links.
   - refusal as a stable state with no repeated prompt loop.
5. Implement the global event tap around the existing pure `InputRouter`:
   - callback does only key extraction, locked router mutation, and async command delivery.
   - unrelated keys return the original event.
   - tap-disable sets router idle synchronously, passes the event through, clears overlays, and does not retry inside the callback.
   - no key values in logs.
6. Implement one serialized/cancellable AX service:
   - scan only the frontmost external PID; exclude OpenRow and ignored bundle IDs.
   - begin at the focused window when possible.
   - use bounded breadth-first traversal and preferably `AXUIElementCopyMultipleAttributeValues` to reduce IPC.
   - keep AX elements inside the actor and return Sendable target snapshots.
   - store element handles by ID for revalidation.
   - reject hidden, disabled, duplicate, nonfinite, offscreen, and unsupported targets.
7. Implement actions and reusable overlays:
   - one nonactivating, click-through AppKit panel per display, reused between modes.
   - one layer-backed custom drawing view per panel; no per-hint windows.
   - translate AX/Quartz top-left coordinates to AppKit coordinates with `ScreenGeometry`.
   - opaque yellow hint labels; blue exact-match outline; no dimmed screen.
   - 2-point blue inset scroll outline, number badge, and compact instructions.
   - revalidate PID/state/frame/intersection before a single pointer move + left down/up pair.
   - scroll via pixel events located in the selected region without moving the pointer; stop on key-up.
8. Add the native/WebKit fixture target for dense controls and nested scrolling, then test real click/scroll behavior.
9. Add `scripts/build-app.sh`, `Resources/Info.plist`, and any required entitlements. Assemble `.build/OpenRow.app`, set the bundle identifier and `LSUIElement`, copy the release binary, and ad-hoc sign for local use. Do not claim Developer ID signing/notarization.
10. Create `DESIGN.html` synchronized with `DESIGN.md`.
11. Run `swift test`, release build, static privacy/SF Symbols audits, and direct UI checks. Store useful screenshots under `.evidence/openrow/` (gitignored).

## Implementation details already decided

- Track the last frontmost non-OpenRow application so menu-bar activation still targets the user's app.
- Cancel active modes on frontmost-app change, display change, pause, secure input, or tap failure.
- Use `IsSecureEventInputEnabled()` before action modes; uncertain secure contexts pass keyboard input through.
- Translate physical home-row keys for display with the active keyboard layout (Carbon/TIS), falling back safely for IMEs while matching physical key codes.
- Use `SMAppService.mainApp` for launch at login and report its real status; it requires a signed app bundle.
- Use `OSLog`/signposts only for counts, durations, mode/status, and error categories.
- Avoid idle timers. A display-linked or dispatch timer is allowed only while a scroll key is actively held and must be cancelled on key-up/mode exit.
- Keep the overlay out of accessibility/window cycling; announce mode and recovery using native accessibility notifications without exposing scanned UI strings.

## Direct UI proof required

Use the shared native computer-control surface after building the `.app`. Confirm all of the following rather than substituting compilation or type checks:

- First launch shows permission-first onboarding once.
- Closing onboarding/Settings leaves the menu-bar item present.
- OpenRow has no Dock icon and no ordinary window while idle.
- Settings reopens from the menu and every promised preference is editable there.
- Sidebar/menu/status/action icons are actual SF Symbols, with visible labels where meaning is not universally familiar.
- Permission refusal has a clear repair action and no alert loop.
- With permissions granted, Hyper-J labels a fixture control and selects it exactly once.
- Hyper-K selects a fixture scroll region; H/J/K/L direction, Shift dash, Tab/number traversal, key-up stop, and Escape work without focus change.
- Tap disable/pause/app switch/display change removes overlays and leaves ordinary keyboard input usable.

If TCC permissions or signing prevent the end-to-end checks, report the exact blocked proof as unverified; do not weaken the completion claim.
