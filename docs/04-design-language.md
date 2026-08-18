# DeckPad — Design Language

Liquid Glass foundation (native macOS 26 materials) with a vibrant personality borrowed from Raycast (dark, fast, keyboard-first) and Slack (playful color, warm identity). This doc defines tokens and rules; [05-ui-spec.md](05-ui-spec.md) applies them per screen. All UI must follow this system (FR-63).

## 1. Principles

1. **Glass is chrome, canvas is content.** Liquid Glass materials (`glassEffect`) are reserved for the floating chrome layer — toolbars, inspector panels, pills, toasts, menu-bar popovers. The controller replica sits on an opaque dark canvas so glass has something to refract.
2. **Dark-first.** DeckPad is an instrument; it defaults to a stage-dark appearance. Light mode is supported (tokens are semantic) but dark is the design target.
3. **Hierarchy through material, not borders.** Elevation = more vibrancy/blur, not strokes. Hairlines only inside data tables (MIDI monitor).
4. **Fast and springy.** Every interaction answers in ≤ 1 frame with a spring, mirroring the physicality of the hardware.
5. **The hardware is the hero.** The FLX4 replica is the centerpiece; UI decoration must never compete with mapping-state information rendered on it.

## 2. Color tokens

Defined in `Assets.xcassets` as semantic colors (dark/light variants). Hex values below are the dark-appearance values — the design targets.

### Brand & accents

| Token | Value | Use |
|---|---|---|
| `accent.primary` | `#FF6363` (coral) | Primary actions, active states, selection — the Raycast-red energy |
| `accent.deep` | `#4A154B` (aubergine) | Secondary brand hue — gradients, profile chips — the Slack warmth |
| `accent.gradient` | linear `#4A154B → #FF6363`, 135° | Hero surfaces: onboarding, app icon, empty states, pinned-profile glow |
| `deck.one` | `#59A8FF` | Everything deck-1: hotspot tint, monitor rows, editor header |
| `deck.two` | `#FF8A5C` | Everything deck-2 |
| `mixer.neutral` | `#B48CF2` | Mixer/FX/browser section tint |

### Canvas & surfaces

| Token | Value | Use |
|---|---|---|
| `bg.canvas` | `#121216` | Window content background (behind everything) |
| `bg.elevated` | `#1A1A20` | Cards, monitor table, sidebar rows |
| `bg.deviceBody` | `#0C0C0F` | The controller replica's chassis fill |
| `glass.tint` | white 8% over material | Tint applied to `glassEffect` chrome |

### Semantic

| Token | Value | Use |
|---|---|---|
| `state.success` | `#3ECF8E` | Action fired, device connected, permission granted |
| `state.warning` | `#FFB224` | Permission missing, coexistence pause |
| `state.danger` | `#FF5C5C` | Errors, destructive buttons |
| `state.info` | `#59A8FF` | Neutral notices |
| `text.primary` / `.secondary` / `.tertiary` | white 92% / 64% / 40% | Standard text ramp |

### Hotspot states (on the replica)

| State | Treatment |
|---|---|
| Unmapped | `text.tertiary` outline, no fill |
| Mapped | Section-tint fill 24%, tint outline, label chip |
| Active (physically actuated) | Tint fill 60% + outer glow, spring scale 0.96→1 |
| Listening (MIDI-learn target) | `accent.primary` pulsing outline (1.2 s loop) |
| Shift layer shown | Hotspots swap to their SHIFT mapping chips; canvas corner badge "SHIFT" |

## 3. Materials & window treatment

- **Window:** hidden titlebar, full-size content view; traffic lights inset over the canvas. Content background: `bg.canvas` with a very subtle radial `accent.deep` glow (4% opacity) top-center — the "stage light".
- **Chrome:** toolbar, sidebar, and inspector use `glassEffect(.regular)` in a shared `GlassEffectContainer` so adjacent glass merges and morphs correctly.
- **Morphing:** the mapping-editor inspector and the ⌘K palette share `glassEffectID`s, so opening the palette visually *lifts out* of the inspector (Liquid Glass morph) rather than fading.
- **Overlays:** notch toast and pill use `glassEffect(.clear)` with `glass.tint`; specs in [07-feedback-system.md](07-feedback-system.md).
- **Restraint rules:** never nest glass in glass; max one glass layer between content and eye; respect Reduce Transparency (fall back to `bg.elevated` fills automatically via system materials).

## 4. Typography

| Role | Font | Size/weight |
|---|---|---|
| Screen titles | SF Pro Display | 28 semibold |
| Section headers | SF Pro Display | 20 semibold |
| Body / controls | SF Pro Text | 13 regular |
| Emphasis / buttons | SF Pro Text | 13 semibold |
| Captions / meta | SF Pro Text | 11 regular, `text.secondary` |
| Technical values (MIDI numbers, CC values, key caps) | **SF Mono** | 12 medium |

Key combos render as physical **keycaps**: SF Mono glyphs in rounded-rect chips (`KeyCapView`), e.g. `⌘` `⇧` `T` — never as plain text like "Cmd+Shift+T".

## 5. Shape & spacing

- Radii: 16 (window-level panels), 12 (cards/inspector), 8 (buttons/fields), 6 (pads on replica), capsule (pills, chips).
- Spacing scale: 4 / 8 / 12 / 16 / 24 / 32. Canvas margins 24; inspector padding 16.
- Replica proportions come from `flx4-layout.json` measurements — the drawing must read instantly as *your* controller (jogs ≈ 40% of deck width, pads 2×4 grid, mixer strip centered).

## 6. Motion

| Interaction | Animation |
|---|---|
| Hotspot press echo | spring(response 0.25, damping 0.7), scale + glow |
| Panel/inspector transitions | glassEffect morph via `glassEffectID`, 0.35 s |
| Toast/pill in-out | slide+fade spring in (0.3 s), fade out (0.25 s) |
| Continuous value bars | direct-drive (no animation) — value IS the position; 120 Hz-friendly |
| Profile auto-switch | menu-bar icon crossfade + optional toast; canvas chips crossfade 0.2 s |

Respect Reduce Motion: replace springs/morphs with 0.15 s fades.

## 7. Iconography & app icon

- SF Symbols, hierarchical rendering, filled variants for states.
- Established metaphors: play/pads/faders symbols on canvas labels; `bolt.fill` = action fired; `pin.fill` = pinned profile.
- **App icon:** rounded glass tile on `accent.gradient`; motif: a crossfader slot crossed with a keycap — "DJ hardware becomes keyboard". Generated as our own asset (M4), layered for macOS 26 icon appearance variants.

## 8. Component inventory

Reusable views (SwiftUI) that M4 implements; both UI docs reference these names.

| Component | Purpose |
|---|---|
| `GlassPanel` | Standard chrome container (glassEffect + radius 12/16) |
| `ControlHotspot` | Replica overlay per ControlID; renders §2 hotspot states |
| `KeyCapView` | Keycap-chip rendering of shortcuts |
| `ActionRow` | Icon + name + params summary of an Action (palette, inspector, lists) |
| `ValueBar` | Horizontal/vertical live value with tint (pill, inspector live preview) |
| `PillBadge` | Capsule status chips (profile, device state) |
| `SectionHeader` | 20 pt header + optional trailing actions |
| `EmptyStateView` | Icon + line + CTA on `accent.gradient` wash |
