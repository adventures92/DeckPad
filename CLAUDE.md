# DeckPad — repo guide

macOS app (SwiftUI, macOS 26+) turning a Pioneer DDJ-FLX4 DJ controller into a programmable Mac control surface. Product name is **DeckPad**; the Xcode project/folder keeps the scaffold name "DevPad Controller" until milestone M0 renames it.

## Where truth lives

- `docs/` is the spec. Read `docs/00-overview.md` first; `docs/02-architecture.md` defines module names and core types (`ControlID`, `ControlEvent`, `Mapping`, `Profile`) — use those names verbatim in code.
- `docs/99-decisions.md` is the decision log (D-xxx product, ADR-xxx technical). Don't re-litigate settled decisions; append a superseding entry instead.
- Requirement IDs (FR-x/NFR-x from `docs/01-requirements.md`) are referenced in task files and should appear in commit messages when relevant.

## Task workflow

- Current work = the lowest-numbered `docs/tasks/M*.md` with unchecked items. Check items off (`[x]`) in the same commit as the work; a milestone is done only when its acceptance criteria are checked.
- Never regenerate or renumber task files — edit them in place. New scope → new checklist items or a new ADR, not a rewrite.
- If implementation contradicts a spec doc, fix the doc in the same commit (docs stay true).

## Hard rules from the specs

- The only sanctioned TBD/placeholder markers are the ⏳ capture-pending cells in `docs/03-device-ddj-flx4.md` (until M1) and the explicitly marked measurement lines in task files.
- Never invent DDJ-FLX4 MIDI values — they come from the M1 capture session (ADR-004).
- App Sandbox stays OFF, Hardened Runtime stays ON (ADR-002). No SwiftData — Codable JSON persistence (ADR-005).
- MIDI goes through MIDIKit, wrapped so its types never leak past `MIDIEngine` (ADR-003).

## Build & test

```bash
xcodebuild -project "DevPad Controller.xcodeproj" -scheme "DevPad Controller" build
xcodebuild -project "DevPad Controller.xcodeproj" -scheme "DevPad Controller" test
```

(Scheme name becomes `DeckPad` after M0.) Testing hardware is Anand's own DDJ-FLX4; hardware-dependent tests must also run from the `flx4-capture.json` fixture (created in M1) so CI needs no device.
