# OpenRow build plan

This repository now contains a build-ready plan for a native macOS 26+ keyboard-driven pointer and scrolling utility. No application code has been created in this planning thread.

## Recommended direction

- Build one native Swift 6 macOS app with SwiftUI Settings and AppKit overlays.
- Target macOS 26.0 and use standard system controls so Liquid Glass adapts automatically on macOS 27; isolate every 27-only refinement behind availability checks.
- Treat Caps Lock-to-Hyper as an external remapping. Record the resulting Control–Option–Shift–Command chord and allow every shortcut to be edited live.
- Ship label-only Click mode (`Hyper–J`) and H/J/K/L Scroll mode (`Hyper–K`) first.
- Discover targets through the macOS accessibility tree, retain focus in the frontmost app, render one nonactivating overlay per display, and use Quartz events for the visible pointer move/click and scrolling.
- Keep all processing local, no telemetry/account/network dependency, no runtime packages, and distribute a hardened Developer ID–signed/notarized build directly.
- Implement clean-room from public behavior and Apple APIs; use distinct OpenRow branding and assets.

## Build order

1. **Signed feasibility tracer:** prove Accessibility + Input Monitoring, fail-open global input, one AX target/overlay/click, and one scroll event on macOS 26.
2. **Deterministic core + fixture:** write tests first for hint assignment, shortcuts, state transitions, target filtering, coordinate conversion, and scroll math; create a dense external fixture app.
3. **Click vertical slice:** wire AX scan → unique home-row hints → prefix filter → target revalidation → one pointer click across displays.
4. **Scroll vertical slice:** wire scroll-region discovery → selected outline → repeat-aware H/J/K/L events → region switching → safe exit.
5. **Native shell + settings:** add menu bar, permission onboarding, live shortcut recorder, behavior panes, ignored apps, launch at login, and privacy-safe diagnostics.
6. **Release hardening:** run the app/input/display/accessibility matrix, measure latency, test first run in a fresh VM, choose/add the license, sign/notarize, and create the reproducible release artifact.

## Quality gates

- Input is pass-through by default; Escape, app/display change, permission loss, event-tap disable, and stale targets cancel without leaving keys trapped.
- A completed hint moves the pointer inside the revalidated target and sends exactly one down/up pair.
- U.S., Dvorak, and Japanese IME tests validate physical home-row handling.
- Retina/non-Retina and negative-origin multi-display tests validate overlay/click coordinates.
- For a warm 100-target snapshot over 30 runs: first-paint p50 ≤ 150 ms, p95 ≤ 300 ms, with no unexplained run above 750 ms.
- Settings passes Full Keyboard Access, VoiceOver, light/dark, larger text, Reduce Transparency/Motion, Increase Contrast, and macOS 27 Show Borders when a 27 environment is available.
- A network-denied run works and code/log review confirms that raw keys, AX strings, window titles, and usage history are neither persisted nor sent.

## Handoff files

- `SPEC.md` — complete behavior, architecture, invariants, acceptance criteria, tests, and slice definitions.
- `DESIGN.md` — native visual system, exact measurements, colors, states, HIG/accessibility requirements, and macOS 26→27 policy.
- `RESEARCH.md` — HomeRow behavioral research, Apple API/HIG evidence, feasibility risks, source links, and limits.
- `artifacts/openrow-plan.html` — local interactive visual plan with three controlled design treatments and click/scroll/onboarding mockups.

## Approval gate

The proposed implementation baseline is **Native Quiet + MIT license + direct Developer ID distribution**. If that baseline is accepted, a new thread can start with the signed feasibility tracer without reopening product discovery. Search mode, click chaining, OCR/grid navigation, and Mission Control remain post-v1 decisions.
