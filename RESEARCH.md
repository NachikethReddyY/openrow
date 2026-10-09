# OpenRow research

Status: planning evidence, researched 9 September 2026. No implementation was inspected or copied from HomeRow.

## Questions answered

### What behavior is worth preserving?

HomeRow's public documentation describes two useful interaction loops:

1. Click navigation: activate globally, discover accessible UI elements, label them, narrow or focus a target from the keyboard, then click it.
2. Scroll navigation: activate a scroll mode, select a scroll area, use H/J/K/L for direction, Shift for a faster dash, numbers or traversal keys to switch regions, and Escape to exit.

Its current public UI and changelog add important hardening requirements: alternative keyboard layouts, Chromium-specific accessibility-tree behavior, non-focus-stealing activation, overlays that remain above targets, multi-display/Mission Control behavior, shortcut recording with a Hyper chord, ignored applications, click chaining, and feedback sounds. These are evidence for what can go wrong, not a commitment to clone all features in v1.

### Which macOS APIs fit the job?

- `AXUIElement` is the public macOS client API for assistive applications to inspect and control accessible elements in other apps. `AXIsProcessTrustedWithOptions` checks trust and can ask macOS to present its permission flow.
- `CGEventTapCreate` can observe or filter global keyboard events. Apple exposes `CGPreflightListenEventAccess` and `CGRequestListenEventAccess` for Input Monitoring. A tap that becomes unresponsive can be disabled by the system, so OpenRow needs an explicit fail-open path and re-enable policy.
- `CGEvent` can construct mouse and scrolling events, and `post(tap:)` inserts them into the event stream. This supports the requested visible pointer move plus mouse-down/up click and pixel-based scroll events.
- A borderless, nonactivating `NSPanel` can present an overlay without making OpenRow the active app. One transparent panel per display avoids a single-window coordinate and Spaces boundary.
- `SMAppService.mainApp` is the supported launch-at-login mechanism.

### What permissions and distribution model follow?

OpenRow needs Accessibility permission to read cross-app accessibility trees and control the pointer/click path, plus Input Monitoring to hear and suppress global mode keystrokes. Permission state must be capability-checked rather than inferred from a settings toggle. The plan uses direct Developer ID signing and notarization, Hardened Runtime, and no App Sandbox for the initial open-source distribution. Cross-app AX behavior and Mac App Store policy are a poor fit for making a sandboxed App Store build the v1 path; this can be re-evaluated only after a signed feasibility spike.

The onboarding copy must say exactly why each permission is required and that all UI inspection stays on the Mac. Refusal is supported: Settings remains usable, no repeated prompt loop occurs, and the user gets an explicit Open System Settings action.

### How should Liquid Glass be used on macOS 26 and 27?

Apple's guidance is to get Liquid Glass primarily from standard SwiftUI/AppKit structures and to use custom glass sparingly. Standard toolbars, sidebars, lists, buttons, and controls adapt automatically. Custom glass is reserved for a real control layer, and `GlassEffectContainer` should group multiple glass effects for rendering efficiency.

OpenRow therefore uses native Liquid Glass in the settings/sidebar chrome, but not as the default hint-label background. Click hints sit over arbitrary light, dark, and colorful content; a compact opaque yellow label with black text and a dark keyline is more reliably legible. The scroll target uses a blue border plus a numbered badge. Reduce Transparency, Increase Contrast, Reduce Motion, and macOS 27's Show Borders environment must retain structure without depending on refraction.

Apps built against the macOS 26 design automatically gain several macOS 27 Liquid Glass refinements. OpenRow should compile and test with Xcode 26 first, wrap any 27-only refinements in availability checks, and avoid copying private rendering behavior. Forward compatibility is a test obligation, not a claim that can be proven on the macOS 26 machine alone.

### What does Apple guidance imply for the settings experience?

- Provide Settings from the App menu and Command-Comma.
- Keep defaults strong and the number of settings small.
- Use a stable, noncustomizable navigation area, restore the last pane, and reflect the current pane in the title.
- Use native controls, meaningful labels, Full Keyboard Access, and visible focus.
- macOS controls should normally be at least 28 by 28 points and never smaller than 20 by 20 points; the hit target is distinct from the glyph size.
- Respect standard shortcuts and present every OpenRow binding visibly in the menu and Shortcut settings. A recorder exposes a plain-language accessible value in addition to modifier glyphs.

## Evidence-driven risks

| Risk | Evidence | Planning response |
| --- | --- | --- |
| Incomplete AX trees | HomeRow says support varies by app; custom-drawn apps may omit metadata. | Make target classification replaceable, report unsupported apps honestly, ship a fixture suite, and defer OCR/grid fallback rather than promise universal coverage. |
| Alternative layouts | HomeRow has repeatedly fixed layout/input-source issues. | Store physical key codes and modifiers, derive visible characters from the current input source, and test U.S., Dvorak, and one IME. |
| Trapped keyboard | Public HomeRow issues mention a dead-keyboard failure. | Event tap defaults to pass-through, suppresses only recognized active-mode events, exits on tap disable/timeout, and always preserves Escape. |
| Chromium variance | HomeRow changelog calls out Chrome tree loading and label accuracy. | Include Chrome in the first integration matrix and keep tree traversal cancellable, bounded, and instrumented. |
| Multi-display coordinates | AX uses global screen geometry while AppKit and Core Graphics have differing coordinate conventions. | Centralize coordinate conversion and test negative display origins, scaling, menu-bar displays, Spaces, and display hot-plug. |
| Translucency over content | Apple says custom Liquid Glass must preserve legibility and adapt to accessibility settings. | Keep overlays opaque by default; use system glass only for app chrome and optional mode HUD. |
| Sandbox/App Store uncertainty | Apple Developer Forums and API boundaries show that event listening and cross-app AX control have distinct TCC and sandbox considerations. | Treat signed, notarized direct distribution as v1; validate on a fresh macOS VM before discussing Mac App Store distribution. |

## Sources

1. HomeRow (2026) *Keyboard shortcuts for your entire Mac*. Available at: https://www.homerow.app/ (Accessed: 9 September 2026).
2. HomeRow (2026) *Public user guide*. Available at: https://github.com/nchudleigh/homerow/blob/main/README.md (Accessed: 9 September 2026).
3. HomeRow (2026) *Changelog*. Available at: https://www.homerow.app/changelog (Accessed: 9 September 2026).
4. Apple (2026) *AXUIElement.h*. Available at: https://developer.apple.com/documentation/applicationservices/axuielement_h (Accessed: 9 September 2026).
5. Apple (2026) *AXIsProcessTrustedWithOptions*. Available at: https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions (Accessed: 9 September 2026).
6. Apple (2026) *CGEventTapCreate*. Available at: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:) (Accessed: 9 September 2026).
7. Apple (2026) *CGEvent and scroll-wheel event creation*. Available at: https://developer.apple.com/documentation/coregraphics/cgevent (Accessed: 9 September 2026).
8. Apple (2026) *Adopting Liquid Glass*. Available at: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass (Accessed: 9 September 2026).
9. Apple (2026) *Platforms State of the Union — WWDC26*. Available at: https://developer.apple.com/videos/play/wwdc2026/102/ (Accessed: 9 September 2026).
10. Apple (2026) *Designing for macOS*. Available at: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/ (Accessed: 9 September 2026).
11. Apple (2026) *Settings*. Available at: https://developer.apple.com/design/human-interface-guidelines/settings (Accessed: 9 September 2026).
12. Apple (2026) *Keyboards*. Available at: https://developer.apple.com/design/human-interface-guidelines/keyboards (Accessed: 9 September 2026).
13. Apple (2026) *Accessibility*. Available at: https://developer.apple.com/design/human-interface-guidelines/accessibility (Accessed: 9 September 2026).
14. Apple Support (2026) *Control access to input monitoring on Mac*. Available at: https://support.apple.com/guide/mac-help/control-access-to-input-monitoring-on-mac-mchl4cedafb6/mac (Accessed: 9 September 2026).
15. Apple Support (2026) *Allow accessibility apps to access your Mac*. Available at: https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac (Accessed: 9 September 2026).
16. Apple (2026) *SMAppService.mainApp*. Available at: https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp (Accessed: 9 September 2026).

## Limits

- The HomeRow public repository contains documentation and a Hyper-key configuration, not the application's implementation. OpenRow must be implemented clean-room from public behavior and Apple APIs.
- macOS 27 is available in beta at the time of planning, but this machine runs macOS 26.6.2 with Xcode 26.6. macOS 27 behavior is sourced from Apple's current material and remains unverified locally.
- Permission behavior can be polluted by cached TCC grants. The build phase needs a fresh VM snapshot or a separately signed test bundle for trustworthy first-run evidence.
