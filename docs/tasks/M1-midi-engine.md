# M1 — MIDI Engine & Device Map Capture

**Goal:** reliable FLX4 connectivity and decoded control events; the physical device map fully captured into [03-device-ddj-flx4.md](../03-device-ddj-flx4.md).
**Prerequisites:** M0. **Spec refs:** FR-1…FR-6, [ADR-003](../99-decisions.md#adr-003-midi-via-midikit-over-raw-coremidi), [ADR-004](../99-decisions.md#adr-004-device-map-is-captured-not-guessed), [03 §5 methodology](../03-device-ddj-flx4.md#5-capture-methodology-m1).

## Tasks

### MIDIEngine
- [x] Add MIDIKit via SPM — now **SwiftMIDI** (`orchetect/swift-midi`, pinned from 1.1.0; MIDIKit rebranded at 1.0, see ADR-003 update). MIT license — add to About credits when About ships (M4)
- [x] MIDIEngine: manager lifecycle, input connection, typed event callback (FR-2) — `DeckPad/MIDIEngine/MIDIEngine.swift`
- [x] FLX4 endpoint identification (recorded in [03 §1](../03-device-ddj-flx4.md#1-device-facts): name `DDJ-FLX4`, mfr `AlphaTheta Corporation`)
- [x] Hot-plug: endpoint added/removed notifications → connected/disconnected state publisher (FR-4) — live-verify during capture session
- [x] MIDI output path: send raw messages to the device (FR-5 groundwork; first real use is LED pass e)

### DeviceLayer
- [x] `DeviceDescriptor` protocol + data-driven `DDJFLX4Descriptor` shell (table-based, per [03 §6](../03-device-ddj-flx4.md#6-descriptor-implementation-notes)) — decode table generated after capture
- [ ] Decoders: note→pressed/released, CC→value, MSB/LSB pairing for 14-bit (FR-2), relative decode for jogs/encoder, SHIFT-variant merging, jog-touch tracking (FR-3, FR-12 groundwork)
- [ ] Unknown-message policy: log once per session, drop (NFR-3)

### MIDI monitor (FR-6)
- [x] Monitor window: live stream table (time, raw, decoded), pause/clear ([05 §7](../05-ui-spec.md#7-midi-monitor-debug) — functional now; filters + polish in M4)
- [x] **Capture mode:** checklist walker over the [03 §2](../03-device-ddj-flx4.md#2-control-inventory) inventory order; records observation per prompt; exports Markdown table + raw `flx4-capture.json`

### Capture session (with the physical unit)
- [ ] Pass a: every control, base layer
- [ ] Pass b: every control with SHIFT held
- [ ] Pass c: continuous full-range sweeps (confirm 14-bit pairing, end values)
- [ ] Pass d: jog — touched turn / rim turn / touch only
- [ ] Pass e: LED experiments per [03 §4](../03-device-ddj-flx4.md#4-led-output-protocol-capture-pending) (button LEDs, pad RGB palette, echo behavior, rate limits)
- [ ] Populate [03 §3](../03-device-ddj-flx4.md#3-midi-map-table-capture-pending) + new LED map section; resolve/correct every ⏳ in §2 (loop section, master/headphone knobs analog?, effects section); update totals if inventory changed
- [ ] Cross-check vs. Pioneer MIDI list PDF + Mixxx mapping; note discrepancies inline
- [ ] Commit `docs/fixtures/flx4-capture.json`; generate descriptor table (Swift) from the captured data

### Tests
- [ ] DeviceLayer unit tests replaying `flx4-capture.json` fixture → expected ControlEvents (incl. 14-bit, shift, jog cases)

## Acceptance criteria
- Roadmap demo: monitor streams named ControlEvents live from the hardware; unplug/replug mid-stream recovers without restart.
- Zero ⏳ markers remain in [03-device-ddj-flx4.md](../03-device-ddj-flx4.md); its capture-pending note is deleted.
- Fixture-driven tests green without hardware attached.
