# M3 — Mapping System & Service Core

**Goal:** real user-defined mappings with profiles, persistence, trigger detection, and the sticky-service lifecycle.
**Prerequisites:** M2. **Spec refs:** FR-7, FR-10…FR-14, FR-20…FR-23, FR-31, FR-32, FR-50, NFR-2/3/7, [02-architecture.md](../02-architecture.md), [08-background-service.md](../08-background-service.md).

## Tasks

### Models & store
- [ ] Codable models exactly per [02 §2](../02-architecture.md#2-core-types-shared-vocabulary): `Mapping`, `Profile`, `Trigger`, `Action` (full catalog payloads), `FeedbackOverride`; `schemaVersion` from day one (NFR-7)
- [ ] MappingStore: load/save `profiles/<uuid>.deckpad.json` + `settings.json`, atomic writes, 500 ms save debounce, broken-file quarantine ([02 §5–6](../02-architecture.md#5-persistence))
- [ ] Import/export a profile as file (FR-23); duplicate/delete; undeletable Global (FR-20)
- [ ] Session undo stack for mapping edits (⌘Z support for M4)

### Dispatcher
- [ ] Serial hub queue; ControlEvent → active profile → mapping resolution with Global fallthrough (FR-21)
- [ ] Trigger detection: press/release/doubleTap (300 ms window + sibling delay rule)/hold(N ms, optional release action)/toggle with persisted state ([06 §9](../06-actions-catalog.md#9-trigger-semantics-recap-fr-13), FR-13)
- [ ] SHIFT layer routing (base vs. shift mapping slots, FR-14)
- [ ] Continuous coalescing @ 8 ms tick; soft-takeover/pickup mode with per-mapping "jump immediately" opt-out ([06 §7](../06-actions-catalog.md#7-continuous-targets-fr-11))
- [ ] Suspend gate (FR-32) — internal actions from M2 now fully wired

### ProfileSwitcher
- [ ] Frontmost-app watcher → auto-switch with Global fallback (FR-21)
- [ ] Manual pin/unpin (FR-22)
- [ ] Coexistence: DJ-app launch/quit watch → pause/resume per settings (FR-7, [08 §5](../08-background-service.md#5-coexistence-with-dj-software-fr-7)); bundle-ID list user-extensible in settings.json

### ServiceController
- [ ] Activation-policy state machine complete per [08 §1](../08-background-service.md#1-lifecycle-state-machine) (ActiveUI ↔ AccessoryService ↔ Suspended ↔ CoexistencePause)
- [ ] Single-instance guard; quit confirmation with suppress checkbox
- [ ] Sleep/wake re-validation; fast-user-switch injection suspension ([08 §3](../08-background-service.md#3-device-resilience-fr-4-nfr-3))
- [ ] os.Logger categories wired throughout ([08 §7](../08-background-service.md#7-logging--diagnostics))

### Tests
- [ ] Trigger-detection unit tests (double-tap windows, hold timing, toggle state) on virtualized clock
- [ ] Store round-trip + migration-refusal + quarantine tests
- [ ] ProfileSwitcher resolution matrix test (pinned/bound/global/coexistence)
- [ ] Idle-footprint check: accessory mode ~0% CPU, < 100 MB (NFR-2) — record numbers here

## Acceptance criteria
- Roadmap demo: Xcode + Global profiles auto-switch on ⌘Tab; mappings survive relaunch; unplug/replug seamless; suspend/resume from menu bar.
- Hand-edited profile JSON with an unknown future `schemaVersion` is refused politely, not destroyed.
- Recorded idle footprint: ⏳ *(fill at completion)*
