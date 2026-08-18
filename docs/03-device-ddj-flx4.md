# Device Reference — Pioneer DJ DDJ-FLX4

The single supported device in v1. This document is the source of truth for the `DDJFLX4Descriptor` in the DeviceLayer ([02-architecture.md](02-architecture.md)).

**Status:** control inventory drafted from the hardware; the MIDI map table below is **capture-pending** (⏳) by design — exact channel/number/value data is recorded from the physical unit in milestone [M1](tasks/M1-midi-engine.md), per [ADR-004](99-decisions.md#adr-004-device-map-is-captured-not-guessed). These ⏳ cells are the only sanctioned TBDs in the doc set.

## 1. Device facts

| Property | Value |
|---|---|
| Manufacturer | AlphaTheta (Pioneer DJ) |
| Model | DDJ-FLX4 (2-channel) |
| Connection | USB-C (also works on USB bus power); Bluetooth MIDI **not** supported by the unit for control — USB only |
| Class compliance | USB class-compliant MIDI — no driver needed on macOS |
| MIDI direction | Bidirectional: sends control input; receives LED/display messages |
| Audio | Built-in audio interface — **explicitly unused** by DeckPad (non-goal, [01-requirements.md §4](01-requirements.md#4-explicit-non-goals-v1)) |
| Identification | ✅ Confirmed on hardware (M1): endpoint name `DDJ-FLX4`, display name `DDJ-FLX4`, manufacturer `AlphaTheta Corporation`, model `DDJ-FLX4` — one source + one destination |

## 2. Control inventory

Grouped by physical section. `ControlID` values are canonical — code, UI hotspots, and profile JSON all use them. Deck 2 mirrors deck 1 (`deck2.*`).

### 2.1 Deck section (×2)

| ControlID | Physical control | Kind | Notes |
|---|---|---|---|
| `deckN.play` | PLAY/PAUSE button | button | LED-capable |
| `deckN.cue` | CUE button | button | LED-capable |
| `deckN.sync` | BEAT SYNC button | button | LED-capable |
| `deckN.shift` | SHIFT button | button | **Reserved as layer modifier** (FR-14) — not mappable itself |
| `deckN.pad1` … `deckN.pad8` | Performance pads 1–8 | pad | RGB LED-capable |
| `deckN.padModeHotCue` | HOT CUE mode button | button | Pad mode buttons are mappable like any button; DeckPad ignores DJ semantics |
| `deckN.padModePadFX` | PAD FX mode button | button | |
| `deckN.padModeBeatJump` | BEAT JUMP mode button | button | |
| `deckN.padModeSampler` | SAMPLER mode button | button | |
| `deckN.loopIn` | LOOP IN / 4BEAT button | button | Loop-section enumeration ⏳ verified in M1 capture |
| `deckN.loopOut` | LOOP OUT button | button | ⏳ |
| `deckN.reloopExit` | RELOOP/EXIT button | button | ⏳ |
| `deckN.tempo` | TEMPO slider | slider | Likely 14-bit (MSB/LSB) ⏳ |
| `deckN.jog` | Jog wheel — platter rotation (top touched) | jog | Relative encoder ⏳ value semantics |
| `deckN.jogSide` | Jog wheel — rim rotation (untouched) | jog | Relative ⏳ |
| `deckN.jogTouch` | Jog wheel — capacitive touch | button | Used as modifier for jog mappings (FR-12) |

### 2.2 Mixer section

| ControlID | Physical control | Kind | Notes |
|---|---|---|---|
| `mixer.ch1.trim` / `mixer.ch2.trim` | TRIM knobs | knob | |
| `mixer.ch1.eqHi` / `.eqMid` / `.eqLow` (×2 ch) | EQ knobs | knob | Likely 14-bit ⏳ |
| `mixer.ch1.cfx` / `mixer.ch2.cfx` | CFX (color FX) knobs | knob | |
| `mixer.ch1.cue` / `mixer.ch2.cue` | Headphone CUE buttons | button | LED-capable |
| `mixer.ch1.fader` / `mixer.ch2.fader` | Channel faders | fader | Likely 14-bit ⏳ |
| `mixer.crossfader` | Crossfader | fader | Likely 14-bit ⏳ |
| `mixer.smartFader` | SMART FADER button | button | LED-capable |
| `mixer.smartCX` | SMART CX button | button | LED-capable |
| `mixer.masterLevel` | MASTER LEVEL knob | knob | ⏳ May be analog-only (no MIDI) — verify; if analog, excluded from canvas mappable set |
| `mixer.hpMix` | HEADPHONES MIXING knob | knob | ⏳ possibly analog-only |
| `mixer.hpLevel` | HEADPHONES LEVEL knob | knob | ⏳ possibly analog-only |
| — | MIC LEVEL knob | — | Analog; not MIDI-visible; shown on canvas as decorative only ⏳ confirm |

### 2.3 Effects section

Enumeration drafted from the DDJ-400-family layout; ⏳ verify against the physical FLX4 in M1.

| ControlID | Physical control | Kind | Notes |
|---|---|---|---|
| `fx.beatLeft` / `fx.beatRight` | BEAT ◄ / ► buttons | button | ⏳ |
| `fx.select` | BEAT FX SELECT | button | ⏳ |
| `fx.chSelect` | BEAT FX CH SELECT | button/switch | ⏳ message behavior unknown |
| `fx.onOff` | BEAT FX ON/OFF | button | LED-capable ⏳ |
| `fx.levelDepth` | BEAT FX LEVEL/DEPTH knob | knob | ⏳ |

### 2.4 Browse section

| ControlID | Physical control | Kind | Notes |
|---|---|---|---|
| `browser.encoder` | Rotary selector — turn | encoder | Relative ⏳ |
| `browser.encoderPress` | Rotary selector — press | button | |
| `browser.load1` / `browser.load2` | LOAD buttons | button | LED-capable |

**Totals:** ~60 physical MIDI controls; with the SHIFT layer (FR-14) each mappable control carries two logical slots → **~110+ mappable inputs**, matching the "~100 inputs" claim in [00-overview.md](00-overview.md).

## 3. MIDI map table (capture-pending)

Filled in during the M1 capture session. Columns: message type (Note/CC), MIDI channel, number, value semantics, shift-layer variant.

| ControlID | Type | Ch | Num | Value semantics | SHIFT variant | Status |
|---|---|---|---|---|---|---|
| `deck1.play` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| *(one row per control in §2, same order)* | | | | | | |

> The table is deliberately not pre-populated with guessed values. Populate it **only** from monitor captures; cross-check against the two references in §5. When complete, delete this note, set every Status to ✅, and remove §2's ⏳ markers or correct the inventory.

### Expected conventions to verify (not assume)

- **Shift variants:** Pioneer controllers typically emit *different* note/CC numbers while SHIFT is held, rather than a shift flag. If confirmed, DeviceLayer maps both numbers to one ControlID with `shifted: true/false`.
- **14-bit CCs:** faders/tempo/EQ typically send MSB on CC *n* and LSB on CC *n+32*. DeviceLayer must pair them (FR-2).
- **Jog encoding:** typically CC with center-offset relative values (64 = rest; >64 forward ticks, <64 backward). Top-touched vs. rim rotation arrive as different CC numbers; touch itself as a note.
- **Note on/off:** buttons likely send Note On velocity 127 on press and Note Off (or velocity 0) on release.

## 4. LED output protocol (capture-pending)

Needed for FR-5 / feedback channel 4 ([07-feedback-system.md](07-feedback-system.md)).

To determine in M1 (experiment + references):

1. Which messages light each button LED (likely Note On to the button's own note/channel; velocity = brightness or on/off).
2. Pad RGB: whether velocity selects from a fixed color palette, and the palette's value→color table.
3. Whether the unit echoes its own state (LED local-off vs. host-controlled when a DAW/DJ app isn't holding the device).
4. Rate limits: max safe MIDI-out throughput before the unit lags (matters for LED animations).

Record findings in a `## LED map` table appended to this file, same format as §3.

## 5. Capture methodology (M1)

1. **Tooling:** DeckPad's own MIDI monitor ([05-ui-spec.md §7](05-ui-spec.md#7-midi-monitor-debug)) in *capture mode*: it walks this document's control list, prompts "actuate `deck1.play`", records the observed message, and exports the finished table as Markdown to paste into §3.
2. **Passes:** (a) every control base layer; (b) every control with SHIFT held; (c) continuous controls full-range sweep to confirm 14-bit pairing and end values; (d) jog: touched turn / untouched turn / touch only; (e) LED experiments per §4.
3. **Cross-checks:**
   - Pioneer DJ official **DDJ-FLX4 MIDI message list** PDF (pioneerdj.com → Support → DDJ-FLX4 → Software & firmware / documents).
   - **Mixxx** community mapping for DDJ-FLX4 (`mixxxdj/mixxx` repo, `res/controllers/`), battle-tested value tables.
   Discrepancies between capture and references: trust the capture, note the discrepancy inline.
4. **Regression fixture:** export the raw capture log as `docs/fixtures/flx4-capture.json` (created in M1) so DeviceLayer unit tests replay real traffic without hardware.

## 6. Descriptor implementation notes

- `DDJFLX4Descriptor` is **data-driven**: a static table generated from §3 (ControlID ↔ message triplets), not per-control code. The M1 exporter emits this table as Swift.
- Canvas layout (normalized x/y/w/h per ControlID for the UI replica) lives beside it as `flx4-layout.json` — created during M4 asset work ([05-ui-spec.md §3](05-ui-spec.md#3-controller-canvas)).
- Unknown messages (future firmware, unlisted controls) are logged once per session and dropped (NFR-3).
