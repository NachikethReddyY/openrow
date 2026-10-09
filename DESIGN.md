# OpenRow interface design

Status: proposed Native Quiet direction. The product requirements in the user brief are accepted; the visual execution awaits final approval before implementation.

## 1. Experience frame

- **User:** a keyboard-first Mac user in long, interruption-heavy desktop sessions.
- **Immediate job:** reach and activate a graphical control or scroll a region while hands remain on the keyboard.
- **Supported context:** macOS 26 minimum; macOS 27 forward-compatible; one or more Retina/non-Retina displays; light/dark appearance; keyboard primary, pointer secondary; Full Keyboard Access and VoiceOver in Settings.
- **Personality:** calm, exact, compact, native, and fast.
- **Emotional outcome:** confidence that OpenRow will appear instantly, never steal focus, click only the selected target, and leave the keyboard usable.
- **Smallest useful proof:** with Safari frontmost, `Hyper–J` shows readable home-row hints; typing one moves the pointer and clicks the matching control once; Escape cancels.

## 2. Direction: Native Quiet

OpenRow uses macOS system structure for persistent UI and one high-contrast custom language for transient overlays.

- Settings is a standard macOS settings window: native traffic lights, toolbar/title behavior, edge-to-edge Liquid Glass sidebar, system lists/forms, and no branded background treatment.
- Hint labels are compact opaque yellow keys with black text and a dark edge. They intentionally do not use glass because they sit over uncontrolled content.
- Scroll mode uses a blue 2-point region outline and a small blue numbered badge. Blue means current selection, not decoration.
- A compact mode HUD may use system glass because it is a temporary control/status layer. It is omitted by default when labels or an outline already make state obvious.
- OpenRow uses a distinct simple icon and name; no HomeRow house/HR imagery, copied screenshots, or marketing language.

The visual comparison in `artifacts/openrow-plan.html` includes two deliberately controlled alternatives. Native Quiet is recommended because it gets macOS 26 and 27 adaptation from standard components, uses the fewest custom surfaces, and gives the overlay maximum contrast.

## 3. Material and depth

### Persistent windows

- Prefer `Settings` scene + `NavigationSplitView`/native AppKit equivalents.
- Let system components provide Liquid Glass on macOS 26. Do not put `glassEffect` on every form group.
- Use custom glass only for a compact, genuinely floating control surface. When more than one custom glass view appears together, wrap them in `GlassEffectContainer`.
- On macOS 27, inherit the platform's refined diffusion and edges automatically. Add 27-only interaction/border refinements only behind availability checks.
- Under Reduce Transparency, all structure resolves to opaque system surfaces with separators. Under Increase Contrast or Show Borders, controls and selection keep explicit edges.

### Overlay windows

- One borderless, nonactivating, transparent `NSPanel` per active display.
- Overlay panels never become key/main, never accept mouse events, and stay at the lowest window level that reliably remains above the target content without covering protected system UI.
- Labels sit on the overlay plane with one tight contact shadow solely to separate them from content. No glow, blur, glass, morphing, or idle animation.
- Enter/exit uses opacity only, 80–120 ms; Reduce Motion makes it immediate.

## 4. Color roles

Native Settings uses semantic system colors. Hex values below are for the visual artifact and overlay implementation where a stable cross-background color is required.

| Role | Native value / fallback | Use | Exclusions |
| --- | --- | --- | --- |
| Window | `windowBackgroundColor` / `#1C1C1E` dark | Settings content plane | Never force dark mode. |
| Sidebar | system sidebar material / `rgba(46,46,49,.78)` | Navigation ownership | No extra nested glass cards. |
| Raised group | `controlBackgroundColor` / `#2C2C2E` | Related settings rows | Not every paragraph or row. |
| Primary text | `labelColor` / `#F5F5F7` | Titles, labels, values | — |
| Secondary text | `secondaryLabelColor` / `#AEAEB2` | Explanations, state detail | Never essential state alone. |
| Separator | `separatorColor` / `#48484A` | Persistent row/group boundary | Prefer spacing when enough. |
| Action/selection | `controlAccentColor` / `#0A84FF` | Selected sidebar, primary action, active scroll region | Not decorative copy or headings. |
| Hint | `#FFE36E` | Click hint background only | Not buttons, warnings, or Settings selection. |
| Hint text | `#111111` | Hint characters | Never yellow/white. |
| Warning | `systemOrange` / `#FF9F0A` | Permission limited or stale target | Always paired with text/icon. |
| Failure | `systemRed` / `#FF453A` | Permission/error failure | Never routine inactive state. |
| Ready | `systemGreen` / `#30D158` | Capability ready | Always paired with “Ready” or checkmark. |

The fixed hint pairing targets comfortably above WCAG AA despite uncontrolled surroundings because the yellow surface is opaque and has a dark keyline. Focus/selection never relies on color alone: selected rows have fill + weight, current hint has outline + scale/weight, and scroll regions have outline + number.

## 5. Typography

Use the system San Francisco family through semantic SwiftUI/AppKit styles. Do not bundle fonts.

| Role | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| Pane title | 20 pt / 24 pt | semibold | Current Settings pane |
| Section title | 13 pt / 17 pt | semibold | General, Shortcuts, Behavior groups |
| Body/control | 13 pt / 17 pt | regular | Labels and values |
| Secondary | 11 pt / 14 pt | regular | Permission explanation and validation help |
| Sidebar | 13 pt / 17 pt | regular; semibold selected | Stable pane navigation |
| Hint default | 10 pt / 14 pt | semibold monospaced | 1–3 key hint codes |
| Mode badge | 11 pt / 13 pt | semibold monospaced | Scroll region number/status |

Use system text scaling. A label-size preference maps to 9, 10, 12, and 14 pt rather than an unconstrained continuous value. Hint boxes grow with text and never crop three-character codes.

## 6. Layout measurements

### Settings window

- Content size: 820 × 600 pt preferred. The Settings scene can size to pane content; zoom is disabled per macOS settings convention. Every pane remains usable at 680 × 480 pt if platform behavior allows a smaller restored frame.
- Sidebar: 208 pt preferred, 184 pt minimum. Navigation rows are 32 pt high with 12 pt leading inset, 8 pt glyph-to-label gap, and an SF Symbol around 16 pt inside a 28 pt target.
- Content margins: 24 pt top/leading/trailing, 28 pt bottom.
- Section gap: 24 pt. Section title-to-group gap: 8 pt.
- Settings group corner radius: system default; fallback 12 pt. A group uses one outer surface and 1-pixel separators, not a card per row.
- Setting row: 44 pt minimum; 52–64 pt when secondary explanation is present. Horizontal inset 14 pt; control-to-edge 12 pt.
- Controls: standard regular/small macOS sizes; clickable target normally ≥ 28 × 28 pt and never below 20 × 20 pt.
- Shortcut recorder: 184 × 28 pt minimum with 8 pt internal horizontal padding and a stable width while recording/error states change.
- Keep primary controls away from the fragile bottom edge; long panes scroll beneath standard edge treatment.

### Click hints

- Content inset: 3 pt horizontal, 1 pt vertical.
- Default min box: 18 × 16 pt for two characters; height grows with label size.
- Radius: 3 pt; border: 1 pt dark with an optional 1 px highlight at high contrast; shadow: 0 1 3 pt at ≤ 35% black. A centered 6 pt upward pointer uses the same fill and dark edge.
- Preferred anchor: horizontally centered with the pointer tip inside the target and the label overlapping its nearest edge by 4–8 pt. Fallback order: inside the target, immediately above, then nearest collision-free location within 18 pt.
- Keep the full box inside the owning display's visible frame and at least 2 pt from screen edges.
- Collision order is deterministic. A leader line is not used in v1; if collision cannot resolve within bounds, preserve the higher-priority target and expose the omitted-count diagnostic.

### Scroll regions

- Active outline: 2 pt system blue inset inside the visible clipped area so it remains visible at display edges.
- Badge: 22 × 20 pt minimum, top-leading 6 pt inset; selected badge blue with white number, unselected badge opaque dark with white number and 1 pt light edge.
- No full-screen tint or continuous animation.

## 7. Information architecture

### Menu bar

1. OpenRow status: Ready, Paused, or Needs Permission.
2. Click Mode — current shortcut.
3. Scroll Mode — current shortcut.
4. Pause OpenRow.
5. Settings… — Command-Comma.
6. Quit OpenRow — Command-Q.

Status is plain menu text/check state, not a decorative badge. If the menu-bar icon is hidden, the app remains available through its normal app/menu command; hiding both Dock and menu-bar presence is not allowed.

### Settings panes

1. **General:** permission readiness, launch at login, menu-bar presence, sounds.
2. **Shortcuts:** Click mode and Scroll mode first, followed by per-mode controls. Recorder values are visible and VoiceOver readable.
3. **Clicking:** hint alphabet preset, label size, placement, optional click feedback.
4. **Scrolling:** H/J/K/L mapping, speed, dash speed, region numbers.
5. **Ignored Apps:** app list with Add/Remove and accurate first-use empty state.
6. **About:** version, open-source license, repository link, privacy statement, diagnostics export only when implemented.

This reduces HomeRow's five-pane screenshot to persistent concepts OpenRow actually supports and gives shortcuts their own high-frequency pane.

## 8. Component and state rules

### Permission row

Name, one-line reason, text status with SF Symbol, and one contextual action: Grant Access, Open System Settings, or Ready. Never show multiple blue actions. If denied, say “Accessibility is off. OpenRow can't inspect or click controls.”

### Shortcut recorder

Default: neutral recessed field with glyphs. Focused: system focus ring. Recording: “Press a shortcut” with blinking insertion caret only if native and cheap; no pulsing animation. Conflict: orange icon + nearby sentence; previous valid value remains. Disabled: preserve readable value and explain the missing permission only if it blocks testing, not editing.

### Empty ignored-app list

Use `eye.slash` SF Symbol at modest size, title “No ignored apps,” sentence “OpenRow is available in every app,” and Add App button. Avoid a huge icon or marketing illustration.

### Overlay states

- **Collecting (<150 ms expected):** no spinner. If it exceeds 150 ms, show a small opaque “Finding controls…” status near the pointer; it never captures input beyond mode commands.
- **Hints ready:** labels only; no global dimming.
- **Partial input:** unmatched labels disappear, matched suffix remains bold; selected/focused hint gets a 2 pt blue ring plus higher weight.
- **No match:** short orange mode badge “No match · Esc to close,” then remain cancellable; Backspace recovers.
- **No targets:** “No clickable controls found in [App]” plus Escape; Settings can offer diagnostics after exit.
- **Stale target/failure:** cancel before click, flash the target label orange once (or static under Reduce Motion), and return input.
- **Tap disabled:** overlays close immediately; menu status becomes Needs Attention; no retry loop inside the callback.

## 9. Accessibility and inclusion

- Settings uses native controls with roles, names, values, state, predictable focus order, and no custom-drawn equivalents unless the shortcut recorder requires one.
- Full Keyboard Access reaches navigation, every recorder, button, slider, picker, list row, and contextual action. Focus remains visible independently of blue color.
- VoiceOver announces shortcut values in words, permission state changes, validation errors, and the selected pane. Overlay hints are not VoiceOver navigation replacements; when VoiceOver is running, OpenRow must not interfere with standard VoiceOver chords.
- Essential overlay meaning uses characters, geometry, and border/weight, not color or sound alone.
- Respect Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without Color, and macOS 27 Show Borders.
- Use current input source characters and physical key positions; never assume QWERTY text events. Localize all Settings copy and allow 40% expansion without truncating primary controls.
- No auto-dismiss timer for permission/error explanations. Click hints disappear only after action, cancellation, invalidation, or user-configured toggle behavior.

## 10. macOS 26 → 27 plan

1. Build against the macOS 26 SDK and use standard SwiftUI/AppKit navigation, list, menu, toolbar, and control types so system Liquid Glass adapts by default.
2. Keep custom overlay drawing independent of undocumented glass internals.
3. Put every macOS 27-only refinement behind `if #available(macOS 27, *)`; no compile-time fork of the core interaction.
4. On 27, test standard sidebar edge extension, tighter window corners, Show Borders, Liquid Glass clarity/tint preferences, key-loop fixes, and title/scroll-edge behavior.
5. Never claim macOS 27 support until the same P0 interaction matrix passes on a 27 machine or VM.

## 11. Restraint audit

- Rectangles are limited to the real Settings window, one grouped settings surface, native controls, hint keys, and active scroll boundary.
- Capsules appear only where the system control style requires them; ordinary labels and statuses are text.
- Glass identifies the system control layer; it is not used as wallpaper or behind every row.
- Yellow belongs only to hint identity, blue to active selection/action, and semantic colors to named readiness/error states.
- There is one primary action per onboarding step and no decorative subtitle, invented feature copy, persistent tutorial, tabs, or help control.
- Motion communicates overlay arrival or invalidation and is never continuous.

## 12. Visual proof

The local visual plan demonstrates:

- three controlled Settings treatments with the same content;
- the recommended native Settings pane;
- permission-limited first run;
- click hints over a representative dark app;
- partial label filtering and focused target;
- scroll-region selection; and
- narrow document layout and keyboard-operable design tabs.

The HTML artifact is communication-only. It approximates system materials; Xcode SwiftUI previews and an actual macOS 26 build are the authority for real Liquid Glass, metrics, focus, and accessibility behavior.
