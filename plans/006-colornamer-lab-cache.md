# Plan 006: Precompute the named-color table's Lab values once

> **Executor instructions**: Follow step by step; verify each step; STOP
> conditions binding. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/Utilities/HEXParser.swift`
> Written against `9726b96` + uncommitted `icloud-sync` tree.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-test-baseline.md
- **Category**: perf
- **Planned at**: commit `9726b96`, 2026-07-15

## Why this matters

`ColorNamer.name(forHex:)` converts all ~460 reference colors from sRGB to Lab on **every call**, though the table is constant. Image color extraction calls it once per accepted centroid (`Palettes/Utilities/ImageColorExtractor.swift`, around line 65) and generation calls it per fill color — hundreds of thousands of redundant `pow()` calls on the scan/generate hot path. Caching the table's Lab values once is a pure win with identical output.

## Current state

`Palettes/Utilities/HEXParser.swift:444-454`:

```swift
var bestName = "Unknown"
var bestDelta = Double.greatestFiniteMagnitude

for entry in namedColors {
    let entryLab = sRGBtoLab(r: entry.r / 255.0, g: entry.g / 255.0, b: entry.b / 255.0)  // ← recomputed every call
    let delta = ciede2000(lab, entryLab)
    ...
}
```

`namedColors` is a `static` array of `(name, r, g, b)` tuples ending at `:426`. `sRGBtoLab` is `private static` at `:475-501`. Everything lives in `enum ColorNamer`.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Test | `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** TEST SUCCEEDED **` |

## Scope

**In scope**: `Palettes/Utilities/HEXParser.swift` (ColorNamer only), optionally `PalettesTests/ColorNamerTests.swift`.

**Out of scope**: the `namedColors` table contents; `ciede2000`; `Color.init?(hex:)`; any caller.

## Git workflow

Branch `advisor/006-colornamer-lab-cache`; conventional commit (`perf:`); no push/PR unless instructed.

## Steps

### Step 1: Add the cached table

Inside `ColorNamer`:

```swift
private static let namedColorsLab: [(name: String, lab: (L: Double, a: Double, b: Double))] =
    namedColors.map { ($0.name, sRGBtoLab(r: $0.r / 255.0, g: $0.g / 255.0, b: $0.b / 255.0)) }
```

(`static let` is lazily initialized once, thread-safe.) Change the loop in `name(forHex:)` to iterate `namedColorsLab` and use `entry.lab` directly.

### Step 2: Verify identical output

Plan 001's `ColorNamerTests` golden tests must pass unchanged — they are the equivalence proof. Optionally add one test asserting `name(forHex:)` over 20 arbitrary hexes equals a brute-force reimplementation… skip that; the golden tests suffice.

**Verify**: `xcodebuild test ...` → `** TEST SUCCEEDED **`, ColorNamer tests unchanged and green.

## Done criteria

- [ ] `grep -n "sRGBtoLab" Palettes/Utilities/HEXParser.swift` shows no call inside the `name(forHex:)` loop body (only the input conversion and the cache initializer)
- [ ] All tests pass
- [ ] `plans/README.md` row updated

## STOP conditions

- ColorNamer tests from plan 001 don't exist (dependency not landed).
- Tuple-typed `static let` hits a Swift 5 compiler limitation — use a small private struct instead; if that also fails, STOP.

## Maintenance notes

- If the named-color table grows, no change needed — the cache derives from it.
- Deferred (recorded, likely not worth it): O(n²) `perceptualDistance` pass in `ImageColorExtractor` could also reuse cached Labs; revisit only if scan feels slow on-device.
