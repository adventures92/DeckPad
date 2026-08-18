# DeckPad — Requirements (PRD)

Requirement IDs are stable and referenced from [02-architecture.md](02-architecture.md), the task files in [tasks/](tasks/), and commit messages. Do not renumber; deprecate instead.

## 1. Functional requirements

### Device & MIDI

- **FR-1** — Detect the DDJ-FLX4 over USB via CoreMIDI, identifying it by MIDI endpoint name/manufacturer. No kernel drivers, no user setup. *(MIDIEngine; M1)*
- **FR-2** — Receive and decode all MIDI input from the device: Note On/Off, Control Change, and 14-bit MSB/LSB CC pairs for high-resolution faders/knobs. *(MIDIEngine; M1)*
- **FR-3** — Translate raw MIDI into semantic control events (`deck1.play pressed`, `mixer.crossfader = 0.73`, `deck2.jog turned +3 while touched`) via a device descriptor, so the rest of the app never sees raw MIDI. *(DeviceLayer; M1)*
- **FR-4** — Handle hot-plug: device unplugged → app idles quietly and shows state in menu bar; replugged → resumes automatically with no user action. *(MIDIEngine, ServiceController; M1)*
- **FR-5** — Send MIDI output to the controller to drive pad LEDs (mapping state, trigger flash). *(MIDIEngine, FeedbackCenter; M5)*
- **FR-6** — Provide a built-in MIDI monitor (debug view) streaming decoded events in real time; used both by users for troubleshooting and by us in M1 to capture the device map. *(MIDIMonitor UI; M1)*
- **FR-7** — Coexistence: user-selectable behavior when DJ software is detected running (rekordbox, djay, Serato): pause DeckPad automatically (default) or keep running. *(ProfileSwitcher, ServiceController; M3)*

### Mapping

- **FR-10** — Map any discrete control (pads, transport, mode buttons, encoder push) to any action in the [actions catalog](06-actions-catalog.md). *(MappingStore, ActionEngine; M2–M3)*
- **FR-11** — Map any continuous control (faders, knobs, tempo sliders) to a continuous target: system volume, display brightness, scroll speed, or a parameterized custom command. *(ActionEngine; M2)*
- **FR-12** — Map jog wheels as relative encoders: scroll (vertical/horizontal), arrow-key stepper, zoom, or custom repeat action; jog **touch** state usable as a modifier (e.g., touch+turn vs. turn). *(DeviceLayer, ActionEngine; M2)*
- **FR-13** — Trigger types per discrete control: press, release, double-tap, hold (configurable duration), and toggle (alternating two actions). *(MappingStore, ActionEngine; M3)*
- **FR-14** — The controller's SHIFT button acts as a layer modifier: every control can have a base mapping and a shift mapping. *(DeviceLayer, MappingStore; M3)*
- **FR-15** — MIDI-learn assignment: user clicks a control in the UI *or* touches the physical control, and the mapping editor targets it. *(MIDIEngine, MappingEditor; M4)*

### Profiles

- **FR-20** — Named profiles, each containing a full mapping set. A **Global** profile always exists as fallback. *(MappingStore; M3)*
- **FR-21** — Per-app auto-switch: profiles can be bound to app bundle IDs; DeckPad activates the matching profile when the frontmost app changes, falling back to Global for unbound apps. Controls unmapped in the active profile fall through to Global. *(ProfileSwitcher; M3)*
- **FR-22** — Manual override: user can pin a profile from the menu bar (or a mapped `switchProfile` action), suspending auto-switch until unpinned. *(ProfileSwitcher; M3)*
- **FR-23** — Import/export profiles as human-readable JSON files (shareable). *(MappingStore; M3)*

### Actions

- **FR-30** — Implement the full action catalog defined in [06-actions-catalog.md](06-actions-catalog.md): keystroke, text snippet, media/system key, app control, open URL/file, run Shortcut, shell command, AppleScript, system toggles, DeckPad-internal actions, and continuous targets. *(ActionEngine; M2)*
- **FR-31** — Actions execute in < 50 ms from physical input to injected event (excluding inherently slow actions like shell scripts, which run async). *(ActionEngine; M2)*
- **FR-32** — A global kill switch ("Suspend DeckPad") from the menu bar and as a mappable action. *(ServiceController; M3)*

### Feedback

- **FR-40** — Feedback channels on action execution: notch toast, floating pill, sound cue, pad LED flash — each independently toggleable globally, with per-mapping override (inherit / force on / force off). See [07-feedback-system.md](07-feedback-system.md). *(FeedbackCenter; M5)*
- **FR-41** — Continuous-control feedback shows live value (e.g., pill with a volume bar while the fader moves), throttled/coalesced so it never lags the hand. *(FeedbackCenter; M5)*

### Service & lifecycle

- **FR-50** — Closing the main window drops the app to a menu-bar accessory (no Dock icon); reopening from the menu bar restores the full UI. *(ServiceController; M3)*
- **FR-51** — Optional launch-at-login via `SMAppService`, toggleable in Settings. *(ServiceController; M6)*
- **FR-52** — Onboarding flow: welcome → connect controller → grant Accessibility → create first mapping → done. Runs on first launch; re-runnable from Settings. *(OnboardingFlow; M6)*
- **FR-53** — Settings: feedback defaults, login item, coexistence behavior, profile management, permissions status panel. *(SettingsView; M4–M6)*

### UI

- **FR-60** — The main window renders a faithful, proportioned visual replica of the DDJ-FLX4 top plate; every MIDI-visible control is a clickable hotspot showing its mapping state. *(ControllerCanvas; M4)*
- **FR-61** — Mapping editor: select control → choose trigger → choose action + parameters → optional feedback override; changes apply live without save/apply buttons. *(MappingEditor; M4)*
- **FR-62** — Physical interaction echo: touching a control on the hardware highlights it in the open UI in real time. *(ControllerCanvas; M4)*
- **FR-63** — The whole UI follows the Liquid Glass design language defined in [04-design-language.md](04-design-language.md). *(all UI; M4)*

## 2. Non-functional requirements

- **NFR-1 Latency** — ≤ 50 ms input-to-injection for discrete actions; continuous controls feel realtime (no visible stair-stepping at 60 Hz UI). 
- **NFR-2 Footprint** — Idle background CPU ~0%; memory < 100 MB as accessory. No polling loops; everything event-driven.
- **NFR-3 Reliability** — Service survives device unplug, display sleep, fast user switching. No crash loops: MIDI parse errors are logged and dropped, never fatal.
- **NFR-4 Privacy** — No network calls in v1 (no analytics, no update phone-home). All data stays in `~/Library/Application Support/DeckPad/`.
- **NFR-5 Platform** — macOS 26.0+ (Tahoe), Apple Silicon + Intel via universal binary. SwiftUI-first; AppKit only where SwiftUI lacks APIs (panels, event injection).
- **NFR-6 Distribution** — Developer ID signed, notarized, Hardened Runtime on, **App Sandbox off** (required for event injection — decision [ADR-002](99-decisions.md#adr-002-direct-distribution-sandbox-off)). Delivered as DMG; Homebrew cask later.
- **NFR-7 Storage format** — Profiles are versioned, human-readable JSON (schema version field from day one).

## 3. Permissions inventory

Everything the app must request, when, and why. The onboarding/permissions UX is specified in [08-background-service.md](08-background-service.md).

| Permission | API | Needed for | When requested |
|---|---|---|---|
| **Accessibility** (TCC) | `AXIsProcessTrustedWithOptions` / CGEvent posting | Injecting keystrokes, media keys, scroll events (most of the action catalog) | Onboarding, before first mapping test |
| **Automation** (per-target app, TCC) | AppleEvents / `NSAppleScript` | AppleScript actions targeting other apps | Lazily, on first run of an AppleScript action per target app |
| **Login item approval** | `SMAppService.mainApp` | Launch at login | When user toggles it in Settings (system shows its own consent UI) |
| *(none needed)* | CoreMIDI | MIDI in/out on macOS carries no TCC prompt | — |
| *(explicitly avoided)* | Input Monitoring | Not needed: DeckPad posts events but never observes the keyboard | — |

## 4. Explicit non-goals (v1)

1. Support for controllers other than the DDJ-FLX4 (the `DeviceDescriptor` seam exists, but only one descriptor ships).
2. Mac App Store distribution (incompatible with event injection).
3. Recording/macro sequences (multi-step macros beyond a single action per trigger).
4. Audio features of any kind — DeckPad never opens the FLX4's audio interface.
5. Networking: no telemetry, no auto-update in v1 (manual DMG updates; Sparkle considered post-v1).
