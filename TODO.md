# OpenRow work

## 2026-09-09 — optimized native macOS app

- [x] Inspect the Postplan reference and repository/toolchain prerequisites.
- [x] Lock the product contract: menu-bar background utility, on-demand UI, SF Symbols only.
- [x] Record the v1 behavior and native design decisions in `SPEC.md` and `DESIGN.md`.
- [x] Write failing tests for hint assignment/filtering, input safety, mode transitions, and display geometry.
- [x] Implement the deterministic domain core and make its tests pass.
- [ ] Implement permission checks, fail-open global input, AX discovery/revalidation, pointer actions, and scrolling.
- [ ] Implement reusable nonactivating overlays for click hints and scroll-region selection.
- [ ] Implement the menu-bar lifecycle, permission-first onboarding, Settings, ignored apps, and login item.
- [ ] Add an instrumented fixture and local release app bundling.
- [ ] Build and run focused unit/integration checks.
- [ ] Launch the bundled app and directly inspect first-run, menu-bar, Settings, and background-only behavior.
- [ ] Run a final privacy, idle-work, SF Symbols, and repository-state audit.
