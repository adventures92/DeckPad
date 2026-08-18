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
- [x] Decoders: note→pressed/released (noteOn vel 0 = release), 14-bit MSB/LSB pairing (FR-2), 64-centered jog + two's-complement encoder relative decode, SHIFT tracking + variant-number merging, jog-touch tracking, mode-agnostic pad ranges (FR-3, FR-12 groundwork)
- [x] Unknown-message policy: decode to nothing, drop; monitor still displays raw (NFR-3)

### MIDI monitor (FR-6)
- [x] Monitor window: live stream table (time, raw, decoded), pause/clear ([05 §7](../05-ui-spec.md#7-midi-monitor-debug) — functional now; filters + polish in M4)
- [x] **Capture mode:** checklist walker over the [03 §2](../03-device-ddj-flx4.md#2-control-inventory) inventory order; records observation per prompt; exports Markdown table + raw `flx4-capture.json`

### Capture session (with the physical unit)
- [x] Pass a: every control, base layer (2026-08-18; all 64 controls MIDI-visible — even the "maybe analog" master/headphone knobs)
- [ ] Pass b: every control with SHIFT held → confirms/corrects the ® provisional values in [03 §3](../03-device-ddj-flx4.md#3-midi-map-captured-base-layer---reference-sourced-shift-variant-pending-pass-b)
- [x] Pass c: continuous full-range sweeps — 14-bit MSB/LSB (+0x20 rule) confirmed on every knob/fader/slider
- [x] Pass d: jog — touched/rim/touch-only captured (vinyl-off CC `0x23` still to confirm; see 03 §3.1)
- [ ] Pass e: LED experiments per [03 §4](../03-device-ddj-flx4.md#4-led-output-protocol-pass-e--pending) (echo rule, pad ranges, VU meters, SysEx position query, rate limits)
- [x] Populate [03 §3](../03-device-ddj-flx4.md) with captured base map; §2 ⏳ resolved (loop section confirmed; master/hp knobs are MIDI; FX section confirmed)
- [x] Cross-check vs. Mixxx mapping — capture only *added* controls (masterLevel, hpLevel, smartCX/Fader, FX LSB); Pioneer PDF is bot-gated, URL recorded in 03 §5
- [x] Commit `docs/fixtures/flx4-capture.json`; descriptor decode tables generated from capture (`DDJFLX4Descriptor.buildDecodeTables()`)

### Tests
- [x] DeviceLayer unit tests: 12 decoder tests + fixture replay (`FLX4DecoderTests`, `FLX4FixtureReplayTests`) — every captured message decodes, buttons map to documented ControlIDs; runs without hardware

## Acceptance criteria
- Roadmap demo: monitor streams named ControlEvents live from the hardware; unplug/replug mid-stream recovers without restart.
- Zero ⏳ markers remain in [03-device-ddj-flx4.md](../03-device-ddj-flx4.md); its capture-pending note is deleted.
- Fixture-driven tests green without hardware attached.
