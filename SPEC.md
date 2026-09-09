# OpenRow behavioral specification

## Outcome

OpenRow is a native, local-only macOS menu-bar utility that lets a user reveal reachable controls and choose one with short physical home-row hints, or select and scroll a visible region with H/J/K/L.

## Runtime contract

- OpenRow runs as an accessory/background app with a menu-bar item and no Dock icon.
- No ordinary window opens during routine launches. On first launch, onboarding may appear once to explain required permissions.
- Settings opens only when requested. Closing Settings never stops the background utility.
- Idle operation is event-driven: no polling timer, display capture, OCR, network request, analytics, or account.
- Pausing or an input-tap failure removes every overlay and passes all keyboard input through.

## Click mode

1. Hyper-J (`Control-Option-Shift-Command-J`) toggles click mode globally.
2. OpenRow reads finite, visible, enabled controls from the frontmost app's accessibility tree without changing focus.
3. Targets are sorted by display, vertical position, then horizontal position and receive one fixed-length base-9 code from physical A/S/D/F/G/H/J/K/L positions.
4. One key is used for up to 9 targets, two for up to 81, and three for up to 729.
5. Labels use the active keyboard layout's characters while matching physical key positions.
6. Typing filters labels. Backspace removes one key. Escape or Hyper-J cancels immediately.
7. A completed code is revalidated against the original process, enabled state, frame, and visible displays. A stale target cancels.
8. A valid target moves the pointer to its center and posts exactly one left-button down/up pair.

Only activation keys, hint keys, Backspace, and Escape are consumed. Unrelated keys pass through.

## Scroll mode

1. Hyper-K toggles scroll mode globally.
2. OpenRow discovers visible accessibility scroll/web regions, selects the first in deterministic geometry order, and draws a 2-point blue inset outline plus a number badge.
3. H/J/K/L scroll left/down/up/right at the selected region without moving the pointer. Shift increases speed.
4. Key-up stops movement immediately. Tab cycles regions; number keys select regions 1–9.
5. Escape, Hyper-K, frontmost-app change, display change, pause, secure input, or input-tap failure exits.

Only the scroll-mode control keys are consumed. Unrelated keys pass through.

## Safety and permissions

- Accessibility is required to discover and revalidate UI targets.
- Input Monitoring is required for the global event tap.
- Permission refusal is a stable supported state with one action opening the exact System Settings pane.
- The event-tap callback performs bounded routing only. It never traverses accessibility data or waits on another thread.
- Tap-disable notifications synchronously return routing to idle, remove overlays, and require explicit repair instead of retrying in the callback.
- Secure input, ignored apps, OpenRow-owned UI, invalid geometry, more than 729 click targets, and uncertain targets fail closed for actions and open for unrelated keyboard input.
- Logs may contain counts, durations, status, and error categories only—never raw keys, labels, UI strings, window titles, or account data.

## Persistence

Typed preferences in `UserDefaults` contain shortcuts, click-label size, scroll speed, dash multiplier, onboarding completion, pause state, and ignored bundle identifiers. There is no document or cloud state.

Every user-editable preference has a native control in the on-demand Settings interface. Configuration never depends on editing a file or running a Terminal command. Shortcut recording rejects incomplete, unmodified, reserved, or colliding chords without discarding the previously valid shortcut.

## Performance budgets

- Idle: no recurring application timer and effectively zero CPU outside system notifications/event-tap callbacks.
- Warm discovery: for 100 targets over 30 runs, first overlay paint p50 <= 150 ms and p95 <= 300 ms; no unexplained run above 750 ms.
- Input callback: constant-time route lookup with no AX call, allocation-heavy rendering, or synchronous dispatch.
- Overlay: one reusable nonactivating panel per display; one layer-backed drawing view per panel; no per-hint window.
- Scans: one serialized, cancellable AX traversal capped by node count and supported target count.

## Out of scope for v1

Search, chained clicks, OCR, screen capture, grid navigation, Mission Control automation, remote services, a Mac App Store build, and claims of universal control coverage.
