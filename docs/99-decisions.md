# DeckPad — Decision Log

Product decisions (D-xxx) were confirmed with Anand on 2026-08-18. Architecture decision records (ADR-xxx) capture technical positions; revisit only with a superseding entry — never edit history.

Format: **Context → Decision → Consequences**. Newest entries at the bottom.

---

## D-001: App name — DeckPad

**Context.** Scaffold was created as "DevPad Controller". Candidates: DeckPad, CueKey, Jockey, DevPad.
**Decision.** **DeckPad** — DJ *deck* meets macro *pad*; short, descriptive, brandable (`deckpad.app`, bundle id `com.adven.DeckPad`).
**Consequences.** M0 renames product/display name and bundle id. Folder and `.xcodeproj` names may lag until M0 completes.

## D-002: Distribution — direct, notarized

**Context.** Core features (keystroke injection, media keys, controlling other apps) require Accessibility and CGEvent posting, which Mac App Store sandbox policy forbids.
**Decision.** Distribute outside the App Store: Developer ID signed, notarized DMG (Homebrew cask post-v1). Same channel as BetterTouchTool/Karabiner.
**Consequences.** `ENABLE_APP_SANDBOX = NO` (flipped in M0); Hardened Runtime stays on for notarization. No App Store review constraints; we own the update channel (manual in v1).

## D-003: v1 scope — full control surface

**Context.** Options: buttons only; buttons+faders/knobs; full surface including jogs.
**Decision.** Full surface: all discrete buttons/pads, all continuous faders/knobs, jog wheels as relative encoders with touch detection, browse encoder.
**Consequences.** DeviceLayer must handle 14-bit CCs and relative jog semantics from M1; the actions catalog includes continuous targets from the start.

## D-004: Profiles — per-app auto-switching

**Context.** Single global map vs. manual profiles vs. per-app auto-switch.
**Decision.** Per-app auto-switch on frontmost app (NSWorkspace), with Global fallback, unmapped-control fallthrough to Global, and a manual pin override.
**Consequences.** ProfileSwitcher is a first-class module; mapping resolution is two-level (active → Global) everywhere, including the UI's mapping-state display.

---

## ADR-001: Single-app architecture

**Context.** "Sticky background service" could be (a) one app that switches to accessory activation policy, or (b) a LaunchAgent daemon + configurator UI over XPC.
**Decision.** (a) Single SwiftUI app. Window closed → `NSApp.setActivationPolicy(.accessory)`, menu-bar extra stays; login item via `SMAppService.mainApp`.
**Consequences.** Massively simpler: one process owns MIDI, state, and UI. Costs: quitting the app stops the service (mitigated by login item + confirm-on-quit). The Dispatcher-and-below stack keeps clean boundaries so a daemon split remains possible (documented seam in [02-architecture.md §7](02-architecture.md#7-extensibility-seams-deliberate-but-dormant-in-v1)).

## ADR-002: Direct distribution, sandbox off

Technical twin of D-002. **Decision.** Hardened Runtime on, App Sandbox off, no entitlement exceptions needed for CGEvent/Accessibility since we're unsandboxed. TCC still gates everything (Accessibility, Automation) — see [01-requirements.md §3](01-requirements.md#3-permissions-inventory).

## ADR-003: MIDI via MIDIKit over raw CoreMIDI

**Context.** Raw CoreMIDI is a C API with manual packet parsing (and MIDI 1.0/2.0 UMP duality). [MIDIKit](https://github.com/orchetect/MIDIKit) (MIT) provides typed Swift events, endpoint identity persistence, and hot-plug notifications.
**Decision.** Depend on MIDIKit (SPM). MIDIEngine wraps it so MIDIKit types never leak past that module.
**Consequences.** One third-party dependency (vendored risk accepted; MIT license, actively maintained). If it stagnates, MIDIEngine's surface is small enough to reimplement on CoreMIDI directly.
**Update (M1, 2026-08-18).** MIDIKit rebranded to **SwiftMIDI** at 1.0: repo is now `orchetect/swift-midi`, umbrella product/module `SwiftMIDI`. DeckPad pins `swift-midi` from 1.1.0. Everything else in this ADR stands.

## ADR-004: Device map is captured, not guessed

**Context.** The DDJ-FLX4's exact MIDI messages (channels, CC/note numbers, LED protocol) must be right. AI-generated or recalled values are unreliable; Pioneer publishes an official MIDI message list PDF, and the Mixxx project ships a community mapping.
**Decision.** [03-device-ddj-flx4.md](03-device-ddj-flx4.md) ships with the control *inventory* and an empty map table. Exact values are captured empirically in M1 using DeckPad's own MIDI monitor against the physical unit, cross-checked with the Pioneer PDF and Mixxx mapping. Capture-pending cells are the **only** sanctioned TBDs in this doc set.
**Consequences.** M1 has an explicit "capture session" task with a per-control checklist. The descriptor is data-driven so captured values land in one table, not scattered code.

## ADR-005: Codable JSON persistence, not SwiftData

**Context.** The Xcode template scaffolded SwiftData. Mapping profiles need to be diffable, exportable, hand-editable, and shareable (FR-23).
**Decision.** Plain Codable JSON files in Application Support (one file per profile + settings.json), atomic writes, `schemaVersion` field. SwiftData/`Item.swift` template code is deleted in M0.
**Consequences.** We write ~100 lines of store code SwiftData would have given us; in exchange: trivial import/export, human-readable diffs, no model-container migration machinery.

## ADR-006: Feedback overlays are custom NSPanels, not Notification Center

**Context.** Notch toast and floating pill need precise placement (notch geometry, above-Dock centering), custom Liquid Glass styling, sub-100ms show/hide, and no user-notification permission dance. `UNUserNotificationCenter` offers none of that.
**Decision.** FeedbackCenter owns two non-activating `NSPanel`s (`.statusBar` level, ignores mouse where appropriate): NotchToastPanel (top, sized to `NSScreen.safeAreaInsets`/notch geometry with non-notch fallback) and PillPanel (bottom-center). Sounds via `NSSound`; LED via MIDI-out.
**Consequences.** We own placement/animation code and multi-display edge cases ([07-feedback-system.md](07-feedback-system.md) specifies them). No notification permission needed; overlays never enter Notification Center history.

## ADR-007: Brightness/media control techniques (risk accepted)

**Context.** Volume has a public API (CoreAudio). Display brightness on Apple Silicon does **not** — apps like MonitorControl use private `DisplayServices` calls; the public-ish fallback is simulating brightness keys via NX system-defined events (coarse 16-step).
**Decision.** Media/system keys (play/pause, brightness up/down, volume keys) via NX system-defined events. Smooth continuous volume via CoreAudio property APIs. Smooth continuous brightness via `DisplayServicesSetBrightness` (private, linked at runtime) with automatic fallback to stepped key events if unavailable.
**Consequences.** Private-API usage is fine for direct distribution (D-002) but is an acknowledged breakage risk each macOS release; isolated in one executor with a fallback path and a release-time smoke-test task (M6).
