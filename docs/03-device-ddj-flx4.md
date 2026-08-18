# Device Reference — Pioneer DJ DDJ-FLX4

The single supported device in v1. This document is the source of truth for the `DDJFLX4Descriptor` in the DeviceLayer ([02-architecture.md](02-architecture.md)).

**Status:** base-layer MIDI map **captured from the physical unit on 2026-08-18** (raw log: [fixtures/flx4-capture.json](fixtures/flx4-capture.json)), cross-checked against the Mixxx community mapping, per [ADR-004](99-decisions.md#adr-004-device-map-is-captured-not-guessed). Remaining: SHIFT pass (values marked ® below are reference-sourced, pending capture) and the LED output pass (§4).

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

Full list with kinds/sections: see `DDJFLX4Descriptor.buildInventory()` — identical IDs and order as the capture checklist. Sections: Deck 1 / Deck 2 (play, cue, sync, shift, 8 pads, 4 pad-mode buttons, loop in/out/reloop-exit, tempo, jog touch/platter/rim), Mixer (per-channel trim + 3-band EQ + CFX + cue + fader; crossfader, Smart Fader, Smart CX, master level, headphone mix/level), Effects (beat ◀/▶, select, ch-select switch, on/off, level/depth), Browser (encoder turn/press, load 1/2).

**Totals:** 64 physical controls; with the SHIFT layer (FR-14), ~120 mappable logical inputs.

## 3. MIDI map (captured base layer; ® = reference-sourced SHIFT variant, pending Pass B)

### 3.1 Decks (deck 1 = ch 0, deck 2 = ch 1)

| ControlID | Type | Num | SHIFT variant |
|---|---|---|---|
| `deckN.play` | Note | `0x0B` 11 | ® `0x0E` 14 |
| `deckN.cue` | Note | `0x0C` 12 | ® `0x48` 72 |
| `deckN.sync` | Note | `0x58` 88 | ® `0x60` 96 (long-press sends `0x5C` ® — undecoded, documented only) |
| `deckN.shift` | Note | `0x3F` 63 | — (the modifier itself) |
| `deckN.padModeHotCue` | Note | `0x1B` 27 | ® `0x69` 105 (Keyboard) |
| `deckN.padModePadFX` | Note | `0x1E` 30 | ® `0x6B` 107 (Pad FX 2) |
| `deckN.padModeBeatJump` | Note | `0x20` 32 | ® `0x6D` 109 (Beat Loop) |
| `deckN.padModeSampler` | Note | `0x22` 34 | ® `0x6F` 111 (Key Shift) |
| `deckN.loopIn` | Note | `0x10` 16 | ® `0x4C` 76 |
| `deckN.loopOut` | Note | `0x11` 17 | ® `0x4E` 78 |
| `deckN.reloopExit` | Note | `0x4D` 77 | ® `0x50` 80 |
| `deckN.tempo` | CC 14-bit | MSB `0x00` / LSB `0x20` | same ® |
| `deckN.jogTouch` | Note | `0x36` 54 | ® `0x67` 103 |
| `deckN.jog` (platter) | CC relative | `0x22` 34 touched · `0x23` 35 ® untouched (vinyl-off; unit was in vinyl mode during capture) | ® CC `0x29` 41 |
| `deckN.jogSide` (rim) | CC relative | `0x21` 33 | — |
| `mixer.chN.cue` | Note (on deck ch!) | `0x54` 84 | ® `0x68` 104 |

### 3.2 Performance pads (deck 1: ch 7, +SHIFT ch 8 · deck 2: ch 9, +SHIFT ch 10)

Note = mode base + (pad − 1). Captured in Sampler mode; other bases from reference ®, all decoded uniformly.

| Pad mode | Note range |
|---|---|
| Hot Cue | ® `0x00`–`0x07` |
| Pad FX | ® `0x10`–`0x17` |
| Beat Jump | ® `0x20`–`0x27` |
| Sampler | ✅ `0x30`–`0x37` (captured) |
| Keyboard / Beat Loop / Key Shift (2nd layer) | ® `0x40`– / `0x60`– / `0x70`– |

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
| `mixer.smartCX` | 6 | Note | `0x00` 0 — **not in community map** |
| `mixer.smartFader` | 6 | Note | `0x01` 1 — **not in community map** |

### 3.4 Beat FX

| ControlID | Ch | Type | Num | Notes |
|---|---|---|---|---|
| `fx.beatLeft` / `fx.beatRight` | 4 | Note | `0x4A` 74 / `0x4B` 75 | |
| `fx.select` | 4 | Note | `0x63` 99 | ® SHIFT `0x64` 100 |
| `fx.onOff` | 4 **and** 5 | Note | `0x47` 71 | channel reflects CH SELECT position; ® SHIFT `0x43` 67 |
| `fx.chSelect` | 4 & 5 | Note | `0x10` 16 (CH1) · `0x11` 17 (CH2) | 3-position switch; positions emit note on/off pairs across ch 4/5 |
| `fx.levelDepth` | 4 | CC 14-bit | `0x02`/`0x22` | LSB not in community map — captured |

### 3.5 Browser (ch 6)

| ControlID | Type | Num | SHIFT variant |
|---|---|---|---|
| `browser.encoder` | CC relative (two's-compl.) | `0x40` 64 | ® CC `0x64` 100 |
| `browser.encoderPress` | Note | `0x41` 65 | ® `0x42` 66 |
| `browser.load1` / `.load2` | Note | `0x46` 70 / `0x47` 71 | — |

### Capture artifacts & open questions

1. Some pad Note On rows are missing from the aggregate (collection-window timing); note numbers confirmed by the contiguous `0x30`–`0x37` pattern.
2. The Mixxx map lists CUE/LOOP CALL ◀/▶ buttons (`0x51`/`0x53`) — likely a DDJ-400 carry-over. **Ask/verify: does the FLX4 have any unprompted buttons left?** If yes, capture ad hoc via the monitor.
3. `0x23` (vinyl-off platter turn) pending confirmation — toggle vinyl mode off (SHIFT+jog-mode per manual ®) and turn the platter.

## 4. LED output protocol (pass E — pending)

Reference expectations to verify against hardware (from the Mixxx mapping; all output is host-driven):

1. **Echo rule:** send the control's own (status, note) with velocity `0x7F` to light, `0x00` to extinguish — no RGB palette; strictly on/off.
2. Pads light per pad-mode range and channel (incl. SHIFT channels 8/10 as separate LED layers).
3. **VU meters:** CC `0x02` on ch 0/1, value 0–127.
4. Track-load animation: Note ch 15, note = deck index, vel `0x7F`.
5. Blinking is host-driven (timers), not firmware.
6. A keep-alive/position-query SysEx `F0 00 40 05 00 00 04 05 00 50 02 F7` reportedly makes the unit report all analog control positions — useful for soft-takeover initialization; verify.

Record verified results in a `## LED map` table here after the pass.

## 5. Capture methodology & status

Tooling: DeckPad's MIDI monitor **capture mode** ([05-ui-spec.md §7](05-ui-spec.md#7-midi-monitor-debug)) walking this doc's inventory order; exports Markdown + `flx4-capture.json` (replayed by `FLX4FixtureReplayTests` so CI needs no hardware).

| Pass | Status |
|---|---|
| a — base layer, every control | ✅ 2026-08-18 |
| b — SHIFT layer | ⏳ pending (® values above await it) |
| c — continuous full-range sweeps / 14-bit confirmation | ✅ (within pass a) |
| d — jog touched/rim/touch-only | ✅ (within pass a; vinyl-off `0x23` open) |
| e — LED experiments | ⏳ pending |

Cross-references: Pioneer DJ official *DDJ-FLX4 MIDI message list* PDF (`pioneerdj.com/-/media/pioneerdj/software-info/controller/ddj-flx4/ddj-flx4_midi_message_list_e1.pdf` — bot-gated, open in a browser) and the Mixxx mapping (`mixxxdj/mixxx` → `res/controllers/Pioneer-DDJ-FLX4.midi.xml` + script). Capture disagreed with the community map only by *adding* controls (master level, hp level, Smart CX/Fader, FX level LSB).

## 6. Descriptor implementation notes

- `DDJFLX4Descriptor` is data-driven per this table (`buildDecodeTables()`), stateful for SHIFT / jog-touch / MSB latching. ® values are marked "provisional" in code comments and get confirmed or corrected by Pass B.
- Canvas layout (`flx4-layout.json`, normalized geometry per ControlID) is authored in M4 ([05-ui-spec.md §3](05-ui-spec.md#3-controller-canvas)).
- Unknown messages decode to nothing and are dropped (NFR-3); the monitor still shows them raw for diagnosis.
