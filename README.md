# DeckPad

**Turn your DJ controller into a Mac control surface.**

DeckPad is a native macOS app (SwiftUI, macOS 26+, Liquid Glass design) that repurposes a Pioneer DJ **DDJ-FLX4** as a programmable input device. Map any pad or button to keyboard shortcuts, Shortcuts, shell commands, or app actions; ride the faders for system volume and screen brightness; scroll and scrub with the jog wheels. Once configured, DeckPad lives in the menu bar as a background service — with feedback via a notch toast, a floating pill, sounds, or the controller's own LEDs.

> **Status:** [M1 — MIDI engine](docs/tasks/M1-midi-engine.md) complete — the DDJ-FLX4 is fully mapped from the physical hardware (input map, SHIFT layer, LED protocol), decoded live by the DeviceLayer, and regression-tested from a captured fixture. Next up: [M2 — Action engine](docs/tasks/M2-action-engine.md).

## Documentation

Start with the [overview](docs/00-overview.md), then:

| | Doc |
|---|---|
| 📋 | [Requirements (PRD)](docs/01-requirements.md) |
| 🏗 | [Architecture](docs/02-architecture.md) |
| 🎛 | [Device reference — DDJ-FLX4](docs/03-device-ddj-flx4.md) |
| 🎨 | [Design language](docs/04-design-language.md) |
| 🖥 | [UI specification](docs/05-ui-spec.md) |
| ⚡ | [Actions catalog](docs/06-actions-catalog.md) |
| 🔔 | [Feedback system](docs/07-feedback-system.md) |
| 🔁 | [Background service](docs/08-background-service.md) |
| 🗺 | [Roadmap (M0–M6)](docs/09-roadmap.md) |
| 📓 | [Decision log](docs/99-decisions.md) |
| ✅ | [Task checklists](docs/tasks/) — the living to-do lists, one per milestone |

## Requirements

- macOS 26 (Tahoe) or later
- Pioneer DJ DDJ-FLX4 (USB; class-compliant, no drivers)
- Xcode 26+ to build

## Building

Open `DeckPad.xcodeproj` and run the `DeckPad` scheme, or:

```bash
xcodebuild -project DeckPad.xcodeproj -scheme DeckPad build
```

Run UI tests from Xcode (headless CLI runs can't enable automation mode). Distribution is Developer ID + notarized DMG (outside the App Store) — pipeline lands in [M6](docs/tasks/M6-distribution.md).
