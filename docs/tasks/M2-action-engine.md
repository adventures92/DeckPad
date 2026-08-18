# M2 — Action Engine

**Goal:** every action type in the [catalog](../06-actions-catalog.md) executes correctly, with permissions handled and latency proven.
**Prerequisites:** M1. **Spec refs:** FR-30…FR-32 (FR-32 lands in M3), FR-11/FR-12 targets, NFR-1, [ADR-007](../99-decisions.md#adr-007-brightnessmedia-control-techniques-risk-accepted), [08 §4](../08-background-service.md#4-permissions-acquisition-ux).

## Tasks

### PermissionsManager
- [ ] Accessibility: trusted check, prompt-once flow, System Settings deep link, 1 Hz visible-only polling, revocation detection flag ([08 §4](../08-background-service.md#4-permissions-acquisition-ux))
- [ ] Automation: pre-flight hint data + `AEDeterminePermissionToAutomateTarget` status reads
- [ ] Published permission state (ObservableObject) for UI/menu-bar badges

### Executors (one type per catalog section; `ActionExecuting` protocol declaring permission + sync/async)
- [ ] Keystroke + key-repeat: CGEvent down/up with modifiers ([06 §1](../06-actions-catalog.md#1-keyboard))
- [ ] Text snippet: unicode chunked typing
- [ ] Media/system keys: NX system-defined events — play/pause, next/prev, volume ±/mute, brightness ±, Mission Control, Launchpad, kbd illumination ([06 §2](../06-actions-catalog.md#2-media--system-keys))
- [ ] Apps & files: launch/focus, hide/quit, cycle windows, open URL, open file ([06 §3](../06-actions-catalog.md#3-apps--files))
- [ ] Automation: `shortcuts run` (+ `shortcuts list` for picker data), shell via zsh with timeout + env (`DECKPAD_VALUE`/`DECKPAD_TICKS`), AppleScript ([06 §4](../06-actions-catalog.md#4-automation)) — all async off the hub
- [ ] System toggles: lock, screen saver, dark mode, screenshot modes, DND-via-bundled-Shortcut, display sleep ([06 §5](../06-actions-catalog.md#5-system-toggles--session))
- [ ] Internal actions: switch/pin profile, suspend, open window, toggle monitor, no-op ([06 §6](../06-actions-catalog.md#6-deckpad-internal)) — wired to stubs until M3
- [ ] Continuous: CoreAudio system volume; brightness via DisplayServices with stepped-key fallback; curve + range + clamp support ([06 §7](../06-actions-catalog.md#7-continuous-targets-fr-11))
- [ ] Jog modes: scroll events (axis/speed/natural), arrow stepper, zoom, dial increments, custom-per-tick ([06 §8](../06-actions-catalog.md#8-jog--encoder-modes-fr-12))

### Quality
- [ ] Latency signposts (os_signpost) input→post; measure on hardware: p95 ≤ 50 ms for keystroke/media actions (NFR-1) — record numbers in this file
- [ ] Failure propagation: executor errors → typed result for FeedbackCenter (silent-failure ban, [07 §6](../07-feedback-system.md#6-rules--rate-limits-sanity-guarantees))
- [ ] Unit tests: each executor invoked with expected parameters against a mock event-poster/process-runner; brightness fallback path tested

## Acceptance criteria
- Roadmap demo: hardcoded test mappings — pad types a keystroke into TextEdit, fader rides system volume smoothly, jog scrolls Safari — all measured under budget.
- With Accessibility revoked, actions fail visibly (log + flag), never crash; re-grant recovers per [08 §4](../08-background-service.md#4-permissions-acquisition-ux).
- Measured latency numbers recorded here: ⏳ *(fill at completion — this file's only allowed pending marker)*
