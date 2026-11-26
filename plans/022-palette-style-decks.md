# Palette Style Decks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generating again from the same colors, mode and vibe in Auto, UI Light or UI Dark steps through distinct, named design styles instead of returning near-identical seeded variations.

**Architecture:** A pure `PaletteStyle` catalog holds 6 UI Light styles, 6 UI Dark styles and 8 Auto treatments. `PaletteBuilder` takes an optional style: interface modes read the style's role table, and Auto applies the treatment on top of the 60/30/10 builder. A `nil` style builds exactly as before. A pure `StyleDeck` shuffles each mode's styles once per input key and walks them without repeats. `PaletteGenerator` draws from a session-only `StyleDeckStore` on every fresh run and stores the style in `GenerationRecipe`, so described changes keep it. The result screen shows the style's name as a caption.

**Tech Stack:** Swift 6.4, SwiftUI, XCTest, OKLCH color math (`Palettes/Utilities/OKLCH.swift`).

**Spec:** `docs/superpowers/specs/2026-11-25-palette-style-decks-design.md` (local only: `docs/superpowers/` is git-ignored).

## Global Constraints

- Branch: `feature/palette-style-decks`, cut from `dev` (already created). Never commit to `main`.
- Deployment target is iOS 17.0. Don't raise it, and don't use iOS 26-only APIs outside `Palettes/Compatibility/` shims.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Every new class needs `nonisolated deinit {}`. Never write `isolated deinit`.
- New Swift files are auto-included by synchronized groups. Never hand-edit `Palettes.xcodeproj/project.pbxproj`.
- The builder stays pure (no UIKit, no FoundationModels) and deterministic: the same request, including the style, always builds the same palette.
- The user's colors ship first and verbatim. In interface modes, the first one is `Primary`.
- `style == nil` must build exactly the palettes it builds today (pinned by the golden test in Task 2).
- Interface styles: Text on Background ≥ 4.5:1, Muted Text on Background ≥ 3:1 (WCAG relative luminance).
- The deck lives in memory only: at most 32 keys, the least recently used dropped first. Nothing is persisted.
- Commit by explicit path (`git commit -- <paths>`). The working tree carries the user's unrelated uncommitted work, which must never be staged.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Build and test

Pick a booted iOS 27 simulator with `xcrun simctl list devices available` (at the time of writing: `iPhone 18 Pro`, `32BB5F12-AE8B-4FFA-985D-91E5D4FF435A`). Every command below uses:

```bash
DEST="platform=iOS Simulator,id=32BB5F12-AE8B-4FFA-985D-91E5D4FF435A"
```

Run one suite:

```bash
xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "$DEST" -derivedDataPath /tmp/palettes-dd -only-testing:PalettesTests/<SuiteName> 2>&1 | tail -30
```

If several agents run in parallel, give each its own `-derivedDataPath`.

## File map

| File | Change | Responsibility |
|---|---|---|
| `Palettes/Managers/PaletteStyle.swift` | Create | The 20 styles: names, decks, interface role tables, Auto treatments |
| `Palettes/Managers/StyleDeck.swift` | Create | `StyleDeckKey`, `StyleDeck` (shuffled or ordered non-repeating draws, LRU), Auto filtering and fit ranking, `StyleDeckStore` |
| `Palettes/Models/GenerationMode.swift` | Create | Mode menu model: Auto, a pinned color style, UI Light / UI Dark |
| `PalettesTests/GenerationModeTests.swift` | Create | Mode mapping |
| `Palettes/Managers/PaletteBuilder.swift` | Modify | `PaletteBuildRequest.style`, `PaletteTone.filling(from:)`, `impliedHarmony(of:)`, `Variation.narrow`, styled interface roles, Auto treatments |
| `Palettes/Managers/PaletteRefinement.swift` | Modify | `GenerationRecipe.style`; a harmony change clears it |
| `Palettes/Managers/PaletteGenerator.swift` | Modify | Draw a style on fresh runs (`deck:` parameter), reuse it on refinements, pass it to the builder |
| `Palettes/Views/Components/Generation/GenerationExperienceView.swift` | Modify | Style caption under the result's name |
| `Palettes/Views/Color/GenerateView.swift` | Modify | Pass `resultRecipe?.style?.displayName` to the result view |
| `PalettesTests/UnstyledGoldenTests.swift` | Create | Pins today's unstyled output |
| `PalettesTests/PaletteStyleTests.swift` | Create | Catalog shape |
| `PalettesTests/PaletteStyleBuilderTests.swift` | Create | Styled interface and Auto builds |
| `PalettesTests/StyleDeckTests.swift` | Create | Deck behavior and Auto filtering |
| `PalettesTests/PaletteRefinementTests.swift` | Modify | Recipe keeps or clears the style |
| `PalettesTests/PaletteGeneratorTests.swift` | Modify | Regenerate cycles; a change keeps the style |
| `plans/README.md` | Modify | Row for plan 022 |

---

### Task 1: `PaletteStyle` catalog

**Files:**
- Create: `Palettes/Managers/PaletteStyle.swift`
- Test: `PalettesTests/PaletteStyleTests.swift`

**Interfaces:**
- Consumes: `HarmonyScheme` (`Palettes/Managers/ColorHarmony.swift`), `PaletteTone` (`Palettes/Managers/PaletteBuilder.swift`).
- Produces:
  - `enum PaletteStyle: String, CaseIterable, Identifiable`, with cases `tonal, cleanNeutral, warmEditorial, softPastel, highContrast, colorDrenched, tonalDark, oledBlack, midnight, dimGraphite, espresso, neon, analogous603010, complementaryPop, monochromePop, splitComplementary, triadicPlayful, pastel, jewelTones, earthy`
  - `var displayName: String`
  - `static func deck(for: HarmonyScheme) -> [PaletteStyle]`
  - `enum StyleHue { case relative(Double), fixed(Double) }`
  - `struct RoleSpec { let L: Double; let C: Double; let hue: StyleHue }`
  - `static let interfaceRoleNames: [String]`
  - `var interfaceRoles: [String: RoleSpec]?`
  - `struct Treatment { harmonies, accentOffset, dropsSecondary, addsAccent, vividAccent, chromaScale, tone, earthPull }`
  - `var treatment: Treatment?`
  - `static func treatment(for: HarmonyScheme) -> PaletteStyle?`

- [ ] **Step 1: Write the failing test**

Create `PalettesTests/PaletteStyleTests.swift`:

```swift
//
//  PaletteStyleTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteStyleTests: XCTestCase {

    func testEachModeHasItsDeck() {
        XCTAssertEqual(PaletteStyle.deck(for: .uiLight).count, 6)
        XCTAssertEqual(PaletteStyle.deck(for: .uiDark).count, 6)
        XCTAssertEqual(PaletteStyle.deck(for: .auto).count, 8)
        XCTAssertTrue(PaletteStyle.deck(for: .triadic).isEmpty)
        let all = PaletteStyle.deck(for: .uiLight) + PaletteStyle.deck(for: .uiDark) + PaletteStyle.deck(for: .auto)
        XCTAssertEqual(Set(all), Set(PaletteStyle.allCases), "every style belongs to exactly one deck")
        XCTAssertEqual(all.count, PaletteStyle.allCases.count)
    }

    func testInterfaceStylesDefineEveryRole() {
        for style in PaletteStyle.deck(for: .uiLight) + PaletteStyle.deck(for: .uiDark) {
            let roles = try! XCTUnwrap(style.interfaceRoles, "\(style)")
            XCTAssertEqual(Set(roles.keys), Set(PaletteStyle.interfaceRoleNames), "\(style)")
            XCTAssertNil(style.treatment, "\(style)")
        }
    }

    func testAutoStylesCarryATreatment() {
        for style in PaletteStyle.deck(for: .auto) {
            let treatment = try! XCTUnwrap(style.treatment, "\(style)")
            XCTAssertFalse(treatment.harmonies.isEmpty, "\(style)")
            XCTAssertFalse(treatment.harmonies.contains { $0 == .auto || $0.isUIMode }, "\(style)")
            XCTAssertNil(style.interfaceRoles, "\(style)")
        }
    }

    func testDisplayNamesAreUnique() {
        let names = PaletteStyle.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains(""))
    }

    func testEachHarmonyHasOneTreatment() {
        XCTAssertEqual(PaletteStyle.treatment(for: .analogous), .analogous603010)
        XCTAssertEqual(PaletteStyle.treatment(for: .complementary), .complementaryPop)
        XCTAssertEqual(PaletteStyle.treatment(for: .monochromatic), .monochromePop)
        XCTAssertEqual(PaletteStyle.treatment(for: .splitComplementary), .splitComplementary)
        XCTAssertEqual(PaletteStyle.treatment(for: .triadic), .triadicPlayful)
        XCTAssertNil(PaletteStyle.treatment(for: .uiLight))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteStyleTests`
Expected: build FAILS with `cannot find 'PaletteStyle' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Palettes/Managers/PaletteStyle.swift`:

```swift
//
//  PaletteStyle.swift
//  Palettes
//
//  The named design principles a generated palette follows. Each mode has a
//  deck of them, and generating again from the same colors steps through
//  the deck (see `StyleDeck`), so each result looks different. Interface
//  styles carry a role table; Auto styles carry a treatment on top of the
//  60/30/10 harmonic builder.
//
//  Pure — no UIKit — so it is fully unit-testable.
//

import Foundation

enum PaletteStyle: String, CaseIterable, Identifiable {
    // UI Light
    case tonal, cleanNeutral, warmEditorial, softPastel, highContrast, colorDrenched
    // UI Dark
    case tonalDark, oledBlack, midnight, dimGraphite, espresso, neon
    // Auto
    case analogous603010, complementaryPop, monochromePop, splitComplementary, triadicPlayful, pastel, jewelTones, earthy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tonal: return "Tonal"
        case .cleanNeutral: return "Clean Neutral"
        case .warmEditorial: return "Warm Editorial"
        case .softPastel: return "Soft Pastel"
        case .highContrast: return "High Contrast"
        case .colorDrenched: return "Color Drenched"
        case .tonalDark: return "Tonal Dark"
        case .oledBlack: return "OLED Black"
        case .midnight: return "Midnight"
        case .dimGraphite: return "Dim Graphite"
        case .espresso: return "Espresso"
        case .neon: return "Neon"
        case .analogous603010: return "Analogous 60-30-10"
        case .complementaryPop: return "Complementary Pop"
        case .monochromePop: return "Monochrome + Pop"
        case .splitComplementary: return "Split Complementary"
        case .triadicPlayful: return "Triadic Playful"
        case .pastel: return "Pastel"
        case .jewelTones: return "Jewel Tones"
        case .earthy: return "Earthy"
        }
    }

    /// The styles a mode steps through. Explicit harmonies have none.
    static func deck(for scheme: HarmonyScheme) -> [PaletteStyle] {
        switch scheme {
        case .uiLight: return [.tonal, .cleanNeutral, .warmEditorial, .softPastel, .highContrast, .colorDrenched]
        case .uiDark: return [.tonalDark, .oledBlack, .midnight, .dimGraphite, .espresso, .neon]
        case .auto: return [.analogous603010, .complementaryPop, .monochromePop, .splitComplementary, .triadicPlayful, .pastel, .jewelTones, .earthy]
        case .complementary, .splitComplementary, .analogous, .triadic, .monochromatic: return []
        }
    }
}

// MARK: - Interface styles

extension PaletteStyle {
    enum StyleHue: Equatable {
        /// Degrees from the primary's hue.
        case relative(Double)
        /// A hue of its own, whatever the primary: the style's character.
        case fixed(Double)
    }

    /// One role's OKLCH lightness and chroma, and where its hue comes from.
    struct RoleSpec: Equatable {
        let L: Double
        let C: Double
        let hue: StyleHue
    }

    /// The roles an interface style defines. Success, Warning and Error
    /// are shared by every style.
    static let interfaceRoleNames = ["Primary", "Background", "Surface", "Primary Container", "Text", "Muted Text", "Border", "Accent", "Secondary"]

    /// Role tables for UI Light and UI Dark styles; nil for Auto styles.
    var interfaceRoles: [String: RoleSpec]? {
        func table(_ specs: RoleSpec...) -> [String: RoleSpec] {
            Dictionary(uniqueKeysWithValues: zip(Self.interfaceRoleNames, specs))
        }
        func r(_ L: Double, _ C: Double, _ degrees: Double = 0) -> RoleSpec { RoleSpec(L: L, C: C, hue: .relative(degrees)) }
        func f(_ L: Double, _ C: Double, _ hue: Double) -> RoleSpec { RoleSpec(L: L, C: C, hue: .fixed(hue)) }

        // Order: Primary, Background, Surface, Primary Container, Text,
        // Muted Text, Border, Accent, Secondary.
        switch self {
        case .tonal:
            return table(r(0.55, 0.15), r(0.985, 0.008), r(0.95, 0.02), r(0.90, 0.06), r(0.24, 0.03), r(0.50, 0.03), r(0.88, 0.025), r(0.62, 0.14, 60), r(0.48, 0.08, 30))
        case .cleanNeutral:
            return table(r(0.50, 0.15), r(0.99, 0), r(0.96, 0), r(0.93, 0.03), r(0.20, 0), r(0.52, 0), r(0.89, 0), r(0.42, 0.14), r(0.72, 0.10))
        case .warmEditorial:
            return table(r(0.52, 0.13), f(0.965, 0.02, 85), f(0.93, 0.028, 80), r(0.90, 0.04), f(0.25, 0.03, 50), f(0.50, 0.03, 60), f(0.86, 0.035, 75), r(0.55, 0.11, 180), r(0.55, 0.07, -40))
        case .softPastel:
            return table(r(0.70, 0.11), r(0.975, 0.018), r(0.935, 0.045, 40), r(0.92, 0.06), r(0.33, 0.05), r(0.55, 0.04), r(0.88, 0.04), r(0.80, 0.10, 40), r(0.82, 0.08, -50))
        case .highContrast:
            return table(r(0.55, 0.20), r(1.0, 0), r(0.965, 0), r(0.86, 0.13), r(0.14, 0), r(0.38, 0), r(0.18, 0), r(0.66, 0.22, 180), f(0.88, 0.17, 100))
        case .colorDrenched:
            return table(r(0.50, 0.16), r(0.94, 0.045), r(0.90, 0.06), r(0.85, 0.08), r(0.22, 0.07), r(0.42, 0.06), r(0.82, 0.07), r(0.60, 0.17, 180), r(0.35, 0.10))
        case .tonalDark:
            return table(r(0.72, 0.14), r(0.18, 0.012), r(0.25, 0.02), r(0.32, 0.06), r(0.95, 0.01), r(0.72, 0.02), r(0.35, 0.025), r(0.76, 0.13, 60), r(0.68, 0.08, 30))
        case .oledBlack:
            return table(r(0.74, 0.16), r(0, 0), r(0.17, 0), r(0.26, 0.05), r(0.93, 0), r(0.66, 0), r(0.27, 0), r(0.78, 0.17, 180), r(0.70, 0.10))
        case .midnight:
            return table(r(0.72, 0.14), f(0.19, 0.045, 265), f(0.25, 0.05, 265), r(0.33, 0.07), f(0.94, 0.02, 250), f(0.72, 0.04, 255), f(0.36, 0.06, 265), r(0.80, 0.12, 150), f(0.70, 0.10, 220))
        case .dimGraphite:
            return table(r(0.70, 0.12), r(0.27, 0.006), r(0.32, 0.008), r(0.38, 0.04), r(0.90, 0.006), r(0.68, 0.008), r(0.40, 0.01), r(0.74, 0.10, 120), r(0.65, 0.06, 30))
        case .espresso:
            return table(r(0.72, 0.13), f(0.20, 0.022, 55), f(0.26, 0.028, 55), r(0.34, 0.05), f(0.93, 0.025, 85), f(0.72, 0.03, 75), f(0.36, 0.035, 60), f(0.78, 0.13, 75), r(0.66, 0.08, -30))
        case .neon:
            return table(r(0.78, 0.19), r(0.15, 0.035), r(0.21, 0.05), r(0.30, 0.10), r(0.96, 0.02), r(0.70, 0.05), r(0.40, 0.12), r(0.84, 0.19, 180), r(0.80, 0.17, -90))
        default:
            return nil
        }
    }
}

// MARK: - Auto treatments

extension PaletteStyle {
    /// How an Auto style bends the 60/30/10 harmonic builder.
    struct Treatment: Equatable {
        /// The harmonies it can build; the seed picks when there are several.
        var harmonies: [HarmonyScheme]
        /// Replaces the scheme's accent offset (degrees from the main hue).
        var accentOffset: Double? = nil
        /// The secondary share goes to tones of the main color instead.
        var dropsSecondary = false
        /// Gives a monochromatic palette one accent (plain monochromatic has none).
        var addsAccent = false
        /// The accent takes vivid chroma whatever the tone.
        var vividAccent = false
        /// Multiplies the chroma of generated tones.
        var chromaScale = 1.0
        /// A tone it brings. A vibe's own tone wins channel by channel.
        var tone: PaletteTone? = nil
        /// Fraction of the shorter way each generated family's hue moves toward 60° (earth).
        var earthPull = 0.0
    }

    var treatment: Treatment? {
        switch self {
        case .analogous603010:
            return Treatment(harmonies: [.analogous], accentOffset: 60)
        case .complementaryPop:
            return Treatment(harmonies: [.complementary], accentOffset: 180, dropsSecondary: true, vividAccent: true)
        case .monochromePop:
            return Treatment(harmonies: [.monochromatic], accentOffset: 150, addsAccent: true, vividAccent: true)
        case .splitComplementary:
            return Treatment(harmonies: [.splitComplementary])
        case .triadicPlayful:
            return Treatment(harmonies: [.triadic], chromaScale: 1.2)
        case .pastel:
            return Treatment(harmonies: [.analogous, .complementary], tone: PaletteTone(lightness: .light, chroma: .muted))
        case .jewelTones:
            return Treatment(harmonies: [.triadic, .splitComplementary], tone: PaletteTone(lightness: .dark, chroma: .vivid))
        case .earthy:
            return Treatment(harmonies: [.analogous, .complementary], chromaScale: 0.6, earthPull: 0.25)
        default:
            return nil
        }
    }

    /// The Auto style that stands for a harmony: the one the deck keeps when
    /// the user's colors imply that harmony, or leads with when a vibe asks for it.
    static func treatment(for harmony: HarmonyScheme) -> PaletteStyle? {
        switch harmony {
        case .analogous: return .analogous603010
        case .complementary: return .complementaryPop
        case .monochromatic: return .monochromePop
        case .splitComplementary: return .splitComplementary
        case .triadic: return .triadicPlayful
        case .auto, .uiLight, .uiDark: return nil
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteStyleTests`
Expected: `** TEST SUCCEEDED **`, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add Palettes/Managers/PaletteStyle.swift PalettesTests/PaletteStyleTests.swift
git commit -m "Add PaletteStyle catalog: interface role tables and Auto treatments

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Palettes/Managers/PaletteStyle.swift PalettesTests/PaletteStyleTests.swift
```

---

### Task 2: Builder: golden pin, then interface styles

**Files:**
- Create: `PalettesTests/UnstyledGoldenTests.swift`
- Create: `PalettesTests/PaletteStyleBuilderTests.swift`
- Modify: `Palettes/Managers/PaletteBuilder.swift` (`PaletteTone`, `PaletteBuildRequest`, `Variation`, `build`, `interfaceEntries`)

**Interfaces:**
- Consumes: `PaletteStyle.interfaceRoles`, `PaletteStyle.RoleSpec`, `PaletteStyle.StyleHue` (Task 1).
- Produces:
  - `PaletteBuildRequest.style: PaletteStyle? = nil` (declared last, after `seed`)
  - `PaletteTone.filling(from: PaletteTone) -> PaletteTone`
  - `PaletteBuilder.Variation.narrow(rng: inout SplitMix64)`, plus `accentJitter` and `secondaryJitter`
  - `build` uses a local `tone` and `freeHue` (Task 3 relies on both)

- [ ] **Step 1: Record the golden BEFORE touching the builder**

Create `PalettesTests/UnstyledGoldenTests.swift`:

```swift
//
//  UnstyledGoldenTests.swift
//  PalettesTests
//
//  Styles must not change a single unstyled build. This pins a matrix of
//  today's outputs (schemes × anchors × sizes × seeds) as one FNV-1a hash.
//  If it fails after an intentional change to unstyled building, re-record:
//  the failure message prints the new hash.
//

import XCTest
@testable import Palettes

@MainActor
final class UnstyledGoldenTests: XCTestCase {

    static func signature() -> String {
        var lines: [String] = []
        let anchorSets: [[String]] = [[], ["#3060A0"], ["#808080"], ["#3366CC", "#CC6633"]]
        for scheme in [HarmonyScheme.auto, .complementary, .monochromatic, .uiLight, .uiDark] {
            for anchors in anchorSets {
                for size in [4, 8] {
                    for seed: UInt64 in [1, 7] {
                        let built = PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: size, scheme: scheme, hue: 200, seed: seed))
                        lines.append([scheme.rawValue, anchors.joined(separator: ","), "\(size)", "\(seed)",
                                      built.scheme.rawValue, built.hexes.joined(separator: ","), built.roles.joined(separator: ",")]
                            .joined(separator: "|"))
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    func testUnstyledBuildsAreUnchanged() {
        let hash = Self.fnv1a(Self.signature())
        XCTAssertEqual(hash, Self.golden, "unstyled output changed; new hash 0x\(String(hash, radix: 16, uppercase: true))")
    }

    /// Recorded on `dev` @ afa556b, before styles existed.
    private static let golden: UInt64 = 0x0
}
```

Run: `xcodebuild test ... -only-testing:PalettesTests/UnstyledGoldenTests`
Expected: FAIL with `unstyled output changed; new hash 0x<HEX>`. Replace `0x0` with that exact `0x<HEX>` and run again.
Expected: `** TEST SUCCEEDED **`.

Commit it on its own, so the golden predates every builder edit:

```bash
git add PalettesTests/UnstyledGoldenTests.swift
git commit -m "Pin unstyled builder output with a golden hash

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- PalettesTests/UnstyledGoldenTests.swift
```

- [ ] **Step 2: Write the failing interface-style tests**

Create `PalettesTests/PaletteStyleBuilderTests.swift`:

```swift
//
//  PaletteStyleBuilderTests.swift
//  PalettesTests
//
//  Styled builds: every interface style stays readable and fills its
//  roles, and every Auto treatment builds what it promises. Fixed seeds
//  make every run identical.
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteStyleBuilderTests: XCTestCase {

    /// Coral, deep blue, grey, pale yellow, and no color of the user's at all.
    private let anchorSets: [[String]] = [["#FF5E7A"], ["#3060A0"], ["#808080"], ["#FFF2A0"], []]
    private let lightStyles = PaletteStyle.deck(for: .uiLight)
    private let darkStyles = PaletteStyle.deck(for: .uiDark)
    private var interfaceStyles: [PaletteStyle] { lightStyles + darkStyles }

    private func mode(of style: PaletteStyle) -> HarmonyScheme {
        if lightStyles.contains(style) { return .uiLight }
        if darkStyles.contains(style) { return .uiDark }
        return .auto
    }

    private func build(_ anchors: [String], size: Int, style: PaletteStyle, tone: PaletteTone = .balanced, seed: UInt64 = 1) -> BuiltPalette {
        PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: size, scheme: mode(of: style), tone: tone, hue: 200, seed: seed, style: style))
    }

    private func hex(_ palette: BuiltPalette, _ role: String) -> String? {
        zip(palette.roles, palette.hexes).first { $0.0 == role }?.1
    }

    private func luminance(_ hex: String) -> Double {
        let c = OKLCH(hex: hex)!.linearSRGB()
        return 0.2126 * max(0, c.r) + 0.7152 * max(0, c.g) + 0.0722 * max(0, c.b)
    }

    private func contrast(_ a: String, _ b: String) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    // MARK: - Interface styles

    func testInterfaceStylesKeepTextReadable() throws {
        for style in interfaceStyles {
            for anchors in anchorSets {
                for size in [6, 8, 12] {
                    for seed: UInt64 in 0..<4 {
                        let palette = build(anchors, size: size, style: style, seed: seed)
                        let label = "\(style) \(anchors) size \(size) seed \(seed)"
                        let background = try XCTUnwrap(hex(palette, "Background"), label)
                        let text = try XCTUnwrap(hex(palette, "Text"), label)
                        let muted = try XCTUnwrap(hex(palette, "Muted Text"), label)
                        XCTAssertGreaterThanOrEqual(contrast(text, background), 4.5, label)
                        XCTAssertGreaterThanOrEqual(contrast(muted, background), 3.0, label)
                    }
                }
            }
        }
    }

    func testInterfaceStylesFillEveryRoleWithDistinctColors() {
        let allRoles = Set(PaletteStyle.interfaceRoleNames + ["Success", "Warning", "Error"])
        for style in interfaceStyles {
            for anchors in anchorSets {
                let palette = build(anchors, size: 12, style: style)
                XCTAssertEqual(palette.hexes.count, 12, "\(style) \(anchors)")
                XCTAssertEqual(Set(palette.hexes).count, 12, "repeated color in \(style) \(anchors): \(palette.hexes)")
                XCTAssertEqual(Set(palette.roles), allRoles, "\(style) \(anchors)")
            }
        }
    }

    func testInterfaceStylesKeepTheUsersColorAsPrimary() {
        for style in interfaceStyles {
            let palette = build(["#3060A0"], size: 8, style: style)
            XCTAssertEqual(palette.hexes.first, "#3060A0", "\(style)")
            XCTAssertEqual(palette.roles.first, "Primary", "\(style)")
        }
    }

    func testOLEDBlackAndHighContrastReachTheEnds() {
        XCTAssertEqual(hex(build([], size: 8, style: .oledBlack), "Background"), "#000000")
        XCTAssertEqual(hex(build([], size: 8, style: .highContrast), "Background"), "#FFFFFF")
    }

    func testStylesInADeckLookDifferent() {
        for deck in [lightStyles, darkStyles] {
            let palettes = deck.map { build(["#3060A0"], size: 8, style: $0).hexes }
            XCTAssertEqual(Set(palettes).count, deck.count)
            let backgrounds = deck.compactMap { hex(build(["#3060A0"], size: 8, style: $0), "Background") }
            XCTAssertEqual(Set(backgrounds).count, deck.count, "backgrounds: \(backgrounds)")
        }
    }

    func testSameStyleAndSeedBuildTheSamePalette() {
        for style in PaletteStyle.allCases {
            XCTAssertEqual(build(["#3060A0"], size: 8, style: style, seed: 9), build(["#3060A0"], size: 8, style: style, seed: 9), "\(style)")
        }
    }

    /// The seed only moves a style a little: its neutrals hold their place.
    func testSeedsKeepAStylesCharacter() throws {
        for style in interfaceStyles {
            let lightness = try (UInt64(0)..<10).map { seed -> Double in
                let background = try XCTUnwrap(hex(build(["#3060A0"], size: 8, style: style, seed: seed), "Background"))
                return OKLCH(hex: background)!.L
            }
            XCTAssertLessThanOrEqual(lightness.max()! - lightness.min()!, 0.035, "\(style): \(lightness)")
        }
    }

    func testGreyPrimaryKeepsFixedHueStylesAndGreysTheRest() throws {
        let warm = try XCTUnwrap(hex(build(["#808080"], size: 8, style: .warmEditorial), "Background"))
        XCTAssertGreaterThan(OKLCH(hex: warm)!.C, 0.012, "Warm Editorial's paper keeps its hue")
        let tonal = try XCTUnwrap(hex(build(["#808080"], size: 8, style: .tonal), "Background"))
        XCTAssertLessThan(OKLCH(hex: tonal)!.C, 0.004, "a grey has no hue to tint with")
        let accent = try XCTUnwrap(hex(build(["#808080"], size: 8, style: .tonal), "Accent"))
        XCTAssertGreaterThan(OKLCH(hex: accent)!.C, 0.05, "colored roles stay colored")
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteStyleBuilderTests`
Expected: build FAILS with `extra argument 'style' in call`.

- [ ] **Step 4: Add `style` and `filling(from:)`**

In `Palettes/Managers/PaletteBuilder.swift`, add to `struct PaletteTone`, after `static let balanced = PaletteTone()`:

```swift
    /// This tone where it says something, `fallback` where it is balanced:
    /// a vibe's own tone wins over a style's, channel by channel.
    func filling(from fallback: PaletteTone) -> PaletteTone {
        PaletteTone(lightness: lightness == .balanced ? fallback.lightness : lightness,
                    chroma: chroma == .balanced ? fallback.chroma : chroma)
    }
```

In `struct PaletteBuildRequest`, add after `var seed: UInt64`:

```swift
    /// The design style to follow (see `PaletteStyle`). nil builds exactly
    /// as the builder did before styles existed.
    var style: PaletteStyle? = nil
```

- [ ] **Step 5: Add `Variation.narrow`**

In `struct Variation`, after `var colorLightness = 0.0`, add:

```swift
        // Styled builds (see `narrow`)
        /// Degrees added to a style's relative Accent and Secondary hues.
        var accentJitter = 0.0
        var secondaryJitter = 0.0
```

After `init(rng: inout SplitMix64) { ... }`, add:

```swift
        /// A style sets the character, so the seed only moves it a little.
        /// Draws after `init(rng:)`'s draws, so unstyled builds are unchanged.
        mutating func narrow(rng: inout SplitMix64) {
            accentJitter = -15 + 30 * rng.nextUnit()
            secondaryJitter = -10 + 20 * rng.nextUnit()
            chroma = 0.95 + 0.1 * rng.nextUnit()
            neutralTint = 0.8 + 0.4 * rng.nextUnit()
            colorLightness = -0.03 + 0.06 * rng.nextUnit()
            neutralsFollowAccent = false
        }
```

- [ ] **Step 6: Thread `tone`, `freeHue` and `style` through `build`**

In `build(_:)`, replace everything from `let hue = request.hue ?? Double(rng.next() % 360)` through the `let generated = ...` expression with:

```swift
        let tone = request.tone
        let freeHue = request.hue ?? Double(rng.next() % 360)
        var variation = Variation(rng: &rng)
        if request.style != nil { variation.narrow(rng: &rng) }
        let main = mainColor(hue: freeHue, tone: tone)

        let generated = scheme.isUIMode
            ? interfaceEntries(anchors: anchors, placed: anchorHexes, main: main, size: size, tone: tone, isDark: scheme == .uiDark, variation: variation, style: request.style, freeHue: freeHue)
            : harmonicEntries(anchors: anchors, placed: anchorHexes, main: main, secondaryHue: scheme == .monochromatic ? nil : secondaryHue, size: size, scheme: scheme, tone: tone, variation: variation)
```

(Task 3 changes `let tone` to apply the treatment's tone.)

- [ ] **Step 7: Build styled roles in `interfaceEntries`**

Change the signature to:

```swift
    private static func interfaceEntries(
        anchors: [OKLCH],
        placed initial: [String],
        main: OKLCH,
        size: Int,
        tone: PaletteTone,
        isDark: Bool,
        variation: Variation = .fixed,
        style: PaletteStyle? = nil,
        freeHue: Double = 0
    ) -> [BuiltPalette.Entry] {
```

Make the first lines of the `for recipe in recipes where ...` loop body:

```swift
            if let spec = style?.interfaceRoles?[recipe.role] {
                let candidates = styledCandidates(spec, role: recipe.role, colored: recipe.chromaFollowsTone,
                                                  primary: primary, freeHue: freeHue, factor: factor, variation: variation)
                let hex = pick(candidates, placed: placed, floors: [5, 3])
                placed.append(hex)
                entries.append(BuiltPalette.Entry(hex: hex, role: recipe.role, group: .interface))
                continue
            }
```

(Success, Warning and Error have no spec in a style table, so they fall through to the existing code unchanged.)

Add this helper right after `interfaceEntries`:

```swift
    /// Candidates for one role of an interface style. Colored roles follow
    /// the tone and move a little with the seed; neutrals keep their place,
    /// so a background stays a background and text stays readable. A grey
    /// primary greys the relative neutrals, and its colored roles count
    /// from the brief's or seed's hue instead of the grey's meaningless angle.
    private static func styledCandidates(
        _ spec: PaletteStyle.RoleSpec,
        role: String,
        colored: Bool,
        primary: OKLCH,
        freeHue: Double,
        factor: Double,
        variation: Variation
    ) -> [OKLCH] {
        let isGrey = primary.C < 0.03
        var chroma = spec.C
        let hue: Double
        switch spec.hue {
        case .fixed(let degrees):
            hue = degrees
        case .relative(let degrees):
            let jitter = role == "Accent" ? variation.accentJitter : (role == "Secondary" ? variation.secondaryJitter : 0)
            hue = (isGrey && colored ? freeHue : primary.h) + degrees + jitter
            if !colored { chroma *= isGrey ? 0 : variation.neutralTint }
        }
        if colored { chroma *= factor * variation.chroma }
        let L = spec.L + (colored ? variation.colorLightness : 0)
        // A style may ask for exact black or white, so only 0...1 bounds it.
        return [0, 0.03, -0.03, 0.06, -0.06].map {
            OKLCH(L: min(1, max(0, L + $0)), C: chroma, h: OKLCH.wrap(hue))
        }
    }
```

- [ ] **Step 8: Run the interface tests and the golden**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteStyleBuilderTests -only-testing:PalettesTests/UnstyledGoldenTests -only-testing:PalettesTests/PaletteBuilderTests`
Expected: `** TEST SUCCEEDED **`. If a contrast assertion fails, the failure names the style and inputs. Fix the role table value in `PaletteStyle.swift` (raise Text or Muted Text contrast against Background) rather than loosening the test, and note the changed value in the commit message. If `UnstyledGoldenTests` fails, an unstyled code path changed: find it and restore it. Never re-record here.

- [ ] **Step 9: Commit**

```bash
git add Palettes/Managers/PaletteBuilder.swift PalettesTests/PaletteStyleBuilderTests.swift
git commit -m "Builder: interface styles with their own role tables

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Palettes/Managers/PaletteBuilder.swift PalettesTests/PaletteStyleBuilderTests.swift
```

---

### Task 3: Builder: Auto treatments

**Files:**
- Modify: `Palettes/Managers/PaletteBuilder.swift` (`resolveAuto` → `impliedHarmony(of:)`, `build`, `harmonicEntries`)
- Test: `PalettesTests/PaletteStyleBuilderTests.swift` (append)

**Interfaces:**
- Consumes: `PaletteStyle.treatment`, `PaletteStyle.Treatment` (Task 1); `PaletteTone.filling(from:)` and the `tone`/`freeHue` locals in `build` (Task 2).
- Produces: `static func PaletteBuilder.impliedHarmony(of anchors: [OKLCH]) -> HarmonyScheme?` (internal; Task 4 uses it).

- [ ] **Step 1: Write the failing tests**

Append inside `PaletteStyleBuilderTests` (before the final `}`):

```swift
    // MARK: - Auto treatments

    private func generated(_ palette: BuiltPalette) -> [OKLCH] {
        palette.entries.filter { $0.group != .anchor }.compactMap { OKLCH(hex: $0.hex) }
    }

    func testTreatmentsBuildTheirHarmony() {
        let expected: [PaletteStyle: HarmonyScheme] = [
            .analogous603010: .analogous, .complementaryPop: .complementary, .monochromePop: .monochromatic,
            .splitComplementary: .splitComplementary, .triadicPlayful: .triadic,
        ]
        for (style, harmony) in expected {
            for seed: UInt64 in 0..<5 {
                XCTAssertEqual(build([], size: 6, style: style, seed: seed).scheme, harmony, "\(style) seed \(seed)")
            }
        }
    }

    func testSeededTreatmentsStayInTheirHarmonies() {
        for style in [PaletteStyle.pastel, .jewelTones, .earthy] {
            let allowed = Set(style.treatment!.harmonies)
            let built = Set((UInt64(0)..<20).map { build(["#3060A0"], size: 6, style: style, seed: $0).scheme })
            XCTAssertTrue(built.isSubset(of: allowed), "\(style): \(built)")
            XCTAssertEqual(built.count, allowed.count, "\(style) should reach each of its harmonies over 20 seeds")
        }
    }

    func testUsersColorsOutrankTheTreatmentsHarmony() {
        // Blue and orange sit 143° apart: triadic, whatever the treatment says.
        XCTAssertEqual(build(["#3366CC", "#CC6633"], size: 6, style: .pastel).scheme, .triadic)
        XCTAssertEqual(PaletteBuilder.impliedHarmony(of: [OKLCH(hex: "#3366CC")!, OKLCH(hex: "#CC6633")!]), .triadic)
        XCTAssertEqual(PaletteBuilder.impliedHarmony(of: [OKLCH(hex: "#808080")!]), .monochromatic)
        XCTAssertNil(PaletteBuilder.impliedHarmony(of: [OKLCH(hex: "#3060A0")!]))
    }

    func testEveryTreatmentReachesItsSizeWithoutRepeats() {
        for style in PaletteStyle.deck(for: .auto) {
            for anchors in anchorSets + [["#3366CC", "#CC6633"]] {
                for size in [4, 8, 12] {
                    let hexes = build(anchors, size: size, style: style).hexes
                    XCTAssertEqual(hexes.count, size, "\(style) \(anchors) size \(size)")
                    XCTAssertEqual(Set(hexes).count, size, "repeated color in \(style): \(hexes)")
                }
            }
        }
    }

    func testComplementaryPopHasNoSecondaryTonesAndOneAccent() {
        for size in [6, 8] {
            let palette = build(["#3060A0"], size: size, style: .complementaryPop)
            XCTAssertTrue(palette.entries.filter { $0.group == .secondary }.isEmpty, "size \(size)")
            XCTAssertEqual(palette.entries.filter { $0.group == .accent }.count, 1, "size \(size)")
        }
    }

    func testMonochromePopAddsOneAccentOffTheMainHue() throws {
        let palette = build(["#3060A0"], size: 6, style: .monochromePop)
        XCTAssertEqual(palette.scheme, .monochromatic)
        let accents = palette.entries.filter { $0.group == .accent }
        XCTAssertEqual(accents.count, 1)
        let accent = try XCTUnwrap(OKLCH(hex: accents[0].hex))
        let anchor = try XCTUnwrap(OKLCH(hex: "#3060A0"))
        XCTAssertEqual(OKLCH.hueDistance(accent.h, anchor.h + 150), 0, accuracy: 20)
    }

    func testMonochromePopOnAGreyTakesTheFreeHue() throws {
        // hue: 200 in `build`, so the accent sits near 200 + 150 = 350.
        let palette = build(["#808080"], size: 6, style: .monochromePop)
        let accent = try XCTUnwrap(palette.entries.first { $0.group == .accent }.flatMap { OKLCH(hex: $0.hex) })
        XCTAssertLessThanOrEqual(OKLCH.hueDistance(accent.h, 350), 25)
    }

    func testPastelIsLighterThanJewelTones() {
        for seed: UInt64 in 0..<4 {
            func meanL(_ style: PaletteStyle) -> Double {
                let colors = generated(build(["#3060A0"], size: 8, style: style, seed: seed))
                return colors.map(\.L).reduce(0, +) / Double(colors.count)
            }
            XCTAssertGreaterThan(meanL(.pastel), meanL(.jewelTones) + 0.15, "seed \(seed)")
        }
    }

    func testVibeToneWinsOverTheTreatment() {
        func meanL(_ tone: PaletteTone) -> Double {
            let colors = generated(build(["#3060A0"], size: 8, style: .pastel, tone: tone))
            return colors.map(\.L).reduce(0, +) / Double(colors.count)
        }
        XCTAssertLessThan(meanL(PaletteTone(lightness: .dark)), meanL(.balanced) - 0.1)
    }

    func testEarthyPullsHuesTowardEarth() throws {
        let anchor = try XCTUnwrap(OKLCH(hex: "#3060A0"))
        let dominant = build(["#3060A0"], size: 8, style: .earthy).entries
            .filter { $0.group == .dominant }
            .compactMap { OKLCH(hex: $0.hex) }
            .filter { $0.C >= 0.02 }
        XCTAssertFalse(dominant.isEmpty)
        for color in dominant {
            // A 25% pull moves blue (~262°) about 40° toward 60°; allow for hue rounding at low chroma.
            XCTAssertLessThan(OKLCH.hueDistance(color.h, 60), OKLCH.hueDistance(anchor.h, 60) - 20)
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteStyleBuilderTests`
Expected: build FAILS with `type 'PaletteBuilder' has no member 'impliedHarmony'`.

- [ ] **Step 3: Extract `impliedHarmony(of:)`**

Replace `resolveAuto` in `PaletteBuilder.swift` with:

```swift
    /// The harmony the user's colors already imply: two or more chromatic
    /// colors by their hue distance, all-grey colors as monochromatic. nil
    /// when the colors leave it open.
    static func impliedHarmony(of anchors: [OKLCH]) -> HarmonyScheme? {
        let chromatic = anchors.filter { $0.C >= 0.03 }
        if chromatic.count >= 2 {
            let d = OKLCH.hueDistance(chromatic[0].h, chromatic[1].h)
            if d <= 45 { return .analogous }
            if abs(d - 180) <= 30 { return .complementary }
            if abs(d - 120) <= 25 { return .triadic }
            return .splitComplementary
        }
        if !anchors.isEmpty && chromatic.isEmpty { return .monochromatic }
        return nil
    }

    /// Two or more of the user's colors already imply a harmony; otherwise
    /// Auto draws one, weighted toward the calmer schemes.
    private static func resolveAuto(anchors: [OKLCH], rng: inout SplitMix64) -> HarmonyScheme {
        if let implied = impliedHarmony(of: anchors) { return implied }
        let roll = rng.nextUnit()
        if roll < 0.30 { return .analogous }
        if roll < 0.55 { return .complementary }
        if roll < 0.80 { return .splitComplementary }
        if roll < 0.90 { return .triadic }
        return .monochromatic
    }
```

- [ ] **Step 4: Apply the treatment in `build`**

In `build(_:)`, replace these two lines:

```swift
        var scheme = request.scheme == .auto ? resolveAuto(anchors: anchors, rng: &rng) : request.scheme
        if request.scheme == .auto, secondaryHue != nil, scheme == .monochromatic { scheme = .complementary }
```

with:

```swift
        let treatment = request.scheme == .auto ? request.style?.treatment : nil
        var scheme: HarmonyScheme
        if let treatment {
            // The user's colors outrank the treatment's harmony; otherwise
            // the seed picks among the treatment's.
            scheme = impliedHarmony(of: anchors)
                ?? treatment.harmonies[Int(rng.next() % UInt64(treatment.harmonies.count))]
        } else {
            scheme = request.scheme == .auto ? resolveAuto(anchors: anchors, rng: &rng) : request.scheme
            if request.scheme == .auto, secondaryHue != nil, scheme == .monochromatic { scheme = .complementary }
        }
```

Replace `let tone = request.tone` (added in Task 2) with:

```swift
        let tone = treatment?.tone.map { request.tone.filling(from: $0) } ?? request.tone
```

Change the `harmonicEntries(...)` call so it ends with `variation: variation, treatment: treatment, freeHue: freeHue)`.

- [ ] **Step 5: Apply the treatment in `harmonicEntries`**

Add two parameters at the end of the signature:

```swift
        variation: Variation,
        treatment: PaletteStyle.Treatment? = nil,
        freeHue: Double = 0
    ) -> [BuiltPalette.Entry] {
```

Replace

```swift
        let roots = anchors.isEmpty ? [main] : anchors
        if anchors.isEmpty {
            entries.append(place([main], floors: [0], role: nil, group: .dominant))
        }

        let counts = groupCounts(size: size, scheme: scheme)
```

with:

```swift
        let pull = treatment?.earthPull ?? 0
        let lead = pulled(main, by: pull)
        let roots = (anchors.isEmpty ? [lead] : anchors).map { pulled($0, by: pull) }
        if anchors.isEmpty {
            entries.append(place([lead], floors: [0], role: nil, group: .dominant))
        }

        var counts = groupCounts(size: size, scheme: scheme)
        if treatment?.dropsSecondary == true {
            counts.dominant += counts.secondary
            counts.secondary = 0
        }
        if treatment?.addsAccent == true, counts.accent == 0, size >= 4, counts.dominant > 1 {
            counts.accent = 1
            counts.dominant -= 1
        }
        let chroma = variation.chroma * (treatment?.chromaScale ?? 1)
```

Replace `let accentOffset = schemeOffsets.count > 1 ? schemeOffsets[1] : schemeOffsets[0]` with:

```swift
        let accentOffset = treatment?.accentOffset ?? (schemeOffsets.count > 1 ? schemeOffsets[1] : schemeOffsets[0])
```

In the `.dominant` case, change `chroma: variation.chroma` to `chroma: chroma`. In the `.secondary` case, change `chroma: variation.chroma` to `chroma: chroma`.

Replace the `.accent` case with:

```swift
            case .accent:
                // A grey root's hue angle means nothing: a treatment's accent
                // counts from the brief's or seed's hue instead.
                let accentRoot = treatment != nil && roots[0].C < 0.03
                    ? OKLCH(L: roots[0].L, C: roots[0].C, h: freeHue) : roots[0]
                let accentTone = treatment?.vividAccent == true ? PaletteTone(lightness: tone.lightness, chroma: .vivid) : tone
                slotted[position] = place(accentCandidates(root: accentRoot, offset: accentOffset, tone: accentTone, start: variation.accentStart), floors: [12, 9, 6], role: "Accent", group: .accent)
```

Add this helper after `harmonicEntries`:

```swift
    /// `color` with its hue moved `fraction` of the shorter way toward 60°
    /// (earth tones). Greys have no hue to move.
    private static func pulled(_ color: OKLCH, by fraction: Double) -> OKLCH {
        guard fraction > 0, color.C >= 0.03 else { return color }
        var delta = (60 - color.h).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return OKLCH(L: color.L, C: color.C, h: OKLCH.wrap(color.h + delta * fraction))
    }
```

- [ ] **Step 6: Run the builder suites**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteStyleBuilderTests -only-testing:PalettesTests/UnstyledGoldenTests -only-testing:PalettesTests/PaletteBuilderTests`
Expected: `** TEST SUCCEEDED **`. The golden must still pass unchanged.

- [ ] **Step 7: Commit**

```bash
git add Palettes/Managers/PaletteBuilder.swift PalettesTests/PaletteStyleBuilderTests.swift
git commit -m "Builder: Auto treatments on the 60/30/10 harmonic builder

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Palettes/Managers/PaletteBuilder.swift PalettesTests/PaletteStyleBuilderTests.swift
```

---

### Task 4: Auto fit ranking, `StyleDeck` and `StyleDeckStore`

> Amended 2026-11-26 (user request). Auto ranks the color styles by how well they suit the user's color: the best fit comes first, and each Regenerate steps to the next-best. With no colors there's nothing to rank against, so Auto shuffles. UI Light and UI Dark keep shuffling.

**Files:**
- Modify: `Palettes/Managers/PaletteStyle.swift` (add an "Auto fit" extension)
- Create: `Palettes/Managers/StyleDeck.swift`
- Test: `PalettesTests/StyleDeckTests.swift`

**Interfaces:**
- Consumes: `PaletteStyle.deck(for:)` and `PaletteStyle.treatment(for:)` (Task 1); `PaletteBuilder.impliedHarmony(of:)` (Task 3); `PaletteBuilder.normalize(_:)`; `OKLCH(hex:)` and `OKLCH.hueDistance`; `PaletteBrief` (`tone`, `scheme`, `secondaryHue`, `.neutral`).
- Produces:
  - `func PaletteStyle.fit(for: OKLCH) -> Double`
  - `static func PaletteStyle.ranked(_: [PaletteStyle], for: OKLCH) -> [PaletteStyle]`
  - `struct StyleDeckKey: Hashable { init(anchors: [String], scheme: HarmonyScheme, vibe: String?) }`
  - `struct StyleDeck` with:
    - `static let capacity = 32`
    - `var keyCount: Int`
    - `func contains(_: StyleDeckKey) -> Bool`
    - `mutating func next<G: RandomNumberGenerator>(for: StyleDeckKey, candidates: [PaletteStyle], first: PaletteStyle? = nil, ordered: Bool = false, using: inout G) -> PaletteStyle?`
    - `static func autoCandidates(anchors: [String], brief: PaletteBrief) -> (styles: [PaletteStyle], first: PaletteStyle?, ordered: Bool)`
  - `final class StyleDeckStore` with `static let shared`, `init()`, and `func next(for: StyleDeckKey, candidates: [PaletteStyle], first: PaletteStyle? = nil, ordered: Bool = false) -> PaletteStyle?`

- [ ] **Step 1: Write the failing tests**

Create `PalettesTests/StyleDeckTests.swift`:

```swift
//
//  StyleDeckTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class StyleDeckTests: XCTestCase {

    private let light = PaletteStyle.deck(for: .uiLight)
    private let auto = PaletteStyle.deck(for: .auto)

    private func key(_ anchors: [String] = ["#3060A0"], _ scheme: HarmonyScheme = .uiLight, _ vibe: String? = nil) -> StyleDeckKey {
        StyleDeckKey(anchors: anchors, scheme: scheme, vibe: vibe)
    }

    // MARK: - Fit

    func testEachColorKindSuitsItsStyle() {
        let cases: [(String, PaletteStyle)] = [
            ("#808080", .monochromePop),     // grey
            ("#FFF2A0", .pastel),            // pale yellow
            ("#8B5A2B", .earthy),            // warm muted brown
            ("#1E3A8A", .jewelTones),        // deep saturated navy
            ("#FF5E7A", .complementaryPop),  // vivid coral
        ]
        for (hex, expected) in cases {
            let color = OKLCH(hex: hex)!
            XCTAssertEqual(PaletteStyle.ranked(auto, for: color).first, expected, "\(hex) L \(color.L) C \(color.C) h \(color.h)")
        }
    }

    func testRankingKeepsEveryStyleAndBreaksTiesByDeckOrder() {
        let ranked = PaletteStyle.ranked(auto, for: OKLCH(hex: "#3060A0")!)
        XCTAssertEqual(Set(ranked), Set(auto))
        XCTAssertEqual(ranked.count, auto.count)
        // Equal fits keep their deck order: Monochrome + Pop and Pastel never outrank the calm default for a mid blue.
        XCTAssertLessThan(ranked.firstIndex(of: .analogous603010)!, ranked.firstIndex(of: .monochromePop)!)
    }

    func testInterfaceStylesHaveNoFit() {
        for style in light + PaletteStyle.deck(for: .uiDark) {
            XCTAssertEqual(style.fit(for: OKLCH(hex: "#3060A0")!), 0, "\(style)")
        }
    }

    // MARK: - Drawing

    func testEveryStyleShowsOnceBeforeAnyRepeats() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 3)
        let drawn = (0..<light.count).compactMap { _ in deck.next(for: key(), candidates: light, using: &rng) }
        XCTAssertEqual(drawn.count, light.count)
        XCTAssertEqual(Set(drawn), Set(light))
    }

    func testNoRepeatAcrossAReshuffle() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 11)
        var previous: PaletteStyle?
        for round in 0..<50 {
            var seen: Set<PaletteStyle> = []
            for _ in 0..<light.count {
                let style = deck.next(for: key(), candidates: light, using: &rng)!
                XCTAssertNotEqual(style, previous, "round \(round)")
                seen.insert(style)
                previous = style
            }
            XCTAssertEqual(seen, Set(light), "round \(round)")
        }
    }

    func testOrderedDeckWalksTheGivenOrderEveryRound() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 4)
        let order: [PaletteStyle] = [.pastel, .analogous603010, .earthy]
        let drawn = (0..<6).compactMap { _ in deck.next(for: key(["#FFF2A0"], .auto), candidates: order, ordered: true, using: &rng) }
        XCTAssertEqual(drawn, order + order)
    }

    func testKeysAreIndependent() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 5)
        for _ in 0..<3 { _ = deck.next(for: key(["#3060A0"]), candidates: light, using: &rng) }
        let other = (0..<light.count).compactMap { _ in deck.next(for: key(["#FF5E7A"]), candidates: light, using: &rng) }
        XCTAssertEqual(Set(other), Set(light))
    }

    func testKeyNormalizesItsInputs() {
        XCTAssertEqual(StyleDeckKey(anchors: ["3060a0"], scheme: .uiLight, vibe: "  Calm Ocean "),
                       StyleDeckKey(anchors: ["#3060A0"], scheme: .uiLight, vibe: "calm ocean"))
        XCTAssertNotEqual(key(["#3060A0"], .uiLight), key(["#3060A0"], .uiDark))
    }

    func testOldestKeyIsDroppedPastCapacity() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 1)
        let keys = (0...StyleDeck.capacity).map { key([String(format: "#%06X", $0 * 4099)]) }
        for k in keys { _ = deck.next(for: k, candidates: light, using: &rng) }
        XCTAssertEqual(deck.keyCount, StyleDeck.capacity)
        XCTAssertFalse(deck.contains(keys[0]))
        XCTAssertTrue(deck.contains(keys[StyleDeck.capacity]))
    }

    func testFirstStyleLeadsAFreshShuffledDeck() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 2)
        XCTAssertEqual(deck.next(for: key(), candidates: light, first: .highContrast, using: &rng), .highContrast)
        let rest = (1..<light.count).compactMap { _ in deck.next(for: key(), candidates: light, first: .highContrast, using: &rng) }
        XCTAssertFalse(rest.contains(.highContrast), "first only leads; it doesn't repeat")
    }

    func testNoCandidatesGiveNoStyle() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 1)
        XCTAssertNil(deck.next(for: key(), candidates: [], using: &rng))
    }

    func testStoreCyclesThroughADeck() {
        let store = StyleDeckStore()
        let drawn = (0..<light.count).compactMap { _ in store.next(for: key(), candidates: light) }
        XCTAssertEqual(Set(drawn), Set(light))
    }

    // MARK: - Auto candidates

    func testAutoWithoutColorsShufflesTheFullDeck() {
        let result = StyleDeck.autoCandidates(anchors: [], brief: .neutral)
        XCTAssertEqual(Set(result.styles), Set(auto))
        XCTAssertFalse(result.ordered)
        XCTAssertNil(result.first)
    }

    func testAutoWithAColorRanksBestFitFirst() {
        let result = StyleDeck.autoCandidates(anchors: ["#FFF2A0"], brief: .neutral)
        XCTAssertTrue(result.ordered)
        XCTAssertEqual(result.styles, PaletteStyle.ranked(auto, for: OKLCH(hex: "#FFF2A0")!))
        XCTAssertEqual(result.styles.first, .pastel)
    }

    func testImpliedHarmonyLeadsThenTheToneTreatmentsByFit() {
        let result = StyleDeck.autoCandidates(anchors: ["#3366CC", "#CC6633"], brief: .neutral)
        XCTAssertTrue(result.ordered)
        XCTAssertEqual(result.styles.first, .triadicPlayful)
        XCTAssertEqual(Set(result.styles), [.triadicPlayful, .pastel, .jewelTones, .earthy])
    }

    func testGreyColorsKeepMonochromePopPastelAndJewel() {
        let result = StyleDeck.autoCandidates(anchors: ["#808080"], brief: .neutral)
        XCTAssertEqual(result.styles.first, .monochromePop)
        XCTAssertEqual(Set(result.styles), [.monochromePop, .pastel, .jewelTones])
    }

    func testVibeToneRemovesContradictingTreatments() {
        func styles(_ lightness: PaletteTone.Lightness = .balanced, _ chroma: PaletteTone.Chroma = .balanced) -> [PaletteStyle] {
            var brief = PaletteBrief.neutral
            brief.tone = PaletteTone(lightness: lightness, chroma: chroma)
            return StyleDeck.autoCandidates(anchors: [], brief: brief).styles
        }
        XCTAssertFalse(styles(.light).contains(.jewelTones))
        XCTAssertFalse(styles(.dark).contains(.pastel))
        XCTAssertFalse(styles(.balanced, .vivid).contains(.pastel))
        XCTAssertFalse(styles(.balanced, .vivid).contains(.earthy))
        XCTAssertFalse(styles(.balanced, .muted).contains(.jewelTones))
        XCTAssertFalse(styles(.balanced, .muted).contains(.triadicPlayful))
    }

    func testVibeHarmonyLeads() {
        var brief = PaletteBrief.neutral
        brief.scheme = .triadic
        // No colors: it leads the shuffle.
        XCTAssertEqual(StyleDeck.autoCandidates(anchors: [], brief: brief).first, .triadicPlayful)
        // One color: it leads the ranking.
        XCTAssertEqual(StyleDeck.autoCandidates(anchors: ["#FFF2A0"], brief: brief).styles.first, .triadicPlayful)
        // Colors that imply a harmony outrank the vibe's.
        XCTAssertEqual(StyleDeck.autoCandidates(anchors: ["#3366CC", "#4D7FE0"], brief: brief).styles.first, .analogous603010)
    }

    func testTwoHueVibeDropsMonochrome() {
        var brief = PaletteBrief.neutral
        brief.secondaryHue = 40
        XCTAssertFalse(StyleDeck.autoCandidates(anchors: [], brief: brief).styles.contains(.monochromePop))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test ... -only-testing:PalettesTests/StyleDeckTests`
Expected: build FAILS with `cannot find 'StyleDeck' in scope` (and `has no member 'ranked'`).

- [ ] **Step 3: Add the fit ranking**

Append to `Palettes/Managers/PaletteStyle.swift`:

```swift
// MARK: - Auto fit

extension PaletteStyle {
    /// How well this Auto style suits a color (higher is better; 0 for
    /// interface styles). Pale colors suit Pastel, deep saturated ones Jewel
    /// Tones, warm muted ones (browns, olives) Earthy, greys Monochrome + Pop,
    /// and vivid ones the pop schemes. Calm analogous is the general default.
    func fit(for color: OKLCH) -> Double {
        let L = color.L
        let C = color.C
        let warm = C >= 0.03 && OKLCH.hueDistance(color.h, 60) <= 50
        switch self {
        case .monochromePop: return C < 0.03 ? 10 : 1
        case .pastel: return L >= 0.80 ? 9 : (L >= 0.70 ? 5 : 0)
        case .jewelTones: return L <= 0.45 && C >= 0.08 ? 9 : (L <= 0.55 && C >= 0.12 ? 5 : 0)
        case .earthy: return warm && C < 0.11 && (0.30...0.75).contains(L) ? 9 : (warm && C < 0.15 ? 4 : 0)
        case .complementaryPop: return C >= 0.17 ? 8 : (C >= 0.12 ? 5 : 2)
        case .triadicPlayful: return C >= 0.17 ? 7 : (C >= 0.12 ? 4 : 1)
        case .analogous603010: return 6
        case .splitComplementary: return 4
        default: return 0
        }
    }

    /// `styles`, best-suited to `color` first. Ties keep their given order.
    static func ranked(_ styles: [PaletteStyle], for color: OKLCH) -> [PaletteStyle] {
        styles.enumerated()
            .sorted { a, b in
                let (fitA, fitB) = (a.element.fit(for: color), b.element.fit(for: color))
                return fitA != fitB ? fitA > fitB : a.offset < b.offset
            }
            .map(\.element)
    }
}
```

- [ ] **Step 4: Write `StyleDeck.swift`**

Create `Palettes/Managers/StyleDeck.swift`:

```swift
//
//  StyleDeck.swift
//  Palettes
//
//  Generating again from the same colors, mode and vibe should look
//  different. The deck hands out a mode's styles in turn, so every style
//  shows before any repeats. Interface modes shuffle, and a reshuffle never
//  starts with the style that just showed. Auto with the user's colors walks
//  the styles best-suited first. Session memory only: nothing here is persisted.
//
//  `StyleDeck` is pure and takes its random source, so it is fully
//  unit-testable. `StyleDeckStore` is the app's one instance.
//

import Foundation

/// What counts as "the same request": the user's colors in order, the
/// mode, and the vibe's words.
struct StyleDeckKey: Hashable {
    let anchors: [String]
    let scheme: HarmonyScheme
    let vibe: String

    init(anchors: [String], scheme: HarmonyScheme, vibe: String?) {
        self.anchors = PaletteBuilder.normalize(anchors)
        self.scheme = scheme
        self.vibe = (vibe ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct StyleDeck {
    static let capacity = 32

    private struct Round {
        var order: [PaletteStyle]
        var position: Int
    }

    private var rounds: [StyleDeckKey: Round] = [:]
    /// Keys from least to most recently drawn.
    private var recency: [StyleDeckKey] = []

    var keyCount: Int { rounds.count }

    func contains(_ key: StyleDeckKey) -> Bool { rounds[key] != nil }

    /// The next style for `key`.
    /// - `ordered`: every round walks `candidates` in the given order (Auto's
    ///   best-fit ranking). Otherwise each round is a shuffle.
    /// - `first`: leads a fresh shuffled deck (a vibe's harmony).
    /// - Returns nil only when there are no candidates.
    mutating func next<G: RandomNumberGenerator>(
        for key: StyleDeckKey,
        candidates: [PaletteStyle],
        first: PaletteStyle? = nil,
        ordered: Bool = false,
        using rng: inout G
    ) -> PaletteStyle? {
        guard !candidates.isEmpty else { return nil }
        var round: Round
        if let existing = rounds[key], Set(existing.order) == Set(candidates) {
            round = existing
        } else {
            var order = ordered ? candidates : candidates.shuffled(using: &rng)
            if !ordered, let first, let index = order.firstIndex(of: first) { order.swapAt(0, index) }
            round = Round(order: order, position: 0)
        }
        if round.position >= round.order.count {
            let last = round.order.last
            var order = ordered ? candidates : candidates.shuffled(using: &rng)
            if !ordered, order.count > 1, order[0] == last { order.swapAt(0, 1) }
            round = Round(order: order, position: 0)
        }
        let style = round.order[round.position]
        round.position += 1
        store(round, for: key)
        return style
    }

    private mutating func store(_ round: Round, for key: StyleDeckKey) {
        if rounds[key] == nil, rounds.count >= Self.capacity, let oldest = recency.first {
            rounds[oldest] = nil
            recency.removeFirst()
        }
        rounds[key] = round
        recency.removeAll { $0 == key }
        recency.append(key)
    }
}

// MARK: - Auto

extension StyleDeck {
    /// The Auto styles that fit the user's colors and vibe, and how to walk them.
    /// - Colors that imply a harmony keep that harmony's style plus the tone
    ///   styles, which then build on the implied harmony.
    /// - A vibe's tone drops the styles that contradict it.
    /// - The colors' implied harmony leads; otherwise a vibe's harmony leads.
    /// - With the user's colors, the rest go best-suited first, every round
    ///   (`ordered`). With none there's nothing to suit, so the deck shuffles.
    static func autoCandidates(anchors: [String], brief: PaletteBrief) -> (styles: [PaletteStyle], first: PaletteStyle?, ordered: Bool) {
        let colors = PaletteBuilder.normalize(anchors).compactMap { OKLCH(hex: $0) }
        let implied = PaletteBuilder.impliedHarmony(of: colors)
        var styles: [PaletteStyle]
        switch implied {
        case .monochromatic?:
            styles = [.monochromePop, .pastel, .jewelTones]
        case let harmony?:
            styles = [PaletteStyle.treatment(for: harmony)].compactMap { $0 } + [.pastel, .jewelTones, .earthy]
        case nil:
            styles = PaletteStyle.deck(for: .auto)
        }
        // A vibe that names two colors is not a one-hue palette.
        if colors.isEmpty, brief.secondaryHue != nil {
            styles.removeAll { $0 == .monochromePop }
        }

        var removed: Set<PaletteStyle> = []
        switch brief.tone.lightness {
        case .light: removed.insert(.jewelTones)
        case .dark: removed.insert(.pastel)
        case .balanced: break
        }
        switch brief.tone.chroma {
        case .vivid: removed.formUnion([.pastel, .earthy])
        case .muted: removed.formUnion([.jewelTones, .triadicPlayful])
        case .balanced: break
        }
        let kept = styles.filter { !removed.contains($0) }
        if !kept.isEmpty { styles = kept }

        let leadHarmony = implied ?? brief.scheme
        let lead = leadHarmony.flatMap { PaletteStyle.treatment(for: $0) }.flatMap { styles.contains($0) ? $0 : nil }
        guard let basis = colors.first(where: { $0.C >= 0.03 }) ?? colors.first else {
            return (styles, lead, false)
        }
        let ranked = PaletteStyle.ranked(styles.filter { $0 != lead }, for: basis)
        return ((lead.map { [$0] } ?? []) + ranked, nil, true)
    }
}

/// The app's one deck, kept for the session only.
final class StyleDeckStore {
    static let shared = StyleDeckStore()

    private var deck = StyleDeck()
    private var rng = SystemRandomNumberGenerator()

    init() {}

    nonisolated deinit {}

    func next(for key: StyleDeckKey, candidates: [PaletteStyle], first: PaletteStyle? = nil, ordered: Bool = false) -> PaletteStyle? {
        deck.next(for: key, candidates: candidates, first: first, ordered: ordered, using: &rng)
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test ... -only-testing:PalettesTests/StyleDeckTests -only-testing:PalettesTests/PaletteStyleTests`
Expected: `** TEST SUCCEEDED **`. If a `testEachColorKindSuitsItsStyle` case fails, the failure message prints that color's L, C and h. Adjust the matching threshold in `fit(for:)` minimally so the color lands in its intended band, and say so in the report. Never change the expected style.

- [ ] **Step 6: Commit**

```bash
git add Palettes/Managers/StyleDeck.swift PalettesTests/StyleDeckTests.swift
git commit -m "Add StyleDeck: Auto ranks styles by fit, interface modes shuffle without repeats

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Palettes/Managers/PaletteStyle.swift Palettes/Managers/StyleDeck.swift PalettesTests/StyleDeckTests.swift
```

---

### Task 5: Recipe and generator wiring, including pinned modes

**Files:**
- Modify: `Palettes/Managers/PaletteRefinement.swift` (`GenerationRecipe`, `applying`)
- Modify: `Palettes/Managers/PaletteGenerator.swift` (`generate`: signature, step 1, step 2)
- Test: `PalettesTests/PaletteRefinementTests.swift`, `PalettesTests/PaletteGeneratorTests.swift` (append)

**Interfaces:**
- Consumes: `StyleDeckKey`, `StyleDeck.autoCandidates`, `StyleDeckStore` (Task 4); `PaletteStyle.deck(for:)` and `.treatment` (Task 1); `PaletteBuildRequest.style` (Task 2).
- Produces:
  - `GenerationRecipe.style: PaletteStyle?` (declared last, default `nil`)
  - `PaletteGenerator.generate(baseColors:size:vibe:scheme:pinnedStyle:existingNames:refining:nameVibe:namingTimeout:namer:deck:onRecipe:...)`, where `pinnedStyle: PaletteStyle? = nil` comes right after `scheme` and `deck: StyleDeckStore = .shared` right after `namer`

- [ ] **Step 1: Write the failing tests**

Append inside the test class in `PalettesTests/PaletteRefinementTests.swift`:

```swift
    func testRecipeChangesKeepTheStyleUnlessTheHarmonyChanges() {
        let recipe = GenerationRecipe(brief: .neutral, size: 6, scheme: .auto, seed: 1, style: .pastel)
        var darker = PaletteChange()
        darker.lightness = -1
        XCTAssertEqual(recipe.applying(darker, lockedCount: 0).style, .pastel)
        var triadic = PaletteChange()
        triadic.scheme = .triadic
        XCTAssertNil(recipe.applying(triadic, lockedCount: 0).style, "an explicit harmony replaces the style")
    }
```

Append inside `PaletteGeneratorTests`:

```swift
    // MARK: - Style decks

    private var fixedNamer: PaletteGenerator.Namer {
        { _, _, _ in PaletteGenerator.Naming(title: "Harbor", colorNames: [:]) }
    }

    @available(iOS 26.0, *)
    @MainActor
    private func styles(_ count: Int, base: [String], scheme: HarmonyScheme = .auto, pinned: PaletteStyle? = nil, store: StyleDeckStore) async throws -> [PaletteStyle] {
        var styles: [PaletteStyle] = []
        for _ in 0..<count {
            var recipe: GenerationRecipe?
            _ = try await PaletteGenerator.generate(
                baseColors: base.map { PaletteGenerator.BaseColor(hex: $0, name: "Base") },
                size: 8, vibe: nil, scheme: scheme, pinnedStyle: pinned,
                namer: fixedNamer, deck: store, onRecipe: { recipe = $0 }
            )
            styles.append(try XCTUnwrap(recipe?.style))
        }
        return styles
    }

    @available(iOS 26.0, *)
    @MainActor
    func testInterfaceModesStepThroughTheirStyles() async throws {
        let store = StyleDeckStore()
        for scheme in [HarmonyScheme.uiLight, .uiDark] {
            let deck = PaletteStyle.deck(for: scheme)
            let drawn = try await styles(deck.count, base: ["#3060A0"], scheme: scheme, store: store)
            XCTAssertEqual(Set(drawn), Set(deck), "\(scheme) must show every style before repeating")
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    func testAutoStartsWithTheBestFitAndStepsDown() async throws {
        let expected = StyleDeck.autoCandidates(anchors: ["#FFF2A0"], brief: .neutral).styles
        let drawn = try await styles(expected.count, base: ["#FFF2A0"], store: StyleDeckStore())
        XCTAssertEqual(drawn, expected)
        XCTAssertEqual(drawn.first, .pastel)
        XCTAssertFalse(drawn.contains { PaletteStyle.deck(for: .uiLight).contains($0) || PaletteStyle.deck(for: .uiDark).contains($0) },
                       "Auto never picks an interface style")
    }

    @available(iOS 26.0, *)
    @MainActor
    func testPinnedModeKeepsItsStyle() async throws {
        let drawn = try await styles(3, base: ["#3060A0"], pinned: .earthy, store: StyleDeckStore())
        XCTAssertEqual(drawn, [.earthy, .earthy, .earthy])
    }

    @available(iOS 26.0, *)
    @MainActor
    func testDescribedChangeKeepsTheStyle() async throws {
        let store = StyleDeckStore()
        var first: GenerationRecipe?
        _ = try await PaletteGenerator.generate(
            baseColors: [], size: 6, vibe: nil, scheme: .uiDark,
            namer: fixedNamer, deck: store, onRecipe: { first = $0 }
        )
        let recipe = try XCTUnwrap(first)
        XCTAssertNotNil(recipe.style)
        var changed: GenerationRecipe?
        _ = try await PaletteGenerator.generate(
            baseColors: [], size: nil, vibe: nil,
            refining: .init(recipe: recipe, change: "darker"),
            namer: fixedNamer, deck: store, onRecipe: { changed = $0 }
        )
        XCTAssertEqual(changed?.style, recipe.style)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteRefinementTests -only-testing:PalettesTests/PaletteGeneratorTests`
Expected: build FAILS with `extra argument 'style' in call` and `extra argument 'pinnedStyle' in call`.

- [ ] **Step 3: Add `GenerationRecipe.style`**

In `Palettes/Managers/PaletteRefinement.swift`, add after `var builtHue: Double?`:

```swift
    /// The design style it was built in (see `PaletteStyle`). A described
    /// change keeps it; nil for palettes built before styles existed.
    var style: PaletteStyle? = nil
```

In `applying(_:lockedCount:)`, replace

```swift
        if let scheme = change.scheme, !self.scheme.isUIMode {
            next.scheme = scheme
        }
```

with:

```swift
        if let scheme = change.scheme, !self.scheme.isUIMode {
            next.scheme = scheme
            // An explicit harmony replaces the style.
            next.style = nil
        }
```

- [ ] **Step 4: Wire styles into `PaletteGenerator.generate`**

Add to the signature, right after `scheme: HarmonyScheme = .auto,`:

```swift
        pinnedStyle: PaletteStyle? = nil,
```

and right after `namer: Namer? = nil,`:

```swift
        deck: StyleDeckStore = .shared,
```

Add these to the doc comment after the `namer` line:

```swift
    /// - Parameter pinnedStyle: an Auto style the user picked as the mode
    ///   (with `scheme` `.auto`). Every fresh run uses it; no deck draw.
    /// - Parameter deck: hands out the next design style for a fresh run, so
    ///   generating again from the same inputs looks different (tests inject one).
```

In the refinement branch, replace

```swift
                if let suggested = brief.scheme, !recipe.scheme.isUIMode { recipe.scheme = suggested }
```

with:

```swift
                if let suggested = brief.scheme, !recipe.scheme.isUIMode {
                    recipe.scheme = suggested
                    recipe.style = nil
                }
```

In the fresh branch (`} else {`), replace everything from `let brief = trimmedVibe.isEmpty ...` through the closing `)` of `recipe = GenerationRecipe(...)` with:

```swift
            let brief = trimmedVibe.isEmpty ? PaletteBrief.neutral : await makeBrief(vibe: trimmedVibe)
            // A picked style is used as is. Otherwise each fresh run from the
            // same colors, mode and vibe takes the next style in the mode's
            // deck: Auto walks the styles best-suited to the colors first,
            // interface modes shuffle.
            assert(pinnedStyle == nil || (pinnedStyle?.treatment != nil && scheme == .auto), "a pinned style is an Auto style")
            let deckKey = StyleDeckKey(anchors: locked.map(\.hex), scheme: scheme, vibe: trimmedVibe)
            let style: PaletteStyle?
            if let pinnedStyle {
                style = pinnedStyle
            } else if scheme == .auto {
                let auto = StyleDeck.autoCandidates(anchors: locked.map(\.hex), brief: brief)
                style = deck.next(for: deckKey, candidates: auto.styles, first: auto.first, ordered: auto.ordered)
            } else {
                style = deck.next(for: deckKey, candidates: PaletteStyle.deck(for: scheme))
            }
            // The user's mode always wins. Unstyled Auto follows the brief's
            // harmony, unless two or more chosen colors already imply one;
            // styled Auto leaves the harmony to its style.
            var resolvedScheme = scheme
            if style == nil, scheme == .auto, locked.count < 2, let suggested = brief.scheme,
               !(suggested == .monochromatic && brief.secondaryHue != nil) {
                resolvedScheme = suggested
            }
            recipe = GenerationRecipe(
                brief: brief,
                size: PaletteBrief.resolvedSize(requested: size, locked: locked.count, suggested: brief.suggestedSize, interface: resolvedScheme.isUIMode),
                scheme: resolvedScheme,
                seed: UInt64.random(in: .min ... .max),
                style: style
            )
```

In step 2 (`let built = PaletteBuilder.build(PaletteBuildRequest(`), add `style: recipe.style` after `seed: recipe.seed`:

```swift
            seed: recipe.seed,
            style: recipe.style
        ))
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test ... -only-testing:PalettesTests/PaletteRefinementTests -only-testing:PalettesTests/PaletteGeneratorTests`
Expected: `** TEST SUCCEEDED **`, including every pre-existing generator test.

- [ ] **Step 6: Commit**

```bash
git add Palettes/Managers/PaletteRefinement.swift Palettes/Managers/PaletteGenerator.swift PalettesTests/PaletteRefinementTests.swift PalettesTests/PaletteGeneratorTests.swift
git commit -m "Generate draws the next style per request (Auto by fit), honors a pinned style, and keeps it on changes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Palettes/Managers/PaletteRefinement.swift Palettes/Managers/PaletteGenerator.swift PalettesTests/PaletteRefinementTests.swift PalettesTests/PaletteGeneratorTests.swift
```

---

### Task 6: Mode menu with every style, result caption, full verification

> Amended 2026-11-26 (user request). The Mode menu offers Auto, the eight color styles (each one pinnable) and UI Light / UI Dark. Auto never picks an interface mode.

**Files:**
- Create: `Palettes/Models/GenerationMode.swift`
- Test: `PalettesTests/GenerationModeTests.swift`
- Modify: `Palettes/Views/Color/GenerateView.swift` (`scheme` state → `mode`, the Mode menu, `resetForm`, `performGeneration`, the `GenerationResultView(` call)
- Modify: `Palettes/Views/Components/Generation/GenerationExperienceView.swift` (`GenerationResultView`)
- Modify: `plans/README.md`

**Interfaces:**
- Consumes: `PaletteStyle` (Task 1); `GenerationRecipe.style` and `generate(... scheme:pinnedStyle: ...)` (Task 5).
- Produces:
  - `enum GenerationMode: Hashable, Identifiable` with cases `auto`, `style(PaletteStyle)`, `uiLight`, `uiDark`; `displayName`, `scheme`, `pinnedStyle`, `static let colorStyles`, and `static let interfaceModes`
  - `GenerationResultView.styleName: String? = nil`

- [ ] **Step 1: Write the failing test**

Create `PalettesTests/GenerationModeTests.swift`:

```swift
//
//  GenerationModeTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class GenerationModeTests: XCTestCase {

    func testColorStylesAreTheEightAutoStyles() {
        XCTAssertEqual(GenerationMode.colorStyles.map(\.pinnedStyle), PaletteStyle.deck(for: .auto).map { Optional($0) })
        for mode in GenerationMode.colorStyles {
            XCTAssertEqual(mode.scheme, .auto, "a pinned style builds through Auto")
            XCTAssertNotNil(mode.pinnedStyle?.treatment)
        }
    }

    func testAutoAndInterfaceModesPinNothing() {
        XCTAssertEqual(GenerationMode.auto.scheme, .auto)
        XCTAssertNil(GenerationMode.auto.pinnedStyle)
        XCTAssertEqual(GenerationMode.interfaceModes, [.uiLight, .uiDark])
        XCTAssertEqual(GenerationMode.uiLight.scheme, .uiLight)
        XCTAssertEqual(GenerationMode.uiDark.scheme, .uiDark)
        XCTAssertNil(GenerationMode.uiDark.pinnedStyle)
    }

    func testNamesAndIDsAreUnique() {
        let all = [GenerationMode.auto] + GenerationMode.colorStyles + GenerationMode.interfaceModes
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(Set(all.map(\.displayName)).count, all.count)
        XCTAssertEqual(GenerationMode.style(.pastel).displayName, "Pastel")
        XCTAssertEqual(GenerationMode.uiLight.displayName, "UI Light")
    }
}
```

Run: `xcodebuild test ... -only-testing:PalettesTests/GenerationModeTests`
Expected: build FAILS with `cannot find 'GenerationMode' in scope`.

- [ ] **Step 2: Write `GenerationMode`**

Create `Palettes/Models/GenerationMode.swift`:

```swift
//
//  GenerationMode.swift
//  Palettes
//
//  What the Generate tab's Mode menu offers: Auto, which picks the color
//  style that best suits the chosen colors (never an interface mode); one
//  color style, pinned; or an interface mode, which steps through its own
//  styles on each generation.
//

import Foundation

enum GenerationMode: Hashable, Identifiable {
    case auto
    case style(PaletteStyle)
    case uiLight
    case uiDark

    /// The eight color styles, in menu order.
    static let colorStyles: [GenerationMode] = PaletteStyle.deck(for: .auto).map { .style($0) }
    static let interfaceModes: [GenerationMode] = [.uiLight, .uiDark]

    var id: String {
        switch self {
        case .auto: return "auto"
        case .style(let style): return "style.\(style.rawValue)"
        case .uiLight: return "uiLight"
        case .uiDark: return "uiDark"
        }
    }

    var displayName: String {
        switch self {
        case .auto: return HarmonyScheme.auto.displayName
        case .style(let style): return style.displayName
        case .uiLight: return HarmonyScheme.uiLight.displayName
        case .uiDark: return HarmonyScheme.uiDark.displayName
        }
    }

    /// The scheme the generator builds with. A pinned color style builds through Auto.
    var scheme: HarmonyScheme {
        switch self {
        case .auto, .style: return .auto
        case .uiLight: return .uiLight
        case .uiDark: return .uiDark
        }
    }

    /// The color style the user picked, if any.
    var pinnedStyle: PaletteStyle? {
        if case .style(let style) = self { return style }
        return nil
    }
}
```

Run the same test. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Use it in the Generate tab**

In `Palettes/Views/Color/GenerateView.swift`:

a) Replace `@State private var scheme: HarmonyScheme = .auto` with `@State private var mode: GenerationMode = .auto`.

b) Delete the `modeOptions` property (and its `/// Modes offered in the menu.` comment).

c) Replace the whole `Menu { ... } label: { ... }` of the Mode option (inside `if canChooseMode {`) with:

```swift
                    Menu {
                        modeButton(.auto)
                        Section("Color Styles") {
                            ForEach(GenerationMode.colorStyles) { modeButton($0) }
                        }
                        Section("Interface") {
                            ForEach(GenerationMode.interfaceModes) { modeButton($0) }
                        }
                    } label: {
                        generationOptionLabel(
                            title: "Mode",
                            value: mode.displayName,
                            systemImage: "paintpalette"
                        )
                    }
```

(Keep the `.accessibilityLabel("Palette mode")` and `.transition(...)` modifiers that follow it.)

d) Add this helper next to `generationOptionLabel` (same type, same access level):

```swift
    /// One Mode menu entry, checked when it's the current mode.
    private func modeButton(_ option: GenerationMode) -> some View {
        Button {
            mode = option
        } label: {
            if option == mode {
                Label(option.displayName, systemImage: "checkmark")
            } else {
                Text(option.displayName)
            }
        }
    }
```

e) In `resetForm()`, replace `scheme = .auto` with `mode = .auto`.

f) In `performGeneration`, replace `scheme: canChooseMode ? scheme : .auto,` with:

```swift
            scheme: canChooseMode ? mode.scheme : .auto,
            pinnedStyle: canChooseMode ? mode.pinnedStyle : nil,
```

g) In the `GenerationResultView(` call, replace `screenMargin: screenMargin` with:

```swift
                    screenMargin: screenMargin,
                    styleName: resultRecipe?.style?.displayName
```

Search the file for any other `scheme` reference to the removed state (`grep -n "scheme" Palettes/Views/Color/GenerateView.swift`). The only remaining hits should be the `scheme:` argument label from (f).

- [ ] **Step 4: Add the caption**

In `GenerationResultView` (`Palettes/Views/Components/Generation/GenerationExperienceView.swift`), add after `var screenMargin: CGFloat?`:

```swift
    /// The design style the palette follows, shown under its name.
    var styleName: String? = nil
```

Rename the existing `private var nameField: some View` to `private var editableName: some View`, and update its doc comment's first line to `/// The generated name in the generated gradient.` (keep the rest). Then add a new `nameField` directly above it:

```swift
    /// The name, and under it the style the palette follows, so generating
    /// again visibly lands on a different look.
    private var nameField: some View {
        VStack(spacing: 2) {
            editableName
            if let styleName {
                Text(styleName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Style, \(styleName)")
            }
        }
    }
```

- [ ] **Step 5: Build and run the whole suite**

Run: `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "$DEST" -derivedDataPath /tmp/palettes-dd 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "$DEST" -derivedDataPath /tmp/palettes-dd 2>&1 | grep -E "Executed|error:|failed" | tail -20`
Expected: `** TEST SUCCEEDED **`, 0 failures.

- [ ] **Step 6: Check the deinit rule (CLAUDE.md)**

```bash
nm -a "$(find /tmp/palettes-dd -name Palettes.debug.dylib -path '*iphonesimulator*' | head -1)" | xcrun swift-demangle | grep __isolated_deallocating_deinit
```

Expected: the only hit is `ResourceBundleClass`. Nothing for `StyleDeckStore`.

- [ ] **Step 7: Check on the simulator**

Launch the app on the booted simulator (iOS Simulator tool: `attach`, then `launch` with `/tmp/palettes-dd/Build/Products/Debug-iphonesimulator/Palettes.app`). In the Generate tab, select one saved color, then:
1. Open the Mode menu and screenshot it. Expect Auto, a "Color Styles" section with eight styles, and an "Interface" section with UI Light / UI Dark.
2. **UI Light:** Generate, then Regenerate 5 times, taking a screenshot each time. Expect six different looks, with captions covering all six UI Light style names.
3. **UI Dark:** repeat. OLED Black's background swatch must be pure black.
4. **Auto:** choose a pale color, Generate, then Regenerate once. The first caption should be Pastel, the second a different color style, and never a UI style.
5. **Earthy (pinned):** Generate, then Regenerate twice. All three captions say Earthy.
6. On a result, describe the change "darker". The caption stays the same.

Record what you saw (with screenshots) in the task report. Anything off is a defect to fix before finishing.

- [ ] **Step 8: Update the plans index and the knowledge graph**

In `plans/README.md`, add this row to the table after the 020 row:

```markdown
| 022 | Palette style decks: 12 interface styles cycle on regenerate; 8 color styles in the Mode menu (pinnable); Auto picks the best-suited color style and steps down on regenerate; style caption on the result | P1 | L | 013 | DONE (feature/palette-style-decks) |
```

Run: `graphify update .`. Don't commit `graphify-out/` unless it's already tracked: check with `git ls-files graphify-out | head -1`.

- [ ] **Step 9: Commit**

```bash
git add Palettes/Models/GenerationMode.swift PalettesTests/GenerationModeTests.swift
git commit -m "Mode menu offers every color style; Auto picks by fit; style caption on results

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- Palettes/Models/GenerationMode.swift PalettesTests/GenerationModeTests.swift Palettes/Views/Color/GenerateView.swift Palettes/Views/Components/Generation/GenerationExperienceView.swift plans/README.md
```

---

## Notes for the executor

- **Small spec deviation, intentional:** `autoCandidates` drops Monochrome + Pop when the vibe names two colors and the user picked none. This keeps today's rule that "a vibe that names two colors is not a one-hue palette".
- **If a contrast test fails** in Task 2, adjust that style's role table, not the threshold, and mention the changed value in the commit message.
- **Don't re-record the golden hash** in Tasks 2–6. A golden failure means an unstyled code path changed.
- **Stop and report** if `GenerateView`'s `GenerationResultView(` call or `PaletteGenerator.generate`'s fresh-run branch no longer matches the code shown here (the branch has moved on), instead of guessing.
