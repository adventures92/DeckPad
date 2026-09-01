# DeckPad — Machine Transition Handoff

Written 2026-08-19, transitioning development from the work-managed Mac (non-admin — Accessibility TCC grants require IT) to a personal Mac with admin rights. Everything durable lives in this repo; this file carries the in-flight state and the new-machine checklist. Delete it once the transition is complete.

## Project state at handoff

| Milestone | Status |
|---|---|
| M0 Foundation | ✅ complete |
| M1 MIDI engine + device map | ✅ complete — full FLX4 map captured from hardware (input, SHIFT layer, LED protocol); fixture-replay tests need no device |
| M2 Action engine | ✅ code + 13 tests done. **Open:** formal latency numbers (NFR-1) — blocked only by the Accessibility grant; samples auto-append to `/tmp/deckpad-latency.csv` when mappings fire |
| M3 Mapping system | ✅ code + 15 tests done. **Open:** demo walkthrough unconfirmed (auto-switch/pin/suspend/quit-confirm — see [docs/tasks/M3-mapping-system.md](docs/tasks/M3-mapping-system.md)) and the idle-footprint measurement (NFR-2) |
| M4–M6 | not started — [docs/09-roadmap.md](docs/09-roadmap.md) |

Test suite: **43 green** (`xcodebuild -project DeckPad.xcodeproj -scheme DeckPad test -skip-testing:DeckPadUITests`).

## New-machine setup checklist

1. **Prereqs:** macOS 26+, Xcode 26+, admin account, the DDJ-FLX4 + USB cable.
2. **Code:** clone from the transfer bundle — `git clone DeckPad-transfer.bundle DeckPad && cd DeckPad && git remote remove origin` — or from whatever remote you push it to. Full history included.
3. **Signing:** Xcode → Settings → Accounts → sign in with the Apple ID for team **"Anand Verma" (V49KZKM5ZY)** — the project pins `DEVELOPMENT_TEAM = V49KZKM5ZY`. Xcode mints a fresh Apple Development certificate automatically (no need to export the old .p12; the TCC grant is per-machine anyway). Do **not** revert to ad-hoc signing — stable signatures are what make the Accessibility grant survive rebuilds.
4. **Build & test** with the commands in [CLAUDE.md](CLAUDE.md). First build resolves SwiftMIDI 1.1.0 from GitHub.
5. **Run the app** → menu-bar dial icon appears → grant Accessibility when prompted (self-service now — this was the whole reason for the move). One-time.
6. **Profiles:** the Global profile self-seeds with starter mappings on first launch. Optionally copy `~/Library/Application Support/DeckPad/` from the old Mac to keep the seeded "TextEdit" auto-switch demo profile (or recreate it: any profile JSON in `profiles/` with `appBundleIDs: ["com.apple.TextEdit"]`).
7. **Claude Code:** open the cloned repo — [CLAUDE.md](CLAUDE.md) + `docs/` + the task files carry all project context for a fresh session. Optionally copy `~/.claude/projects/-Users-anand-v-Workspace-iOS-DevPad-Controller/memory/` from the old Mac into the equivalent path (slug will differ if the folder path differs) to keep session memory; not required — the important notes are in CLAUDE.md.

## First session on the new machine — suggested order

1. Build + run tests (should be 43 green with no device; monitor + decoder work live once the FLX4 is plugged in).
2. Grant Accessibility, then run the M3 demo walkthrough (task file acceptance list): auto-switch via ⌘Tab watching the menu-bar status line, pin override, suspend gate, quit confirmation, unplug/replug.
3. Press deck-1 pad 1 ~15× with TextEdit focused → read `/tmp/deckpad-latency.csv` → record p50/p95 in [docs/tasks/M2-action-engine.md](docs/tasks/M2-action-engine.md) (target: p95 ≤ 50 ms).
4. Close the main window, idle a minute, record CPU/RSS (`ps -o %cpu,rss -p $(pgrep -x DeckPad)`) in the M3 task file (target: ~0% / <100 MB).
5. That closes M2+M3 → start [M4 — UI](docs/tasks/M4-ui.md) (Liquid Glass design system + controller canvas).

## Known machine-specific facts that do NOT carry over

- TCC/Accessibility grants (per-machine, re-grant once).
- `/tmp/deckpad-latency.csv` (regenerates on first mapped action).
- The old Mac's stale TCC entries for ad-hoc-signed builds (irrelevant there too).
