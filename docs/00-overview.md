# DeckPad — Overview

> Turn your DJ controller into a Mac control surface.

## Vision

DeckPad is a native macOS app that repurposes a Pioneer DJ **DDJ-FLX4** as a programmable input device for everyday Mac work. Every pad, button, fader, knob, and jog wheel on the controller can be mapped to a Mac action: fire a keyboard shortcut, run a Shortcut or shell command, launch an app, adjust volume or screen brightness, scroll a document with the jog wheel.

The controller most DJ hobbyists own sits idle 95% of the time. DeckPad turns that idle hardware into the most tactile macro pad money already bought.

## Product pitch

- **For developers who DJ.** You already have muscle memory on this hardware. Map `deck1.pad1` to "run tests", the crossfader to system volume, the jog wheel to timeline scrubbing in your editor.
- **Native and beautiful.** A SwiftUI app targeting macOS 26+ with the Liquid Glass design language — vibrant, Raycast/Slack-inspired, with a faithful visual replica of the controller as the mapping canvas.
- **Set and forget.** Once configured, DeckPad collapses into a menu-bar background service. It survives reboots (login item), USB unplug/replug, and app crashes of the things it controls.
- **Feedback your way.** A toast in the notch, a floating pill above the Dock, an audible cue, a pad LED flash — every feedback channel is individually configurable, globally and per action.

## Name

**DeckPad** — a DJ *deck* meets a macro *pad*. Chosen over CueKey, Jockey, and the scaffold name DevPad (decision [D-001](99-decisions.md#d-001-app-name-deckpad)).

- Product/display name: `DeckPad`
- Bundle identifier: `com.adven.DeckPad` (rename from `com.adven.DevPad-Controller` happens in [M0](tasks/M0-foundation.md))
- The Xcode folder/scheme keeps the scaffold name until M0 renames it.

## Personas

| Persona | Description | What they need |
|---|---|---|
| **The dev-DJ** (primary) | Software engineer, owns a DDJ-FLX4, DJs on weekends. Lives in an editor + terminal + Slack. | Per-app profiles (Xcode vs. browser), shortcut/media mappings, zero-maintenance background service. |
| **The tinkerer** | Automation enthusiast (BetterTouchTool/Karabiner/Raycast user). | Deep action catalog (shell, AppleScript, Shortcuts), import/export of mapping profiles, MIDI monitor for debugging. |
| **The streamer/creator** | Uses macro decks for scene switching, audio control. | Reliable low-latency triggers, LED state feedback on the hardware, continuous controls for audio levels. |

## Competitive landscape

| Product | What it does | Why DeckPad is different |
|---|---|---|
| Elgato Stream Deck | Dedicated macro hardware + app | DeckPad needs **no new hardware** — and offers faders/jogs, which Stream Deck lacks |
| BetterTouchTool | Generic input remapping incl. MIDI | Generic MIDI support, no device-aware UI; DeckPad renders *your* controller and understands its semantics (pads vs. jog touch vs. 14-bit faders) |
| Karabiner-Elements | Keyboard remapping | Keyboards only, no MIDI |
| MIDI Stroke / MidiKey2Key | Bare MIDI→keystroke bridges | Utilitarian, unmaintained UIs; no profiles, feedback, or continuous-control support |
| djay / Serato / rekordbox | Actual DJ software | Not competitors — DeckPad targets the hours the controller is **not** DJing. DeckPad must coexist politely (release the device when DJ software runs). |

## Scope (v1)

**In:** DDJ-FLX4 full surface (all MIDI-visible controls, ~100 inputs), per-app auto-switching profiles, the full action catalog ([06-actions-catalog.md](06-actions-catalog.md)), notch/pill/sound/LED feedback, background service + login item, direct notarized distribution.

**Out (non-goals for v1):** other controllers (architecture keeps a device-descriptor seam for them — see [02-architecture.md](02-architecture.md)), Mac App Store build, iOS companion, MIDI *output* sequencing beyond LED feedback, audio routing/DJ features, Windows/Linux.

## Success criteria

1. From a cold boot with the FLX4 attached, a configured Mac executes a mapped action in under 50 ms from button press, with no DeckPad window ever opened.
2. A new user goes from first launch to a working "pad → shortcut" mapping in under 3 minutes, guided by onboarding.
3. Unplugging and replugging the controller requires zero user interaction to resume.
4. Opening rekordbox/djay does not fight DeckPad; a documented coexistence behavior exists.
5. Every control on the physical FLX4 that emits MIDI is visible and mappable in the UI replica.

## Document map

| Doc | Purpose |
|---|---|
| [01-requirements.md](01-requirements.md) | PRD: functional & non-functional requirements, permissions |
| [02-architecture.md](02-architecture.md) | Modules, data flow, threading, error handling |
| [03-device-ddj-flx4.md](03-device-ddj-flx4.md) | DDJ-FLX4 control inventory + MIDI map (capture plan) |
| [04-design-language.md](04-design-language.md) | Liquid Glass / Raycast / Slack visual system |
| [05-ui-spec.md](05-ui-spec.md) | Screens and interaction spec |
| [06-actions-catalog.md](06-actions-catalog.md) | Every mappable action type |
| [07-feedback-system.md](07-feedback-system.md) | Toast, pill, sound, LED feedback |
| [08-background-service.md](08-background-service.md) | Service lifecycle, permissions UX, resilience |
| [09-roadmap.md](09-roadmap.md) | Milestones M0–M6 |
| [99-decisions.md](99-decisions.md) | Decision log (ADRs) |
| [tasks/](tasks/) | Per-milestone task checklists — the living to-do lists |
