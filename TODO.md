# OpenRow work

## 2026-09-10 — clarify click targets

- [x] Confirm repository, current branch, clean worktree, toolchain, and GitHub access.
- [x] Inspect live accessibility roles/actions and use Luna to check deduplication boundaries.
- [x] Add regressions for shared row actions, distinct nested controls, and exact pointer geometry.
- [x] Consolidate click targets by action ownership and commit a verified checkpoint (9 focused tests passed).
- [x] Draw compact directional callouts anchored to the click point and commit a verified checkpoint (44 unit tests passed; signed release build passed).
- [ ] Discover the browser's scrollable tab sidebar separately from web content, preserve cursor/direction behavior, and commit a verified checkpoint.
- [ ] Verify native/WebKit interactions and inspect the live overlay; obtain focused Luna validation.
- [ ] Synchronize behavior/design documentation, rebase on main, push checkpoints, and open a real PR.
- [ ] Review latest PR checks/findings and provide a testable build for user testing; leave unmerged.

## 2026-09-09 — optimized native macOS app

- [x] Inspect the Postplan reference and repository/toolchain prerequisites.
- [x] Lock the product contract: menu-bar background utility, on-demand UI, SF Symbols only.
- [x] Record the v1 behavior and native design decisions in `SPEC.md` and `DESIGN.md`.
- [x] Write failing tests for hint assignment/filtering, input safety, mode transitions, and display geometry.
- [x] Implement the deterministic domain core and make its tests pass.
- [x] Implement permission checks, fail-open global input, AX discovery/revalidation, pointer actions, and scrolling.
- [x] Implement reusable nonactivating overlays for click hints and scroll-region selection.
- [x] Implement the menu-bar lifecycle, permission-first onboarding, Settings, ignored apps, and login item.
- [x] Add an instrumented fixture and local release app bundling.
- [x] Build and run focused unit/integration checks.
- [x] Launch the bundled app and directly inspect first-run, menu-bar, Settings, and background-only behavior.
- [x] Run a final privacy, idle-work, SF Symbols, and repository-state audit.

## 2026-09-09 — handoff implementation and local build

- [x] Add tested typed preferences, target eligibility/revalidation, and input safety regressions.
- [x] Implement the serialized AX service, global input adapter, and click/scroll actions.
- [x] Implement reusable display overlays and physical keyboard-layout labels.
- [x] Implement the background app, permission onboarding, complete native Settings, and login-item control.
- [x] Build an instrumented native/WebKit fixture and ad-hoc-signed app bundles.
- [x] Synchronize DESIGN.html and document build/use/privacy details.
- [x] Run focused tests and release build; directly inspect native UI and permitted end-to-end flows.
- [x] Record observed proof, permission blockers, and final worktree state.
- [x] Commit verified implementation checkpoints (authorized by user follow-up).
- [x] Fix the observed event-tap actor-isolation crash and verify a real key event on the dedicated thread.
- [x] Rebase onto latest main, push, open a real PR, and resolve checks/review findings (remote CI unavailable; local review and tests used).
- [x] Verify native/browser behavior and focused checks before the authorized squash merge; final merge disposition is tracked in PR #1. Remote CI is unavailable with the current token.
- [x] Install OpenRow in /Applications with stable signing for persistent TCC permissions; verify the installed copy.
- [x] Prevent in-place writes to running signed bundles after the observed fixture invalid-page crash.
- [x] Integrate latest main and use its supplied app icon in the bundle (interface icons remain SF Symbols).
- [x] Reduce overlay badges to a 9-point default with compact padding; preserve configurable sizes and native Settings.
- [x] Route modifier-only secure-input transitions through fail-open cancellation and add a regression.
- [x] Run the user-authorized Swift/Quartz fixture harness and fix any observed failures.
- [x] Replace uniform-length hint codes with unambiguous mixed single/double/longer codes, and test prefix safety.
- [x] Fix missed popup/model-picker targets and exclude noninteractive document cells; verify against a fixture and the supplied screenshots.
- [x] Verify the macOS-resolved installed icon and use the supplied app identity in About and Setup.
- [x] Correct horizontal scrolling and preserve the physical cursor using accessible scroll positions; fail safely where precise scrolling is unavailable.
- [x] Fix browser scrolling with cursor preservation; user explicitly requires it before squash merge.
  - [x] Prove public AppKit/Quartz window-directed scrolling reaches both WebKit regions with the physical pointer stationary.
  - [x] Add nested web-region discovery, clipped click targets, and guarded window-directed wheel delivery.
  - [x] Verify browser clicks, four scroll directions, dash, region selection, key-up/Escape cancellation, and native regressions; review input safety before merge.

- [x] Open PR #1; initial implementation push rejected because OAuth lacks workflow scope.
- [x] Push the app with the workflow retained as a template and verify the PR contains the intended commit.

Validation: 39 tests passed with native tests enabled (33 unit, 6 integration), including browser page/nested scrolling and same-process window-switch rejection. Thirty warm runs discovering 122 controls and drawing 100 hints measured p50 47 ms / p95 56 ms, excluding compositor presentation. Signed installation, persistent Ready permissions, and the local-only source audit passed. Browser support and compact hints are project guidance recorded in SPEC.md; no shared guidance was changed.
