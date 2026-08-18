# DeckPad — UI Specification

Screens, layout, and interaction rules. Visual tokens/components come from [04-design-language.md](04-design-language.md); requirement IDs from [01-requirements.md](01-requirements.md).

## 1. Window anatomy (main window)

Three-pane, Raycast/Slack-inspired:

```
┌────────────────────────────────────────────────────────────────┐
│ ⬤⬤⬤   [Profile ▾]  [● DDJ-FLX4]        [Monitor] [⌘K] [⚙]     │  toolbar (glass)
├──────────┬──────────────────────────────────────┬──────────────┤
│ Profiles │                                      │  Inspector   │
│ sidebar  │        Controller canvas             │  (mapping    │
│ (glass)  │        (FLX4 replica on dark         │   editor,    │
│          │         stage canvas)                │   glass)     │
│          │                                      │              │
├──────────┴──────────────────────────────────────┴──────────────┤
│ status strip: active profile · last action fired · MIDI activity dot │
└────────────────────────────────────────────────────────────────┘
```

- Sidebar and inspector are collapsible; canvas is never smaller than a readable replica (min window 1080×640).
- Toolbar: profile picker (with pin state), device status pill (`PillBadge`: connected/disconnected/paused), MIDI monitor toggle, ⌘K quick-assign, settings.
- Window close → accessory mode (FR-50); reopening restores exact layout state.

## 2. Profiles sidebar

- Rows: profile name + bound-app icons (stacked, max 3 + overflow count) + active indicator; Global pinned at top, undeletable (FR-20).
- Actions (context menu + footer buttons): New, Duplicate, Delete (confirm), Export…, Import… (FR-23), Bind apps… (opens app picker listing running + /Applications apps by bundle ID) (FR-21).
- Pin: right-click → "Pin profile" or the pin icon on hover; pinned profile shows `pin.fill` and suspends auto-switch (FR-22).
- Drag a `.deckpad.json` file into the sidebar to import.

## 3. Controller canvas

The centerpiece (FR-60). A vector replica of the FLX4 top plate, drawn from `flx4-layout.json` (normalized coords per ControlID — our own generated asset, [03-device-ddj-flx4.md §6](03-device-ddj-flx4.md#6-descriptor-implementation-notes)).

- **Rendering:** chassis in `bg.deviceBody`, controls as vector shapes; deck-1/deck-2/mixer sections tinted per tokens. Decorative-only elements (analog knobs, logos) drawn dimmed and non-interactive.
- **Hotspots:** every mappable ControlID is a `ControlHotspot` with the five states from [04 §2](04-design-language.md#hotspot-states-on-the-replica). Mapped hotspots show a mini label chip (mapping `label`, truncated).
- **Hover:** tooltip = control name + current mapping(s) (base + SHIFT) + live value for continuous controls.
- **Click:** selects the control → inspector shows its mapping editor. Double-click: jumps straight into action picker.
- **Live echo (FR-62):** physical actuation lights the hotspot's Active state in real time; continuous controls animate their drawn position (fader caps move, knobs rotate, jog ring spins).
- **SHIFT toggle:** a canvas-corner segmented control (Base / SHIFT) previews the shift layer's chips; holding physical SHIFT does the same temporarily (FR-14).
- **Zoom:** fit-to-window default; ⌘+/− steps; trackpad pinch.

## 4. Inspector — mapping editor (FR-61)

Shown when a control is selected. Sections top-to-bottom:

1. **Header:** control name (`deck1.pad3`), kind icon, live value/state readout (SF Mono), section tint.
2. **Layer tabs:** Base / SHIFT (hidden for `deckN.shift` itself, which is reserved).
3. **Trigger picker:** segmented by control kind — buttons/pads: press, release, double-tap, hold (duration stepper), toggle (FR-13); continuous: continuous (with curve + range); jogs/encoders: relative mode picker (FR-12).
4. **Action picker:** `ActionRow` button opening the searchable action list (same data source as ⌘K palette); grouped per [06-actions-catalog.md](06-actions-catalog.md) categories.
5. **Parameter form:** per action type (key-combo recorder rendering `KeyCapView`s, file/app pickers, script text editor with monospace, Shortcut dropdown listing the user's Shortcuts, curve editor for continuous).
6. **Feedback override:** inherit / on / off per channel, compact matrix ([07-feedback-system.md §3](07-feedback-system.md#3-configuration-matrix)).
7. **Footer:** "Test" (executes the action now, with feedback), "Remove mapping", label text field.

Edits apply live — no Save button (FR-61). Undo via ⌘Z (MappingStore keeps an undo stack for the session).

## 5. ⌘K quick-assign palette

Raycast-style command palette, floating glass, morphs out of the inspector (`glassEffectID`).

- Flow A (action-first): ⌘K → search action → Enter → palette prompts "press a control" → user clicks a hotspot **or actuates the physical control** (MIDI-learn, FR-15) → mapping created on the active profile.
- Flow B (control-first): select hotspot → ⌘K → search → Enter assigns to selection.
- Fuzzy search over action names, categories, and existing mapping labels.

## 6. Settings (FR-53)

Standard `Settings` scene, glass panels, tabs:

| Tab | Contents |
|---|---|
| General | Launch at login (FR-51), coexistence behavior picker (FR-7: pause automatically / keep running), re-run onboarding |
| Feedback | Global channel matrix + live preview buttons per channel ([07 §3](07-feedback-system.md#3-configuration-matrix)) |
| Permissions | Status rows (Accessibility, Automation targets, Login item) with granted/missing badges + "Open System Settings" deep links ([08 §4](08-background-service.md#4-permissions-acquisition-ux)) |
| Profiles | Import/export, default-profile behavior, reset to defaults |
| About | Version, credits, licenses (MIDIKit), link to docs |

## 7. MIDI monitor (debug) (FR-6)

A utility window (also reachable from menu bar while in accessory mode).

- **Stream table:** time, raw message (SF Mono), decoded ControlID, value, active-profile resolution result. Row tint per section (deck.one/deck.two/mixer tokens). Pause/resume, clear, filter by section/kind/unmapped-only.
- **Copy/export:** rows as JSON or CSV.
- **Capture mode:** the M1 workhorse ([03 §5](03-device-ddj-flx4.md#5-capture-methodology-m1)): loads the control checklist from the device doc order, prompts each actuation, records the observed message, exports the finished MIDI-map table as Markdown and the raw log as `flx4-capture.json`.

## 8. Menu bar extra

Icon: DeckPad glyph; states — normal (connected), dimmed (no device), pause badge (coexistence), warning badge (permission lost).

Menu:
1. Device status line (name + connection)
2. Active profile submenu: radio list of profiles + "Pinned" toggle (FR-22)
3. "Suspend DeckPad" toggle (FR-32)
4. "Open DeckPad" (restores regular activation policy)
5. "MIDI Monitor"
6. Quit (confirm dialog when service is live: "DeckPad stops responding to your controller when quit" — checkbox "don't ask again")

## 9. Onboarding (FR-52)

Five glass cards on `accent.gradient` wash, skippable at any step, re-runnable from Settings:

1. **Welcome** — one-line pitch + hero render of the replica.
2. **Connect** — "Plug in your DDJ-FLX4" with live detection flip to success state (uses MIDIEngine state).
3. **Permission** — explains why Accessibility is needed (one sentence + what we never do: "DeckPad never reads your keyboard"), button opens the System Settings pane, live polling flips the card on grant ([08 §4](08-background-service.md#4-permissions-acquisition-ux)).
4. **First mapping** — guided: "tap pad 1" (learn) → pick from three starter actions (Play/Pause media, open Spotlight, run a demo toast) → test it live.
5. **Feedback style** — pick default channels with live previews; Finish.

## 10. Empty & edge states

| State | Treatment |
|---|---|
| No device connected | Canvas shows dimmed replica + `EmptyStateView` ("Plug in your DDJ-FLX4 — I'll wake right up"); everything else stays usable (mappings editable offline) |
| Accessibility missing | Persistent warning `PillBadge` in toolbar + Permissions tab badge; actions that need it show inline warning in inspector |
| Profile with zero mappings | Canvas hint chip: "Click any control to map it, or press ⌘K" |
| Coexistence pause | Canvas overlay banner: "Paused while rekordbox is running" + "Resume anyway" |

## 11. Accessibility (the a11y kind)

- Full keyboard access: hotspot grid is focusable (arrow keys walk controls in layout order); all editors keyboard-completable.
- VoiceOver: hotspots expose name + state ("Deck 1, Pad 3, mapped to Run Tests, double-tap trigger").
- Respect Reduce Transparency (system handles glass fallback) and Reduce Motion ([04 §6](04-design-language.md#6-motion)).
- Canvas color-tints always pair with text/shape cues — never color-only state.
