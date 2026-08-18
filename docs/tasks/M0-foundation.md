# M0 — Foundation

**Goal:** turn the scaffold into the DeckPad shell: correct identity, correct entitlements, module skeleton, menu-bar lifecycle.
**Prerequisites:** none. **Spec refs:** [D-001](../99-decisions.md#d-001-app-name-deckpad), [ADR-001](../99-decisions.md#adr-001-single-app-architecture), [ADR-002](../99-decisions.md#adr-002-direct-distribution-sandbox-off), [ADR-005](../99-decisions.md#adr-005-codable-json-persistence-not-swiftdata), [02-architecture.md](../02-architecture.md).

## Tasks

### Identity & project settings
- [ ] Rename product: display name & `PRODUCT_NAME` → `DeckPad`; scheme → `DeckPad` (folder/`.xcodeproj` rename optional but preferred — verify git history survives via `git mv`)
- [ ] Bundle IDs → `com.adven.DeckPad` (+ `.Tests` / `.UITests`)
- [ ] `ENABLE_APP_SANDBOX = NO` on the app target; Hardened Runtime stays ON (notarization) — remove sandbox entitlements file content if present
- [ ] Add `LSUIElement = NO` (regular app; accessory switching is runtime via activation policy)
- [ ] Add `.gitignore` (xcuserdata, DerivedData, .DS_Store) — xcuserdata is currently tracked
- [ ] Set app category `public.app-category.utilities`, copyright string

### Strip template
- [ ] Delete `Item.swift`, SwiftData `ModelContainer` from `DevPad_ControllerApp.swift`, template `ContentView` list UI
- [ ] Remove SwiftData import everywhere; app compiles clean

### Skeleton
- [ ] Create module folder structure per [02-architecture.md §1](../02-architecture.md#1-module-map): `MIDIEngine/ DeviceLayer/ Dispatcher/ MappingStore/ ProfileSwitcher/ ActionEngine/ FeedbackCenter/ Permissions/ Service/ UI/`
- [ ] Define shared core types (`ControlID`, `ControlKind`, `ControlEvent`, `Trigger` stubs) in a `Core/` module folder — copied from [02 §2](../02-architecture.md#2-core-types-shared-vocabulary)
- [ ] `MenuBarExtra` scene with placeholder menu (device status stub, Open, Quit)
- [ ] ServiceController stub: window-close → `.accessory`, menu-bar "Open DeckPad" → `.regular` (FR-50 skeleton)
- [ ] Main window placeholder: dark `bg.canvas` background, "DeckPad" hero — no real UI yet

### Verification
- [ ] `xcodebuild -scheme DeckPad build test` passes; app launches, menu-bar icon present, window ↔ accessory transition works both directions
- [ ] Repo committed; `git status` clean

## Acceptance criteria
- App identifies as **DeckPad** everywhere visible (menu bar, About, Dock, bundle).
- Sandbox is off (verify with `codesign -d --entitlements - DeckPad.app`).
- No SwiftData symbols remain.
- Roadmap demo: window ↔ menu-bar accessory switching works.
