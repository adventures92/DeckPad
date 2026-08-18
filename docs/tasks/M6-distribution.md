# M6 — Service Polish & Distribution

**Goal:** the sticky, installable product: login item, onboarding, notarized DMG, release checklist.
**Prerequisites:** M4 + M5. **Spec refs:** FR-51, FR-52, NFR-6, [08-background-service.md](../08-background-service.md), [D-002](../99-decisions.md#d-002-distribution--direct-notarized).

## Tasks

### Service polish
- [ ] Launch at login via `SMAppService.mainApp` + Settings toggle reflecting real status incl. `.requiresApproval` ([08 §2](../08-background-service.md#2-launch-at-login-fr-51))
- [ ] Login-item launch path: straight to AccessoryService when onboarded ([08 §2](../08-background-service.md#2-launch-at-login-fr-51))
- [ ] Abnormal-exit detection → gentle note + diagnostics offer ([08 §8](../08-background-service.md#8-update--crash-posture-v1))
- [ ] "Export diagnostics" in About (log archive + anonymized profile summary) ([08 §7](../08-background-service.md#7-logging--diagnostics))

### Onboarding (FR-52)
- [ ] Five-card flow per [05 §9](../05-ui-spec.md#9-onboarding-fr-52): welcome, live device detection, Accessibility grant with live flip, guided first mapping, feedback style picker
- [ ] Skippable, re-runnable from Settings; state in settings.json

### Release engineering (NFR-6)
- [ ] Developer ID Application signing config; Hardened Runtime entitlements audit (no sandbox, no unnecessary entitlements)
- [ ] `scripts/release.sh`: archive → `xcodebuild -exportArchive` → `notarytool submit --wait` → `stapler` → DMG (create-dmg) with license/drag-to-Applications layout
- [ ] Gatekeeper test on a clean machine/VM: download → open → no warnings beyond first-run
- [ ] Universal binary check (arm64 + x86_64)
- [ ] Version/build numbering scheme + `v1.0.0` tag flow

### Release checklist (repeat every release)
- [ ] Private-API smoke test on current macOS: DisplayServices brightness path + fallback ([ADR-007](../99-decisions.md#adr-007-brightnessmedia-control-techniques-risk-accepted))
- [ ] Permissions flows re-tested on a fresh user account (Accessibility, Automation, login item)
- [ ] Fresh-account end-to-end: install DMG → onboard → reboot → controller works before any window opens (the roadmap demo)
- [ ] Latency spot-check vs. NFR-1; idle footprint vs. NFR-2
- [ ] Docs true-up: specs match shipped behavior; parking-lot updates in [09-roadmap.md](../09-roadmap.md)

### Docs & assets
- [ ] User-facing README section: install, permissions explainer, FAQ (coexistence, unplug behavior)
- [ ] Screenshots/screen recording for README (canvas, ⌘K, notch toast)

## Acceptance criteria
- Roadmap demo passes on a fresh macOS user account, from DMG to reboot-surviving background service.
- Notarization pipeline is one command; artifact passes `spctl --assess`.
- All release-checklist items checked for v1.0.0.
