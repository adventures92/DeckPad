# M3 — Mapping System & Service Core

**Goal:** real user-defined mappings with profiles, persistence, trigger detection, and the sticky-service lifecycle.
**Prerequisites:** M2. **Spec refs:** FR-7, FR-10…FR-14, FR-20…FR-23, FR-31, FR-32, FR-50, NFR-2/3/7, [02-architecture.md](../02-architecture.md), [08-background-service.md](../08-background-service.md).

## Tasks

### Models & store
- [x] Codable models per [02 §2](../02-architecture.md#2-core-types-shared-vocabulary): `Mapping` (incl. releaseAction/secondaryAction/jumpImmediately — doc updated), `Profile`, `FeedbackOverride`, `AppSettings` with tolerant decoding; `schemaVersion` from day one (NFR-7)
- [x] MappingStore: `profiles/<uuid>.deckpad.json` + `settings.json`, atomic writes, 500 ms debounce + flush-on-quit, broken-file quarantine, newer-schema refusal, first-run Global seeded with the starter mappings (replaces the M2 demo bench)
- [x] Import/export profile files (FR-23) with duplicate-name/ID handling; duplicate/delete; undeletable Global (FR-20)
- [x] Session undo stack (50 deep) for mapping edits (⌘Z UI lands in M4)

### Dispatcher
- [x] Hub: ControlEvent → active profile → mapping resolution with Global fallthrough (FR-21) — on MainActor for v1 per new [ADR-008](../99-decisions.md#adr-008-dispatcher-runs-on-the-mainactor-v1)
- [x] Trigger detection (`TriggerMachine`, deterministic/virtual-clock): press/release/doubleTap (300 ms + sibling delay)/hold (threshold + release action)/toggle with state persisted in settings.json (FR-13)
- [x] SHIFT layer routing (base vs. shift slots, FR-14)
- [x] Continuous coalescing @ 8 ms; soft-takeover pickup with cross-detection against live system volume, per-mapping "jump immediately" opt-out
- [x] Suspend gate (FR-32) with hardware self-resume (a mapped suspend action still works while suspended); internal actions (switchProfile/pin/suspend) fully wired; dispatch latency sampled to `/tmp/deckpad-latency.csv`

### ProfileSwitcher
- [x] Frontmost-app watcher → auto-switch with Global fallback (FR-21); ignores DeckPad itself
- [x] Manual pin/unpin (FR-22) via menu bar + mappable actions
- [x] Coexistence: DJ-app launch/quit watch → pause/resume per settings (FR-7); bundle-ID list user-extensible in settings.json (defaults: rekordbox, djay Pro, Serato Lite/Pro)

### ServiceController
- [x] Lifecycle per [08 §1](../08-background-service.md#1-lifecycle-state-machine): ActiveUI ↔ AccessoryService (existing) + Suspended (Dispatcher gate) + CoexistencePause (ProfileSwitcher gate)
- [x] Single-instance guard (skipped under the test host); quit confirmation with "don't ask again" suppression
- [x] Sleep/wake MIDI revalidation; fast-user-switch injection suspension ([08 §3](../08-background-service.md#3-device-resilience-fr-4-nfr-3)) — implemented, live-verifiable only by actually fast-user-switching
- [x] os.Logger categories: `midi`, `dispatch`, `action`, `service`, `store` (+ `latency`); `feedback` lands in M5

### Tests
- [x] Trigger-detection tests on a virtual clock (press/hold-click/hold-threshold/double-tap/delayed-single/toggle persistence)
- [x] Store tests: round-trip, Global auto-creation + undeletable, quarantine, newer-schema refusal with file preservation, import renaming, undo
- [x] ProfileSwitcher resolution matrix (pinned wins / bound app / global fallback / stale pin)
- [ ] Idle-footprint check: accessory mode ~0% CPU, < 100 MB (NFR-2) — record numbers here after the demo run

## Acceptance criteria
- Roadmap demo: Xcode + Global profiles auto-switch on ⌘Tab; mappings survive relaunch; unplug/replug seamless; suspend/resume from menu bar.
- Hand-edited profile JSON with an unknown future `schemaVersion` is refused politely, not destroyed.
- Recorded idle footprint: ⏳ *(fill at completion)*
