# Device Reference — Pioneer DJ DDJ-FLX4

The single supported device in v1. This document is the source of truth for the `DDJFLX4Descriptor` in the DeviceLayer ([02-architecture.md](02-architecture.md)).

**Status:** base layer **and** SHIFT layer captured from the physical unit on 2026-08-18 (raw log: [fixtures/flx4-capture.json](fixtures/flx4-capture.json), 150 entries), cross-checked against the Mixxx community mapping, per [ADR-004](99-decisions.md#adr-004-decision-device-map-is-captured-not-guessed). Every reference-sourced SHIFT value was confirmed; capture additionally found mappings the community map lacks. Remaining: the CUE/LOOP CALL ◀/▶ buttons (missed in the original inventory — values marked ® are reference-sourced, targeted capture in progress) and the LED output pass (§4).

## 1. Device facts

| Property | Value |
|---|---|
| Manufacturer | AlphaTheta (Pioneer DJ) |
| Model | DDJ-FLX4 (2-channel) |
| Connection | USB-C (USB bus powered); control is USB-MIDI only |
| Class compliance | USB class-compliant MIDI — no driver needed on macOS |
| MIDI direction | Bidirectional: sends control input; receives LED messages |
| Audio | Built-in audio interface — **explicitly unused** by DeckPad ([01-requirements.md §4](01-requirements.md#4-explicit-non-goals-v1)) |
| Identification | ✅ Confirmed (M1): endpoint name `DDJ-FLX4`, manufacturer `AlphaTheta Corporation`, model `DDJ-FLX4` — one source + one destination |

### Protocol conventions (captured)

- **Channels:** deck 1 = ch 0, deck 2 = ch 1 · Beat FX = ch 4/5 · browser + master section = ch 6 · pads deck 1 = ch 7 (**ch 8 with SHIFT**), pads deck 2 = ch 9 (**ch 10 with SHIFT**).
- **Buttons:** Note On velocity 127 on press; release arrives as Note Off (the hardware's note-on-velocity-0 is normalized to Note Off by SwiftMIDI — the decoder accepts both).
- **SHIFT layering:** pads switch *channel* under SHIFT; every other control switches to a different note/CC *number* (® values in §3).
- **Continuous controls:** all 14-bit — MSB on CC *n*, LSB on CC *n + 0x20*, value = `(MSB << 7) | LSB` over 0–16383.
- **Jog encoding:** 64-centered relative (value − 64 = signed ticks). **Browse encoder:** two's-complement relative (1…63 = forward, 127…65 = −1…−63).
- **Pad note numbers depend on the active pad mode** — same pad, different note range per mode (§3.2). DeckPad decodes all ranges to the same `deckN.padK`, so mappings are pad-mode-agnostic.

## 2. Control inventory

All 64 physical controls confirmed MIDI-visible, including the master/headphone knobs previously suspected analog-only. `ControlID`s are canonical across code, UI, and profile JSON. Deck 2 mirrors deck 1 (`deck2.*`). The MIC LEVEL knob is analog (not in the MIDI capture surface) and is decorative-only on the canvas.

Full list with kinds/sections: see `DDJFLX4Descriptor.buildInventory()` — identical IDs and order as the capture checklist. Sections: Deck 1 / Deck 2 (play, cue, sync, shift, 8 pads, 4 pad-mode buttons, loop in/out/reloop-exit, **cue/loop call ◀/▶**, tempo, jog touch/platter/rim), Mixer (per-channel trim + 3-band EQ + CFX + cue + fader; crossfader, Smart Fader, Smart CX, master level, headphone mix/level), Effects (beat ◀/▶, select, ch-select switch, on/off, level/depth), Browser (encoder turn/press, load 1/2).

The firmware also emits **auxiliary trigger notes** with no dedicated physical control: SHIFT + channel-fader movement sends `deckN.faderStart` (Note `0x52` on the deck channel) and SHIFT + crossfader movement sends `deckN.xfaderStart` (Note `0x66`) — captured in Pass B. Decoded, not yet in the mappable inventory (M3/M4 decision).

**Totals:** 68 physical controls; with the SHIFT layer (FR-14), ~130 mappable logical inputs.

## 3. MIDI map (captured, both layers; ® = reference-sourced, targeted capture pending)

### 3.1 Decks (deck 1 = ch 0, deck 2 = ch 1)

| ControlID | Type | Num | SHIFT variant (captured) |
|---|---|---|---|
| `deckN.play` | Note | `0x0B` 11 | `0x0E` 14 (deck 2 captured; deck 1 window artifact, confirmed by symmetry) |
| `deckN.cue` | Note | `0x0C` 12 | `0x48` 72 |
| `deckN.sync` | Note | `0x58` 88 | `0x60` 96 (long-press reportedly sends `0x5C` ® — undecoded, documented only) |
| `deckN.shift` | Note | `0x3F` 63 | — (the modifier itself) |
| `deckN.padModeHotCue` | Note | `0x1B` 27 | `0x69` 105 (Keyboard) |
| `deckN.padModePadFX` | Note | `0x1E` 30 | `0x6B` 107 (Pad FX 2) |
| `deckN.padModeBeatJump` | Note | `0x20` 32 | `0x6D` 109 (Beat Loop) |
| `deckN.padModeSampler` | Note | `0x22` 34 | `0x6F` 111 (Key Shift) |
| `deckN.loopIn` | Note | `0x10` 16 | `0x4C` 76 |
| `deckN.loopOut` | Note | `0x11` 17 | `0x4E` 78 |
| `deckN.reloopExit` | Note | `0x4D` 77 | `0x50` 80 |
| `deckN.cueLoopLeft` | Note | `0x51` 81 | `0x3E` 62 |
| `deckN.cueLoopRight` | Note | `0x53` 83 | `0x3D` 61 |
| `deckN.tempo` | CC 14-bit | MSB `0x00` / LSB `0x20` | same numbers (SHIFT tracked by state) |
| `deckN.jogTouch` | Note | `0x36` 54 | `0x67` 103 |
| `deckN.jog` (platter) | CC relative | `0x22` 34 touched · `0x23` 35 ® untouched (unit was in vinyl mode both passes) | CC `0x29` 41 |
| `deckN.jogSide` (rim) | CC relative | `0x21` 33 | same number |
| `mixer.chN.cue` | Note (on deck ch!) | `0x54` 84 | `0x68` 104 |
| `deckN.faderStart` (aux) | Note | `0x52` 82 — fires on SHIFT + channel-fader move | — |
| `deckN.xfaderStart` (aux) | Note | `0x66` 102 — fires on SHIFT + crossfader move | — |

### 3.2 Performance pads (deck 1: ch 7, +SHIFT ch 8 · deck 2: ch 9, +SHIFT ch 10)

Note = mode base + (pad − 1). Captured in Sampler mode; other bases from reference ®, all decoded uniformly.

| Pad mode | Note range |
|---|---|
| Hot Cue | ✅ `0x00`–`0x07` (Pass B) |
| Pad FX | ✅ `0x10`–`0x17` (targeted capture) |
| Beat Jump | ✅ `0x20`–`0x27` (targeted capture) |
| Sampler | ✅ `0x30`–`0x37` (Pass A) |
| Keyboard / Beat Loop / Key Shift (2nd layer) | ✅ `0x40`– / `0x60`– / `0x70`– (targeted capture) |

All seven ranges empirically verified 2026-08-18.

### 3.3 Mixer

| ControlID | Ch | Type | Num (MSB/LSB) |
|---|---|---|---|
| `mixer.chN.trim` | deck ch | CC 14-bit | `0x04`/`0x24` |
| `mixer.chN.eqHi` | deck ch | CC 14-bit | `0x07`/`0x27` |
| `mixer.chN.eqMid` | deck ch | CC 14-bit | `0x0B`/`0x2B` |
| `mixer.chN.eqLow` | deck ch | CC 14-bit | `0x0F`/`0x2F` |
| `mixer.chN.fader` | deck ch | CC 14-bit | `0x13`/`0x33` |
| `mixer.ch1.cfx` / `.ch2.cfx` | 6 | CC 14-bit | `0x17`/`0x37` · `0x18`/`0x38` |
| `mixer.crossfader` | 6 | CC 14-bit | `0x1F`/`0x3F` |
| `mixer.masterLevel` | 6 | CC 14-bit | `0x08`/`0x28` — **MIDI-visible** (not in community map) |
| `mixer.hpMix` | 6 | CC 14-bit | `0x0C`/`0x2C` |
| `mixer.hpLevel` | 6 | CC 14-bit | `0x0D`/`0x2D` — **MIDI-visible** (not in community map) |
| `mixer.smartCX` | 6 | Note | `0x00` 0, SHIFT `0x08` 8 — **not in community map** |
| `mixer.smartFader` | 6 | Note | `0x01` 1, SHIFT `0x09` 9 — **not in community map** |

### 3.4 Beat FX

| ControlID | Ch | Type | Num | Notes |
|---|---|---|---|---|
| `fx.beatLeft` / `fx.beatRight` | 4 | Note | `0x4A` 74 / `0x4B` 75 | SHIFT `0x66` 102 / `0x6B` 107 — **not in community map** |
| `fx.select` | 4 | Note | `0x63` 99 | SHIFT `0x64` 100 |
| `fx.onOff` | 4 **and** 5 | Note | `0x47` 71 | channel reflects CH SELECT position; SHIFT `0x43` 67 (both ch) |
| `fx.chSelect` | 4 & 5 | Note | `0x10` 16 (CH1) · `0x11` 17 (CH2) | 3-position switch; positions emit note on/off pairs across ch 4/5 |
| `fx.levelDepth` | 4 | CC 14-bit | `0x02`/`0x22` | LSB not in community map — captured |

### 3.5 Browser (ch 6)

| ControlID | Type | Num | SHIFT variant (captured) |
|---|---|---|---|
| `browser.encoder` | CC relative (two's-compl.) | `0x40` 64 | CC `0x64` 100 |
| `browser.encoderPress` | Note | `0x41` 65 | `0x42` 66 |
| `browser.load1` / `.load2` | Note | `0x46` 70 / `0x47` 71 | `0x68` 104 / `0x7A` 122 — **not in community map** |

### Capture artifacts & open questions

1. Some pad Note On rows are missing from the aggregates (collection-window timing); note numbers confirmed by the contiguous range patterns across both passes.
2. `deck1.play` SHIFT entry caught only the SHIFT press itself (window artifact); `0x0E` confirmed via deck 2 symmetry.
3. CUE/LOOP CALL ◀/▶ were missed in the original inventory (wrongly assumed DDJ-400-only); captured via targeted sniffer 2026-08-18 — reference values confirmed. The raw sniff also confirmed the hardware sends releases as note-on velocity 0 (SwiftMIDI normalizes these to note-off).
4. **Remaining reference-only (®) values, accepted as-is:** `0x23` vinyl-off platter turn (no hardware vinyl toggle found; decoder maps it anyway), `0x5C` sync long-press (documented only, undecoded), and the ch 15 track-load LED animation. None block any feature.

## 4. LED output protocol (captured, pass E — 2026-08-18)

Verified against hardware, interactively. The unit has **two LED classes** with different rules:

### 4.1 Simple button LEDs — work anytime (standalone included)

Echo rule confirmed: send the control's own input (status, note) with velocity `0x7F` to light, `0x00` to extinguish. Verified: `deckN.play`, `deckN.cue`, `deckN.sync` (steady), `mixer.smartCX`, `mixer.smartFader` (steady), `fx.onOff` (**lights but blinks under host control** — firmware quirk). **`browser.load1/2` have no LEDs at all.** No handshake needed for this class.

### 4.2 Pad matrix + mode indicators — host-controlled mode only

- Pad LEDs (and pad-mode indicator behavior) respond **only while the keep-alive SysEx streams**: `F0 00 40 05 00 00 04 05 00 50 02 F7` at ~200 ms cadence. A single SysEx does nothing; when the stream stops, the unit reverts to standalone and host-lit pads/mode LEDs go dark.
- Entering host mode lights the HOT CUE mode indicators on both decks (firmware default state).
- Pad writes must use the note range of the deck's **currently active pad mode** (writes in other ranges are ignored). DeckPad must track mode-button presses (visible as input) to know which range renders.
- **Velocity is effectively binary**: mid velocities (8–80) don't visibly light; use `0x7F`/`0x00` only. Color is the firmware's per-mode palette (Hot Cue = orange); no host RGB control discovered — matches the community mapping.

### 4.3 Channel level meters

CC `0x02` on ch 0 (left) / ch 1 (right), value 0–127 → 5-segment bar (64 ≈ top of green). **Firmware decays the meters within a few seconds** — hold a level by refreshing continuously.

### 4.4 Implications for FeedbackCenter (M5)

1. Run the keep-alive timer whenever LED feedback is enabled; stop it on suspend/coexistence-pause (LEDs revert on their own).
2. Track each deck's active pad mode; write ambient pad state in that range; re-assert the full LED scene on mode change, reconnect, and profile switch.
3. Treat all LEDs as binary. Meters need continuous refresh if used as a value display.
4. Not yet explored (non-blocking, extend during M5): per-mode pad palette colors, SHIFT-channel (8/10) LED layers, track-load animation (ch 15 ®), throughput limits beyond the 200 ms cadence used here.

## 5. Capture methodology & status

Tooling: DeckPad's MIDI monitor **capture mode** ([05-ui-spec.md §7](05-ui-spec.md#7-midi-monitor-debug)) walking this doc's inventory order; exports Markdown + `flx4-capture.json` (replayed by `FLX4FixtureReplayTests` so CI needs no hardware).

| Pass | Status |
|---|---|
| a — base layer, every control | ✅ 2026-08-18 |
| b — SHIFT layer | ✅ 2026-08-18 — all reference values confirmed; new: load/beat/smart SHIFT variants, fader-start aux notes |
| b2 — CUE/LOOP CALL targeted capture | ✅ 2026-08-18 (base + SHIFT, both decks) |
| b3 — pad-mode note ranges targeted capture | ✅ 2026-08-18 (all 7 ranges empirical) |
| c — continuous full-range sweeps / 14-bit confirmation | ✅ (within pass a) |
| d — jog touched/rim/touch-only | ✅ (both passes; vinyl-off `0x23` open) |
| e — LED experiments | ✅ 2026-08-18 (interactive session; see §4) |

Cross-references: Pioneer DJ official *DDJ-FLX4 MIDI message list* PDF (`pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf` — bot-gated, open in a browser) and the Mixxx mapping (`mixxxdj/mixxx` → `res/controllers/Pioneer-DDJ-FLX4.midi.xml` + script). Capture disagreed with the community map only by *adding* controls (master level, hp level, Smart CX/Fader, FX level LSB).

## 6. Descriptor implementation notes

- `DDJFLX4Descriptor` is data-driven per this table (`buildDecodeTables()`), stateful for SHIFT / jog-touch / MSB latching. ® values are marked "provisional" in code comments and get confirmed or corrected by Pass B.
- Canvas layout (`flx4-layout.json`, normalized geometry per ControlID) is authored in M4 ([05-ui-spec.md §3](05-ui-spec.md#3-controller-canvas)).
- Unknown messages decode to nothing and are dropped (NFR-3); the monitor still shows them raw for diagnosis.
