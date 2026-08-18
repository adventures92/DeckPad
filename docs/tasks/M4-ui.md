# M4 — UI (Liquid Glass)

**Goal:** the real DeckPad interface — design system, controller canvas replica, mapping editor, ⌘K palette, sidebar, settings.
**Prerequisites:** M3 (runs in parallel with M5). **Spec refs:** FR-15, FR-53, FR-60…FR-63, [04-design-language.md](../04-design-language.md), [05-ui-spec.md](../05-ui-spec.md).

## Tasks

### Design system
- [ ] Color tokens as semantic asset-catalog colors (dark + light) per [04 §2](../04-design-language.md#2-color-tokens)
- [ ] Components: `GlassPanel`, `ControlHotspot`, `KeyCapView`, `ActionRow`, `ValueBar`, `PillBadge`, `SectionHeader`, `EmptyStateView` ([04 §8](../04-design-language.md#8-component-inventory))
- [ ] Window treatment: hidden titlebar, stage-light canvas, `GlassEffectContainer` chrome ([04 §3](../04-design-language.md#3-materials--window-treatment))
- [ ] Motion helpers + Reduce Motion/Transparency audits ([04 §6](../04-design-language.md#6-motion))

### Controller canvas (FR-60, FR-62)
- [ ] Author `flx4-layout.json` — normalized geometry per ControlID measured from the physical unit / photos (our own generated design asset)
- [ ] Vector replica rendering: chassis, decks, mixer, decorative analog elements dimmed ([05 §3](../05-ui-spec.md#3-controller-canvas))
- [ ] Hotspots with all five states + label chips + hover tooltips
- [ ] Live echo: actuation highlights; drawn fader caps/knobs/jog ring track physical values
- [ ] SHIFT layer preview (segmented + physical-SHIFT temporary)
- [ ] Zoom: fit / ⌘± / pinch

### Editing flows
- [ ] Inspector mapping editor, all seven sections per [05 §4](../05-ui-spec.md#4-inspector--mapping-editor-fr-61): header, layer tabs, trigger picker, action picker, parameter forms (key-combo recorder!, script editor, Shortcut dropdown, curve editor), feedback override matrix, test/remove footer; live-apply + ⌘Z (FR-61)
- [ ] ⌘K palette with glass morph, action-first and control-first flows, **MIDI-learn** (FR-15) ([05 §5](../05-ui-spec.md#5-k-quick-assign-palette))
- [ ] Profiles sidebar: rows, bind-apps picker, pin, import/export incl. drag-in ([05 §2](../05-ui-spec.md#2-profiles-sidebar))

### Shell screens
- [ ] Settings tabs: General / Feedback / Permissions / Profiles / About (FR-53, [05 §6](../05-ui-spec.md#6-settings-fr-53)) — Feedback tab fully wires in M5
- [ ] Menu-bar extra final: icon states + full menu ([05 §8](../05-ui-spec.md#8-menu-bar-extra))
- [ ] MIDI monitor polish: section tints, filters, JSON/CSV copy ([05 §7](../05-ui-spec.md#7-midi-monitor-debug))
- [ ] Empty/edge states per [05 §10](../05-ui-spec.md#10-empty--edge-states)
- [ ] App icon: layered macOS 26 icon per [04 §7](../04-design-language.md#7-iconography--app-icon) direction

### Accessibility & QA
- [ ] Keyboard-access walk of hotspot grid + editors; VoiceOver labels per [05 §11](../05-ui-spec.md#11-accessibility-the-a11y-kind)
- [ ] Light-mode pass (tokens hold up), Reduce Transparency pass
- [ ] UI tests: map-a-pad flow, profile switch reflected in canvas chips

## Acceptance criteria
- Roadmap demo: map a pad end-to-end using only the UI — once by clicking the replica, once via ⌘K + MIDI-learn — with live echo visible.
- Every MIDI-visible control from [03 §2](../03-device-ddj-flx4.md#2-control-inventory) exists as a hotspot (FR-60 audit against the captured inventory).
- No hardcoded colors outside the token set; a11y audits pass.
