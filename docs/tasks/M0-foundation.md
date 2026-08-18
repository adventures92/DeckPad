# M0 — Foundation

**Goal:** turn the scaffold into the DeckPad shell: correct identity, correct entitlements, module skeleton, menu-bar lifecycle.
**Prerequisites:** none. **Spec refs:** [D-001](../99-decisions.md#d-001-app-name-deckpad), [ADR-001](../99-decisions.md#adr-001-single-app-architecture), [ADR-002](../99-decisions.md#adr-002-direct-distribution-sandbox-off), [ADR-005](../99-decisions.md#adr-005-codable-json-persistence-not-swiftdata), [02-architecture.md](../02-architecture.md).

## Tasks

### Identity & project settings
- [x] Rename product: display name & `PRODUCT_NAME` → `DeckPad`; scheme → `DeckPad`; folder + `.xcodeproj` renamed via `git mv` (history preserved); shared scheme committed at `DeckPad.xcodeproj/xcshareddata/xcschemes/DeckPad.xcscheme`
- [x] Bundle IDs → `com.adven.DeckPad` (+ `DeckPadTests` / `DeckPadUITests`)
- [x] `ENABLE_APP_SANDBOX = NO` on all targets; `ENABLE_HARDENED_RUNTIME = YES` added (notarization); sandbox-only `ENABLE_USER_SELECTED_FILES` removed — verified via `codesign -d --entitlements`: no `app-sandbox` key
- [x] `LSUIElement` left at default (NO) — regular app; accessory switching is runtime via activation policy
- [x] Add `.gitignore` (xcuserdata, DerivedData, .DS_Store); previously tracked xcuserdata untracked
- [x] Set app category `public.app-category.utilities`, copyright string

### Strip template
- [x] Delete `Item.swift`, SwiftData `ModelContainer`, template `ContentView` list UI
- [x] Remove SwiftData import everywhere; verified zero `SwiftData`/`ModelContainer` references remain

### Skeleton
- [x] Create module folder structure per [02-architecture.md §1](../02-architecture.md#1-module-map) (`Core/ Service/ UI/` populated; `MIDIEngine/ DeviceLayer/ Dispatcher/ MappingStore/ ProfileSwitcher/ ActionEngine/ FeedbackCenter/ Permissions/` exist on disk and enter git as their milestones populate them)
- [x] Shared core types (`ControlID`, `ControlKind`, `ControlEvent`, `Trigger`) in `DeckPad/Core/CoreTypes.swift`, copied from [02 §2](../02-architecture.md#2-core-types-shared-vocabulary), with Codable round-trip unit tests
- [x] `MenuBarExtra` scene with placeholder menu (device status stub, Open, Quit)
- [x] ServiceController stub: window-close → `.accessory`, menu-bar "Open DeckPad" → `.regular` (FR-50 skeleton) — `DeckPad/Service/ServiceController.swift`
- [x] Main window placeholder: dark `bg.canvas` background, gradient "DeckPad" hero

### Verification
- [x] `xcodebuild -project DeckPad.xcodeproj -scheme DeckPad build` succeeds; unit tests pass (`CoreTypesTests` 2/2). Note: **UI tests must be run from Xcode** — headless CLI runs fail with "Timed out while enabling automation mode" (TCC automation consent); skip them in scripts with `-skip-testing:DeckPadUITests`
- [x] App launches, correct bundle identity (`com.adven.DeckPad` / `DeckPad`)
- [ ] Eyeball check (Anand): menu-bar icon present; window ↔ accessory transition works both directions (close window → Dock icon disappears, menu bar stays; "Open DeckPad" → window + Dock icon return)
- [x] Repo committed; `git status` clean

## Acceptance criteria
- [x] App identifies as **DeckPad** everywhere visible (bundle, window title, menu bar).
- [x] Sandbox is off (verified with `codesign -d --entitlements - DeckPad.app`).
- [x] No SwiftData symbols remain.
- [ ] Roadmap demo confirmed by eyeball: window ↔ menu-bar accessory switching works.
