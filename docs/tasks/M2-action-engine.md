# M2 — Action Engine

**Goal:** every action type in the [catalog](../06-actions-catalog.md) executes correctly, with permissions handled and latency proven.
**Prerequisites:** M1. **Spec refs:** FR-30…FR-32 (FR-32 lands in M3), FR-11/FR-12 targets, NFR-1, [ADR-007](../99-decisions.md#adr-007-brightnessmedia-control-techniques-risk-accepted), [08 §4](../08-background-service.md#4-permissions-acquisition-ux).

## Tasks

### PermissionsManager
- [x] Accessibility: trusted check, prompt-once flow, System Settings deep link, 1 Hz visible-only polling, revocation detection flag ([08 §4](../08-background-service.md#4-permissions-acquisition-ux)) — `DeckPad/Permissions/PermissionsManager.swift`
- [ ] Automation: pre-flight hint data + `AEDeterminePermissionToAutomateTarget` status reads (consumer is the M4 Permissions settings tab; usage description shipped now)
- [x] Published permission state (ObservableObject); menu bar shows a grant button when Accessibility is missing

### Executors (`ActionEngine` with injectable seams: EventPosting, ProcessRunning, Volume/BrightnessControlling)
- [x] Keystroke + key-repeat: CGEvent down/up with modifiers ([06 §1](../06-actions-catalog.md#1-keyboard))
- [x] Text snippet: unicode chunked typing (20 UTF-16 units/chunk)
- [x] Media/system keys: NX system-defined events — play/pause, next/prev, volume ±/mute, brightness ±, kbd illumination; Mission Control/Launchpad via app launch ([06 §2](../06-actions-catalog.md#2-media--system-keys))
- [x] Apps & files: launch/focus, hide/quit (via `NSRunningApplication` — no Automation permission needed, docs/06 updated), cycle windows, open URL, open file
- [x] Automation: `shortcuts run`, shell via zsh with timeout + env, AppleScript via `osascript` ([06 §4](../06-actions-catalog.md#4-automation)) — all async off the hub with completion results (`shortcuts list` picker data lands with the M4 editor)
- [x] System toggles: lock, screen saver, dark mode, screenshot modes, DND (runs user-installed "DeckPad DND" Shortcut; bundled asset ships with M6 onboarding), display sleep
- [x] Internal actions: openDeckPad live; switch/pin profile, suspend, toggle monitor are logged stubs until M3 ([06 §6](../06-actions-catalog.md#6-deckpad-internal))
- [x] Continuous: CoreAudio system volume; brightness via DisplayServices (dlopen) with stepped-key fallback; curve + range + clamp (`ContinuousShape`) ([06 §7](../06-actions-catalog.md#7-continuous-targets-fr-11))
- [x] Jog modes: scroll (axis/speed/natural), arrow stepper with tick accumulators, zoom, volume/brightness dials, custom-per-tick ([06 §8](../06-actions-catalog.md#8-jog--encoder-modes-fr-12))

### Quality
- [ ] Latency: DemoBench logs per-action dispatch time + p50/p95 rollups (os_log `latency` category); measure on hardware during the demo run: p95 ≤ 50 ms (NFR-1) — record numbers in this file
- [x] Failure propagation: `ActionResult` (success/failure/permissionMissing); async subprocess results via completion; Accessibility failures set the PermissionsManager flag (silent-failure ban, [07 §6](../07-feedback-system.md#6-rules--rate-limits-sanity-guarantees))
- [x] Unit tests: 13 executor tests against mock poster/runner/volume/brightness incl. the brightness fallback path and permission-missing visibility

## Acceptance criteria
- Roadmap demo: hardcoded test mappings — pad types a keystroke into TextEdit, fader rides system volume smoothly, jog scrolls Safari — all measured under budget.
- With Accessibility revoked, actions fail visibly (log + flag), never crash; re-grant recovers per [08 §4](../08-background-service.md#4-permissions-acquisition-ux).
- Measured latency numbers recorded here: ⏳ *(fill at completion — this file's only allowed pending marker)*
