# OpenRow interface design

Status: accepted from the supplied OpenRow product plan, with compact-hint corrections on 2026-09-09 and click/scroll target corrections on 2026-09-10.

## Product frame

- Primary user: a keyboard-first Mac user moving between desktop apps.
- Job: click a visible control or scroll a region without reaching for the pointer.
- Context: macOS 26+, resizable Settings window, keyboard and pointer, VoiceOver and Full Keyboard Access, light/dark and increased-contrast appearances.
- Personality: native quiet—calm, compact, and system-owned rather than branded chrome.
- Completion signal: the chosen control acts once or the chosen region scrolls while the original app keeps focus.

## Lifecycle and hierarchy

- Idle UI is one menu-bar item. OpenRow has no Dock icon and no persistent app window.
- Onboarding appears once, before permission prompts, and remains skippable.
- Settings is an on-demand utility window with a native sidebar: General, Shortcuts, Clicking, Scrolling, Ignored Apps, About.
- Each Settings pane has one heading, short supporting copy only where needed, and native grouped controls.
- The menu-bar menu exposes status first, then Click Mode, Scroll Mode, Pause/Resume, Settings, and Quit.

## Icons

- SF Symbols is the only interface-icon source. Use `Image(systemName:)` or AppKit symbol images with semantic accessibility labels.
- The user-supplied `artwork/OpenRow.icon` from main owns the macOS application icon. Compile it with `actool`; the menu bar and all interface controls continue to use SF Symbols.
- Do not use emoji, Unicode stand-ins, third-party icon libraries, traced symbols, or custom-drawn interface icons.
- Current map: menu/app mark `cursorarrow.rays`; General `gearshape`; Shortcuts `command`; Clicking `cursorarrow.click.2`; Scrolling `arrow.up.and.down.and.arrow.left.and.right`; Ignored Apps `app.badge`; About `info.circle`; permissions `accessibility` and `keyboard`; status `checkmark.circle.fill`, `pause.circle.fill`, or `exclamationmark.triangle.fill`.
- Symbols inherit surrounding foreground style. Status color always has a symbol and text equivalent.

## Typography

- Use San Francisco through native system text styles; never bundle a font.
- Pane title: system title style/semibold. Row title: body/medium. Explanations: callout/secondary. Shortcut values: monospaced body/semibold.
- Respect macOS text sizing and localization; no fixed-height text containers.

## Color and material

- Use platform semantic backgrounds, labels, separators, tint, and materials so light, dark, contrast, transparency, and future macOS appearances adapt automatically.
- System accent owns selection, focus, permission actions, and the selected scroll outline.
- Opaque warm yellow owns click hints only; it never appears in Settings.
- Green, amber, and red are status roles and are always paired with an SF Symbol and text.
- No custom tinted sidebar, gradients, decorative glows, or continuously repainting animation.

## Layout and density

- Settings default: 780 x 540 pt, minimum 680 x 460 pt. Sidebar: 190–240 pt. Details use a readable maximum width around 560 pt.
- Spacing follows native Form/List metrics. Related row content remains closer than section spacing.
- The window resizes without hiding primary actions; panes scroll when enlarged text or localization requires it.
- Onboarding default: 660 x 440 pt. Its progress sidebar collapses before content becomes cramped.

## Overlay language

- Overlays are nonactivating, click-through, and excluded from window cycling.
- Click hints are opaque yellow rounded rectangles with black monospaced text, a black edge, and no screen dimming. Matching is reinforced by opacity; an exact match also gains a blue outline.
- The 2026-09-09 density correction sets hint text to 8/9/11 pt (Small/Medium/Large), default 9 pt, with 2 pt horizontal and 1 pt vertical padding. Region numbers use 9 pt. Preserve this compact scale across rebuilds.
- Mix single, double, and longer hint codes with no ambiguous prefixes. Discover actionable popup rows; document table cells do not receive hints merely because they are cells.
- The 2026-09-10 correction adds a compact triangular callout tail (annotation geometry, not an interface icon). Its tip is the exact stored click coordinate. Place the badge above/below/left/right with a short gap, choose the least overlapping on-screen placement, and keep placement stable during filtering. Show one hint for each action owner, with separate hints for independent controls inside a row.
- Scroll selection includes browser tab sidebars separately from the main page. It is a 2-point blue inset outline with a numbered badge and a compact instruction HUD. Selection never relies on color alone.
- Overlay panels reuse one drawing surface per display. Reduce Motion disables transition animation; Reduce Transparency uses opaque surfaces.

## Interaction and states

- Every essential Settings action is reachable with Full Keyboard Access and has a native focus ring.
- Permission states are `Ready`, `Not Allowed`, and `Open System Settings`; refusal never triggers repeated alerts.
- Activation immediately shows a bounded discovery state. Empty results explain that the frontmost app exposed no supported controls/regions and then return to idle.
- Escape always cancels. Frontmost-app/display changes cancel. A disabled event tap clears overlays before presenting `Needs Attention` in the menu.
- Closing onboarding or Settings preserves the background service.

## Accessibility and restraint gates

- Native controls provide roles, names, values, focus, keyboard behavior, and VoiceOver order.
- Overlay mode announcements describe mode and available keys without exposing scanned UI strings.
- Meaning survives grayscale, increased contrast, reduced transparency, reduced motion, and large text.
- Every visible element contributes action, state, grouping, or identity. Further visual removal would reduce recognition or recovery.
