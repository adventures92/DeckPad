# M5 — Feedback

**Goal:** the full feedback system — notch toast, floating pill, sounds, controller LEDs — with the global + per-mapping config matrix.
**Prerequisites:** M3 (runs in parallel with M4; LED tasks additionally need M1's LED capture). **Spec refs:** FR-5, FR-40, FR-41, [07-feedback-system.md](../07-feedback-system.md), [ADR-006](../99-decisions.md#adr-006-feedback-overlays-are-custom-nspanels-not-notification-center).

## Tasks

### FeedbackCenter core
- [ ] `FeedbackEvent` pipeline from Dispatcher (fire-and-forget, zero action latency impact — [07 §6](../07-feedback-system.md#6-rules--rate-limits-sanity-guarantees))
- [ ] Config resolution: global defaults ⊕ per-mapping override ([07 §3](../07-feedback-system.md#3-configuration-matrix)); defaults table applied on first run
- [ ] Content templates per action category incl. async success/failure update of visible toast ([07 §4](../07-feedback-system.md#4-content-templates))

### Overlay panels
- [ ] `NotchToastPanel`: non-activating, `.statusBar` level, all-Spaces; notch geometry via safe-area insets + non-notch fallback; crossfade-in-place queueing ([07 §1.1](../07-feedback-system.md#11-notch-toast))
- [ ] `PillPanel`: bottom-center above Dock; discrete + continuous (`ValueBar`) variants; direct-drive values, 800 ms linger, 3-stack policy ([07 §1.2](../07-feedback-system.md#12-floating-pill))
- [ ] Multi-display policy: follow key window's screen, fallback mouse screen; single instance moves, never duplicates ([07 §5](../07-feedback-system.md#5-multi-display-policy))
- [ ] Coalescing/rate limits: 60 Hz pill, toast depth 1 ([07 §6](../07-feedback-system.md#6-rules--rate-limits-sanity-guarantees))

### Sound
- [ ] `NSSound` channel: system-sound picker + bundled click, volume, 150 ms rate limit, pickup-engage tick ([07 §1.3](../07-feedback-system.md#13-sound-cue))

### Controller LEDs (FR-5)
- [ ] LED frame encoder in DeviceLayer from M1's captured LED map
- [ ] Ambient state: mapped controls dim-lit per category color; refresh on profile switch; off when suspended/paused ([07 §1.4](../07-feedback-system.md#14-controller-led-fr-5))
- [ ] Trigger flash 150 ms → ambient restore; ≤ 30 fps batched frames within captured rate limits

### Settings & polish
- [ ] Settings → Feedback tab: global matrix + live preview buttons (completes the M4 stub)
- [ ] Profile-switch toast type ("⇄ Xcode") with its own toggle
- [ ] Failure-visibility guarantee: erroring mapping always surfaces at least the menu-bar badge ([07 §6](../07-feedback-system.md#6-rules--rate-limits-sanity-guarantees) rule 3)
- [ ] Investigate macOS 26 screen-capture detection for "hide overlays while sharing"; ship toggle only if reliable, else record findings + ADR

### Tests
- [ ] Config-resolution unit tests (inherit/on/off × global states)
- [ ] Template rendering tests; panel-placement logic tests with mocked screen configs (notch/no-notch/multi-display)

## Acceptance criteria
- Roadmap demo: pad trigger → notch toast + LED flash; fader ride → live pill bar; every channel toggleable globally and per-mapping, verified live.
- Overlays never steal focus, never appear in Notification Center, and survive display hot-plug.
- Feedback adds no measurable latency to action execution (signpost check vs. M2 baseline).
