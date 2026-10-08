# Plan 001: Establish a verification baseline — unit test target, shared scheme, first test suites

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes.xcodeproj Palettes/Utilities Palettes/App`
> This plan was written against commit `9726b96` **plus a large uncommitted
> working tree on branch `icloud-sync`**. Compare the "Current state" excerpts
> against the live code before proceeding; on a mismatch, treat it as a STOP
> condition.
>
> **Environment note**: This project can only be built/tested on a machine
> with Xcode installed (iOS app). If `xcodebuild` is unavailable in your
> environment, do the file work, then STOP and report that verification must
> be run manually on the Xcode machine.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `9726b96`, 2026-07-15 (against dirty `icloud-sync` working tree)

## Why this matters

The project has zero test targets and no shared Xcode scheme, so there is no one-command way to know the app works. The CloudKit persistence layer (`AppData.persistColors/persistPalettes`) and the color math (`HEXParser`, `ImageColorExtractor`) are load-bearing, deterministic, and completely uncovered. Plans 002 (persistence hardening) and 003 (palette-color refactor) are risky without this baseline — this plan must land first.

## Current state

- `Palettes.xcodeproj/project.pbxproj` — single native target `Palettes`; `ENABLE_TESTABILITY = YES` is already set; the project uses **synchronized file groups** (PBXFileSystemSynchronizedRootGroup), so new `.swift` files inside a target's folder are picked up automatically without editing the pbxproj.
- No `.xcscheme` files exist anywhere in the repo (scheme is implicit/unshared) — CI and `xcodebuild` on other machines cannot run tests until a shared scheme is committed.
- Deployment target is iOS 17.0; iOS 26 APIs are gated behind `@available` and `Palettes/Compatibility/` shims.
- Pure-logic seams worth testing first (all take primitives, no UI):
  - `Palettes/Utilities/HEXParser.swift:11-25` — `Color.init?(hex:)`, accepts only 6-digit hex (with/without `#`, any case), returns `nil` otherwise.
  - `Palettes/Utilities/HEXParser.swift:430-457` — `ColorNamer.name(forHex:)`, nearest named color via CIEDE2000; returns `"Unknown"` for invalid hex.
  - `Palettes/Utilities/HEXParser.swift:460-471` — `ColorNamer.perceptualDistance(hex1:hex2:)`.
  - `Palettes/Utilities/ColorAdjustment.swift` — pure color adjustment + hex round-trip helpers.
  - `Palettes/App/AppData.swift:28-31` — `AppData.init(inMemory: true)` builds an in-memory SwiftData container; `persistColors` (`:162-192`) / `persistPalettes` (`:194-224`) are `private`, but persistence is exercised indirectly through the debounced `$colors`/`$palettes` sinks (300 ms debounce, `:49-65`).
- Conventions: MVVM, value-type view models (`ColorViewModel`, `PaletteViewModel` — plain structs), `AppData` is the single source of truth. Swift 5 mode.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| List simulators | `xcrun simctl list devices available` | pick any available iPhone name for `<SIM>` below |
| Build | `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** BUILD SUCCEEDED **` |
| Test | `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** TEST SUCCEEDED **` |

(Commands not yet verified on this machine — no Xcode here. Simulator name must be picked from the list, do not guess.)

## Scope

**In scope**:
- New test target `PalettesTests` (created in Xcode or via careful pbxproj edit)
- `Palettes.xcodeproj/xcshareddata/xcschemes/Palettes.xcscheme` (create + commit — mark it Shared, with the test target attached)
- New files: `PalettesTests/HEXParserTests.swift`, `PalettesTests/ColorNamerTests.swift`, `PalettesTests/ColorAdjustmentTests.swift`, `PalettesTests/AppDataPersistenceTests.swift`

**Out of scope**:
- Any change to app source under `Palettes/` (this plan is purely additive test infrastructure)
- UI tests
- CI workflow (plan 008)

## Git workflow

- Branch: `advisor/001-test-baseline` cut from `icloud-sync` (repo convention: feature branches merge to `dev`, never straight to `main`)
- Commit message style: conventional commits, e.g. `feat: add PalettesTests target with baseline suites` (matches `git log`)
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create the `PalettesTests` unit-test target and shared scheme

Add a unit-testing bundle target named `PalettesTests` (host app `Palettes`), using XCTest (not Swift Testing — Swift 5 mode, keep it simple). Then share the `Palettes` scheme (Manage Schemes → Shared) with the test target in its Test action, so `xcodebuild test` works headlessly, and ensure the scheme file lands in `Palettes.xcodeproj/xcshareddata/xcschemes/`.

If you cannot use Xcode UI: create the target by editing `project.pbxproj` (add PBXNativeTarget of product type `com.apple.product-type.bundle.unit-test`, a synchronized group for `PalettesTests/`, target dependency on `Palettes`, `TEST_HOST` settings) — this is fiddly; if the pbxproj edit fails to build twice, STOP.

**Verify**: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` → `** TEST SUCCEEDED **` (zero tests is fine at this step).

### Step 2: HEXParser + ColorNamer golden tests

Create `PalettesTests/HEXParserTests.swift` and `PalettesTests/ColorNamerTests.swift` with `@testable import Palettes`. Cases:

- `Color(hex:)`: accepts `"FF5D00"`, `"#FF5D00"`, `"#ff5d00"`, `"  #FF5D00  "` (whitespace); rejects (returns nil) `"#FFF"`, `"#FF5D00AA"`, `"GGGGGG"`, `""`. NOTE: 3/8-digit rejection is **current** behavior; plan 005 changes it — these tests document today's contract and will be updated there.
- `ColorNamer.name(forHex:)`: exact table entries return their own name (pick 3 from the table in `HEXParser.swift`, e.g. verify `name(forHex:)` of a known entry's hex equals its name — read the `namedColors` table to select entries); invalid hex returns `"Unknown"`; result is deterministic (call twice, equal).
- `perceptualDistance`: identical hexes → 0; invalid hex → `.greatestFiniteMagnitude`; symmetric (d(a,b) == d(b,a)).

**Verify**: test command → `** TEST SUCCEEDED **`, new tests listed as passed.

### Step 3: ColorAdjustment round-trip tests

Read `Palettes/Utilities/ColorAdjustment.swift` (62 lines) and write tests covering: hex → adjust(0 deltas) → hex is identity; adjustments clamp at bounds (no crash, valid hex out).

**Verify**: test command → all pass.

### Step 4: AppData in-memory persistence characterization tests

`PalettesTests/AppDataPersistenceTests.swift`, `@MainActor` test class. Use `AppData(inMemory: true)`. Because persistence is debounced 300 ms behind `$colors`/`$palettes` sinks, after mutating `appData.colors`/`palettes`, wait ~1 s (`try await Task.sleep(for: .seconds(1))`) before asserting. Characterize current behavior:

1. Append a `ColorViewModel` → after wait, a second `AppData` constructed on the same container would see it. Since the container is private, instead assert indirectly: mutate, wait, then simulate reload by calling the public path available — if no public reload/inspection API exists, assert via a fresh fetch is impossible; in that case restrict to: mutate → wait → mutate again → no crash, and mark in the test file a TODO that plan 002 adds a testable seam. **Do not add public API to AppData in this plan.**
2. First-launch seeding: `UserDefaults.standard.removeObject(forKey: "didSeedSampleData")` before constructing → arrays contain the 11 sample colors / 5 sample palettes (see `AppData.swift:248-317`).

**Verify**: test command → all pass.

## Test plan

This plan *is* the test plan; see steps 2–4. Expected: ≥15 new tests, all passing.

## Done criteria

- [ ] `Palettes.xcodeproj/xcshareddata/xcschemes/Palettes.xcscheme` exists and is committed
- [ ] `xcodebuild test ...` → `** TEST SUCCEEDED **` with ≥15 tests
- [ ] `git status` shows no modifications under `Palettes/` app source
- [ ] `plans/README.md` status row updated

## STOP conditions

- `xcodebuild` unavailable (no Xcode on this machine) → do file work, report verification pending.
- pbxproj test-target edit fails to build twice.
- `AppData(inMemory: true)` container returns nil / seeding behavior doesn't match the excerpt (working tree may have moved).

## Maintenance notes

- Plans 002/003/005/006 all extend these suites; keep test file names stable.
- Reviewer: check the scheme file is genuinely shared (in `xcshareddata`, not `xcuserdata`).
- Deferred: UI tests, CI (plan 008).
