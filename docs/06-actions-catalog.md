# DeckPad — Actions Catalog

Every mappable action type (FR-30): any discrete control can trigger any action here (FR-10), and continuous controls drive the targets in §7. This is the contract for `Action` (a Codable enum) and the ActionEngine executors. Each action declares: parameters, which control kinds can trigger it, required permission, default feedback text, and executor technique.

Categories below match the action-picker grouping in the UI ([05-ui-spec.md §4](05-ui-spec.md#4-inspector--mapping-editor-fr-61)).

## 1. Keyboard

| Action | Parameters | Controls | Permission | Technique |
|---|---|---|---|---|
| **Keystroke** | key + modifiers (recorded via key-combo recorder) | discrete | Accessibility | `CGEvent(keyboardEventSource:)` down+up pair, posted to HID tap |
| **Text snippet** | string (multi-line allowed) | discrete | Accessibility | CGEvent unicode-string typing, chunked; 1 ms inter-chunk delay |
| **Key repeat (held)** | key + modifiers, repeat rate | discrete `hold` trigger, jog `relative` | Accessibility | down on press/tick, up on release |

## 2. Media & system keys

Posted as NX system-defined events (`NSEvent.otherEvent` subtype 8) — the same events the keyboard's F-row sends ([ADR-007](99-decisions.md#adr-007-brightnessmedia-control-techniques-risk-accepted)).

| Action | Parameters | Controls | Permission |
|---|---|---|---|
| **Play/Pause · Next · Previous** | — | discrete | Accessibility |
| **Volume up / down / mute** | step size (taps per press) | discrete | Accessibility |
| **Brightness up / down** | step size | discrete | Accessibility |
| **Mission Control · Launchpad** | — | discrete | Accessibility |
| **Keyboard illumination up/down** | — | discrete | Accessibility |

## 3. Apps & files

| Action | Parameters | Controls | Permission | Technique |
|---|---|---|---|---|
| **Launch / focus app** | app (bundle ID picker) | discrete | none | `NSWorkspace.openApplication` |
| **Hide / quit app** | app, force flag (quit) | discrete | Automation (quit via AppleEvent) | AppleEvents |
| **Cycle app windows** | — | discrete | Accessibility | ⌘` keystroke to frontmost |
| **Open URL** | URL string | discrete | none | `NSWorkspace.open` |
| **Open file/folder** | path (file picker) | discrete | none | `NSWorkspace.open` |

## 4. Automation

All run async off the hub (FR-31 note); results feed feedback success/failure variants.

| Action | Parameters | Controls | Permission | Technique |
|---|---|---|---|---|
| **Run Shortcut** | shortcut name (dropdown via `shortcuts list`), optional text input | discrete | none (Shortcuts prompts its own) | `Process` → `shortcuts run <name>` |
| **Shell command** | command string, run-in dir, timeout (default 30 s) | discrete + continuous* | none | `Process` via `/bin/zsh -c`; stderr→log |
| **AppleScript** | script text | discrete | Automation per target app | `NSAppleScript` (main-thread pool) |

\* Continuous variant: the value is exported as `DECKPAD_VALUE` (0.0–1.0) and `DECKPAD_TICKS` (relative), rate-limited to 10 Hz max — enables custom fader targets (e.g. piping to `osascript` for iTunes volume or a home-automation CLI).

## 5. System toggles & session

| Action | Parameters | Controls | Permission | Technique |
|---|---|---|---|---|
| **Lock screen** | — | discrete | Accessibility | ⌃⌘Q keystroke |
| **Start screen saver** | — | discrete | none | launch ScreenSaverEngine |
| **Toggle dark mode** | — | discrete | Automation (System Events) | AppleScript on System Events |
| **Screenshot** | mode: area/window/screen, to clipboard/file | discrete | Accessibility | ⇧⌘4-family keystrokes |
| **Do Not Disturb toggle** | — | discrete | none | runs a bundled Shortcut (documented setup: user imports provided shortcut once) |
| **Sleep displays** | — | discrete | none | `pmset displaysleepnow` |

## 6. DeckPad internal

No permissions; instant.

| Action | Parameters | Controls |
|---|---|---|
| **Switch profile** | profile, or "next/previous" | discrete |
| **Pin/unpin active profile** | — | discrete (FR-22) |
| **Suspend/resume DeckPad** | — | discrete (FR-32) |
| **Open DeckPad window** | — | discrete |
| **Toggle MIDI monitor** | — | discrete |
| **No-op (label only)** | label text | discrete — reserves a control visually without doing anything |

## 7. Continuous targets (FR-11)

For faders, knobs, tempo sliders (`Trigger.continuous`). All support **response curves** (linear / eased / stepped-N) and **range clamping** (map fader travel to e.g. 20–80% volume).

| Target | Technique | Notes |
|---|---|---|
| **System volume** | CoreAudio `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on default output | Smooth, per-frame; feedback pill shows level bar (FR-41) |
| **Display brightness** | `DisplayServicesSetBrightness` (private) with fallback to stepped brightness keys | Risk + fallback per [ADR-007](99-decisions.md#adr-007-brightnessmedia-control-techniques-risk-accepted) |
| **App volume via script** | Shell/AppleScript continuous variant (§4) | For Spotify/Music-specific volume etc. |
| **Custom command** | Shell continuous variant (§4) | `DECKPAD_VALUE` env |

**Soft takeover:** absolute controls (faders/knobs) can be out of sync with their target after profile switches or external changes. Continuous mappings default to *pickup mode*: the mapping stays inert until the physical position crosses the current target value, then engages — no jumps. Toggleable per mapping ("jump immediately").

## 8. Jog & encoder modes (FR-12)

For `Trigger.relative` on `deckN.jog`, `deckN.jogSide`, `browser.encoder`.

| Mode | Parameters | Technique |
|---|---|---|
| **Scroll** | axis (v/h), speed multiplier, natural/reverse | `CGEvent scrollWheelEvent` per tick batch |
| **Arrow stepper** | key per direction (e.g. ←/→ or any combo), ticks-per-step | Keystrokes; great for timeline scrubbing / undo-redo wheels |
| **Zoom** | ticks-per-step | ⌘+/⌘− keystrokes |
| **Volume/Brightness dial** | step size | Same executors as §7, relative increments |
| **Custom command per tick** | command, ticks-per-run | Shell with `DECKPAD_TICKS` |

**Touch modifier:** each jog mapping can differ by `jogTouch` state — e.g. touched turn = per-frame scrub, rim turn = fast scroll. The browse encoder's push (`browser.encoderPress`) is an ordinary discrete control.

## 9. Trigger semantics recap (FR-13)

| Trigger | Available on | Behavior |
|---|---|---|
| `press` | buttons/pads | Fire on Note On |
| `release` | buttons/pads | Fire on Note Off |
| `doubleTap` | buttons/pads | Two presses ≤ 300 ms (configurable); single-press mapping on same control gets a 300 ms fire delay only when a doubleTap sibling exists |
| `hold` | buttons/pads | Fire after N ms held (default 500); optional distinct release action |
| `toggle` | buttons/pads | Alternate two actions per press (state persisted per profile) |
| `continuous` | faders/knobs/sliders | Stream value with curve/range/pickup (§7) |
| `relative` | jogs/encoders | Tick stream into a §8 mode |

## 10. Adding a new action type (checklist for future work)

1. Add enum case + Codable (with `schemaVersion` bump if payload shape changes).
2. Implement executor conforming to `ActionExecuting` (declares required permission + sync/async).
3. Add picker row metadata (name, SF Symbol, category, parameter form).
4. Add default feedback template ([07-feedback-system.md §4](07-feedback-system.md#4-content-templates)).
5. Unit test: executor invoked with expected parameters (mock event poster).
