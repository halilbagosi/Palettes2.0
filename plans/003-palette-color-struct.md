# Plan 003: Replace PaletteViewModel's parallel arrays with a single PaletteColor struct

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. On
> any STOP condition, stop and report. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/ViewModels Palettes/Views Palettes/App Palettes/Managers`
> Written against commit `9726b96` plus the uncommitted `icloud-sync` working
> tree. The Views are under active development — verify every excerpt below
> against the live code first; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M–L (touches many call sites)
- **Risk**: MED
- **Depends on**: plans/001-test-baseline.md (and land after plans/002 to avoid AppData merge conflicts)
- **Category**: bug / tech-debt
- **Planned at**: commit `9726b96`, 2026-07-15 (dirty `icloud-sync` working tree)

## Why this matters

A palette's data lives in three positionally-coupled arrays (`colors: [Color]`, `hexCodes: [String]`, `colorNames: [String]`) that nothing keeps the same length. Several mutation sites already handle them asymmetrically, so a desync is reachable — and once desynced, unguarded subscripts crash with `Array index out of range`. Collapsing them into one array of a `PaletteColor` struct makes mismatched lengths unrepresentable and removes an entire crash class.

## Current state

`Palettes/ViewModels/PaletteViewModel.swift:11-17`:

```swift
struct PaletteViewModel: Identifiable, Sendable, Hashable {
    var id = UUID()
    var name: String
    var colors: [Color]
    var hexCodes: [String] = []      // ← default [], can differ in length from colors
    var colorNames: [String] = []
    var isFavorite: Bool = false
```

Asymmetric mutation — `Palettes/Views/Components/PaletteEditSheet.swift:152-159`:

```swift
private func removeColors(at offsets: IndexSet) {
    guard let idx = paletteIndex else { return }
    appData.palettes[idx].colors.remove(atOffsets: offsets)
    let hexValid = offsets.filter { $0 < appData.palettes[idx].hexCodes.count }
    appData.palettes[idx].hexCodes.remove(atOffsets: IndexSet(hexValid))   // ← colors shrinks even when hexCodes doesn't
    ...
}
```

Unguarded triple subscripts — `PaletteEditSheet.swift:121-123` (guard at `:108` checks only `livePalette.colors.count`):

```swift
colorName: $appData.palettes[paletteIdx].colorNames[wrapper.id],
hexCode: $appData.palettes[paletteIdx].hexCodes[wrapper.id],
colorValue: $appData.palettes[paletteIdx].colors[wrapper.id],
```

Triple lockstep removal — `Palettes/Views/Color/ColorsView.swift:382-394` (`deleteColor`) and `:396-414` (`deleteSelectedColors`): index found in `hexCodes`, then `colors.remove(at:)`, `hexCodes.remove(at:)`, `colorNames.remove(at:)`.

Persistence boundary — `Palettes/App/PersistentStore.swift:36-42`: `StoredPalette` stores `hexCodes: [String]` and `colorNames: [String]` (CloudKit-friendly). **Keep this shape**; map at the AppData boundary only (`Palettes/App/AppData.swift:143-152` for load, `:194-224` for persist).

Producers of the triple arrays: `Palettes/Managers/PaletteGenerator.swift:113-149` (and `mockGenerate` `:216-266`), `Palettes/Views/Color/GenerateView.swift:543-550` (`saveResult`), `AppData.swift` sample palettes `:262-317`, `Palettes/Views/Palette/NewPaletteView.swift`.

Find every consumer before starting: `grep -rn "hexCodes\|colorNames" Palettes --include="*.swift"` (run this; the list above is the load-bearing subset, not exhaustive — the working tree is evolving).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Enumerate call sites | `grep -rn "hexCodes\|colorNames" Palettes --include="*.swift"` | your worklist |
| Test | `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** TEST SUCCEEDED **` |

## Scope

**In scope**:
- `Palettes/ViewModels/PaletteViewModel.swift` (new `PaletteColor` struct + refactor)
- Every consumer surfaced by the grep (Views, Managers, `AppData` mapping)
- `PalettesTests/` additions

**Out of scope**:
- `Palettes/App/PersistentStore.swift` — do NOT change `StoredPalette`'s stored properties (CloudKit schema stability).
- `ColorViewModel` — single-color model is fine as is.
- Behavior changes of any kind — this is a pure representation refactor; UI must be pixel-identical.

## Git workflow

- Branch: `advisor/003-palette-color-struct`; conventional commits (`refactor: ...`); no push/PR unless instructed.

## Steps

### Step 1: Introduce `PaletteColor` and compatibility accessors

In `PaletteViewModel.swift`:

```swift
struct PaletteColor: Identifiable, Sendable, Hashable {
    var id = UUID()
    var color: Color
    var hex: String
    var name: String
}
```

Change `PaletteViewModel` to store `var paletteColors: [PaletteColor]`, and add **computed compatibility properties** `colors: [Color]`, `hexCodes: [String]`, `colorNames: [String]` (get-only) plus the existing memberwise-style init `init(id:name:colors:hexCodes:colorNames:isFavorite:)` that zips the three arrays into `paletteColors` — zip by index, padding missing hex with `"#808080"`-from-color via `ColorAdjustment`'s hex helper if available (check `Palettes/Utilities/ColorAdjustment.swift`) and missing names with `ColorNamer.name(forHex:)`. This keeps every read-only call site compiling unchanged.

**Verify**: build succeeds.

### Step 2: Migrate mutating call sites

The computed properties are get-only, so every *mutating* site now fails to compile — the compiler is your worklist. Rewrite each to mutate `paletteColors` directly:

- `PaletteEditSheet.removeColors` → `paletteColors.remove(atOffsets: offsets)` (one line, asymmetry gone).
- `PaletteEditSheet` bindings `:121-123` → bind `$appData.palettes[paletteIdx].paletteColors[wrapper.id].name/.hex/.color` (ColorEditView takes three bindings; pass the struct's fields).
- `ColorsView.deleteColor` / `deleteSelectedColors` → `paletteColors.removeAll { $0.hex.caseInsensitiveCompare(color.HEX) == .orderedSame }` (note: removeAll matches current firstIndex-single-removal only if hexes are unique per palette — preserve current semantics with `if let i = paletteColors.firstIndex(...) { paletteColors.remove(at: i) }`).
- Producers (PaletteGenerator, GenerateView.saveResult, NewPaletteView, sample data) → construct via the zipping init (no change) or directly with `[PaletteColor]`.

**Verify**: build succeeds; app behavior unchanged (run existing tests).

### Step 3: Map at the persistence boundary

In `AppData.load()` `:143-152` and `persistPalettes` `:203-208`, map `paletteColors` ↔ parallel `hexCodes`/`colorNames` arrays on `StoredPalette`. Loading zips (with the same padding rules as step 1, so a truncated CloudKit record can never produce mismatched lengths in memory).

**Verify**: build + all tests pass.

### Step 4: Tests

Add `PalettesTests/PaletteViewModelTests.swift`:

- Zipping init with equal-length arrays → `paletteColors.count` correct, fields aligned.
- Zipping init with `hexCodes` shorter than `colors` → padded, counts equal, no crash (this is the regression test for the crash class).
- `removeColors`-equivalent mutation keeps one array only (structural — no desync possible; assert compatibility accessors stay aligned).

## Done criteria

- [ ] `grep -rn "\.hexCodes\.remove\|\.colorNames\.remove\|\.colors\.remove" Palettes --include="*.swift"` → no matches (no more triple-lockstep mutation)
- [ ] `xcodebuild test ...` → `** TEST SUCCEEDED **` incl. new PaletteViewModel tests
- [ ] `StoredPalette` in `PersistentStore.swift` unchanged (`git diff Palettes/App/PersistentStore.swift` → empty)
- [ ] `plans/README.md` row updated

## STOP conditions

- Excerpts don't match the live code (views are actively changing on this branch).
- The grep worklist exceeds ~25 files — the refactor is bigger than estimated; report the list instead of grinding through it.
- Any site *requires* a settable `hexCodes`/`colorNames` that can't be expressed through `paletteColors` — report it, don't add a setter that reintroduces desync.
- SwiftData/CloudKit forces a `StoredPalette` change.

## Maintenance notes

- Future palette features (reorder, import — see plan 009) should operate on `paletteColors` only; reviewers should reject new code touching the compatibility accessors mutably.
- The compatibility get-only accessors can be deleted once call sites naturally migrate — deferred, not required here.
- Interacts with plan 002 (both touch `AppData` persist/load) — land 002 first.
