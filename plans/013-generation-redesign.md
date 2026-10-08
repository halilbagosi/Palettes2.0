# Generation Redesign Implementation Plan (013)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generated palettes match their mode, keep the user's color in charge, look clean instead of muddy or garish, and get color names and titles that fit their swatches.

**Architecture:** The language model stops choosing color values. On device it does two narrow jobs: it reads a vibe into a structured brief (a main color word, lightness, saturation and harmony enums), and it names colors from plain descriptions that code writes from each swatch. A new deterministic `PaletteBuilder` makes every color in OKLCH with a 60/30/10 structure: tones of the main color(s), the scheme's other hue(s), one accent, and tinted neutrals. Names and titles are checked against their swatches, with the color dictionary as the fallback. The old HSB planner (`ColorHarmony.plan`, `fillToTarget`, `repairViolations`) is deleted, along with its two known flaky tests.

**Tech Stack:** Swift, SwiftUI, FoundationModels (iOS 26, `@Generable` structs and enums), XCTest. The pure parts (`OKLCH`, `ColorVocabulary`, `PaletteBuilder`, `PaletteBrief`) import Foundation only.

## Background

The audit of 2026-10-07 (`advisor-plans/generation-audit.html`) found:

1. **Modes:** every generated slot went to the scheme's *other* hue, so the user's color appeared once. Palettes read as "a blue swatch next to a yellow palette".
2. **HSB math:** brightness ladders in HSB turn muddy in blues and garish in yellows.
3. **Auto:** a single color at size 5+ always resolved to split-complementary.
4. **Vibe + Auto:** the model picked hex values itself, unchecked.
5. **Names:**
   - The model named colors from hex codes alone, and its names were matched to colors by position.
   - The dictionary produced contradictions such as "Vivid Black", "Pale Space Blue" (on a dark color), "Dark Turquoise" (on a light teal), "Steel" (on a teal) and "Charcoal" (on a deep teal).
6. **Titles:** titles came from the most saturated color (often the accent) plus filler words ("Measured Honey Kiln").
7. **Flaky tests:** `testMultipleSelectedBasesReceiveBalancedMonochromaticTones` fails about 1 run in 7, and `testMonochromaticShipsASingleHue` fails rarely. Both come from the HSB planner.

**User decisions (2026-10-07):**
- Keep the UI Light and UI Dark modes.
- Allow choosing a mode together with a vibe.
- Generation sizes stay even: 2/4/6 (free) and 8/10/12 (Pro). The paywall itself is out of scope.

**Verification already done:** every file in Tasks 1–4 was prototyped and swept in a scratch package before this plan was written, and every test in those tasks passed.
- **Sweep:** 5 schemes × 7 anchor sets × 9 sizes × 3 tones × 200 seeds.
- **Size:** exact for every request, with no repeated color.
- **Hue fidelity:** within 3.9° of the scheme's hues (OKLCH, chroma ≥ 0.04).
- **Distinctness:** every pair is at least CIEDE2000 6 apart, except monochromatic palettes of 10 or more colors. Palettes of 5 or fewer clear 12.
- **Balance:** two chosen colors split the tones evenly in all 2,000 seeds tried.
- **Names:** none of 16,800 dictionary names contradict their swatch with the Task 3 fixes, compared with 933 before.

## Global Constraints

- **Deployment target:** iOS 17.0. FoundationModels APIs stay behind `@available(iOS 26.0, *)` (`PaletteGenerator` is already gated). Do not raise the deployment target.
- **New files:** Swift files are auto-included by synchronized groups. Never edit `Palettes.xcodeproj/project.pbxproj`.
- **Concurrency settings:** the app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and Swift 5 language mode. Write plain `enum`/`struct` helpers like the existing `PaletteNamer` and `ColorNamer`, with no `nonisolated` or `Sendable` annotations unless the compiler asks for them.
- **Pure helpers:** `OKLCH.swift`, `ColorVocabulary.swift`, `PaletteBuilder.swift` and `PaletteBrief.swift` import Foundation only: no UIKit, SwiftUI or FoundationModels.
- **No model color values:** no color value chosen by the language model may ship. Every shipped hex comes from the user's colors or from `PaletteBuilder`.
- **Simulator:** the Simulator path never calls the model (`#if targetEnvironment(simulator)`).
- **Logging:** logs record error type names only, never prompt or model content.
- **Parallel arrays:** `PaletteViewModel`'s `colors`, `hexCodes`, `colorNames` and `colorRoles` stay the same length and index-aligned (CLAUDE.md caveat).
- **Files to leave alone:** do not touch `Palettes/Views/Color/ColorsView.swift` or `Palettes/Views/Components/Selection/MorphingCardGrid.swift`. Only Task 7 touches `Palettes/Views/Color/GenerateView.swift`.
- **Build and test:** find the simulator with `xcrun simctl list devices available` and use `-destination "id=<UDID>"`. The build must have zero new warnings.
  - Build: `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -quiet`
  - Test one class: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/<ClassName>`
- **Branch:** `feature/generation-redesign`, created from `dev` once [halilbagosi/Palettes2.0#2](https://github.com/halilbagosi/Palettes2.0/pull/2) (plan 012) is merged, or from `feature/app-store-readiness` if it is not merged yet.
- **Commits:** end every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Map

| File | Change | Responsibility |
|---|---|---|
| `Palettes/Utilities/OKLCH.swift` | Create (Task 1) | OKLCH conversions, sRGB gamut mapping, hex |
| `Palettes/Utilities/ColorVocabulary.swift` | Create (Task 1) | Hue families and color words, swatch descriptions, name and title plausibility |
| `Palettes/Managers/PaletteBuilder.swift` | Create (Task 2) | Deterministic palette construction (`PaletteTone`, `PaletteBuildRequest`, `BuiltPalette`, `SplitMix64`) |
| `Palettes/Utilities/HEXParser.swift` | Modify (Task 3, 6) | `ColorNamer`: names agree with the swatch; `hex(forName:)` |
| `Palettes/Managers/PaletteBrief.swift` | Create (Task 4) | Vibe → hue, tone, harmony (heuristic and model mapping) |
| `Palettes/Managers/PaletteNamer.swift` | Modify (Task 5) | Title from the main color, no filler, plausibility check |
| `Palettes/Managers/PaletteGenerator.swift` | Rewrite (Task 6) | Brief → build → names pipeline |
| `Palettes/Managers/ColorHarmony.swift` | Shrink (Task 6) | `HarmonyScheme` enum only |
| `Palettes/Managers/PaletteValidation.swift` | Delete (Task 6) | Replaced by the builder's distinctness floors |
| `Palettes/Intents/GeneratePaletteIntent.swift` | Modify (Task 7) | Even sizes 2–12 |
| `Palettes/Views/Color/GenerateView.swift` | Modify (Task 7) | Mode menu available with a vibe alone |
| Tests | Create and modify | See each task |

---

### Task 1: OKLCH color space and color vocabulary

**Files:**
- Create: `Palettes/Utilities/OKLCH.swift`
- Create: `Palettes/Utilities/ColorVocabulary.swift`
- Test: `PalettesTests/OKLCHTests.swift`, `PalettesTests/ColorVocabularyTests.swift`

**Interfaces:**
- Produces:
  - `struct OKLCH: Equatable { var L, C, h: Double }` with:
    - `init(L:C:h:)`, `init?(hex:)`, `init(r:g:b:)`
    - `static func wrap(_:) -> Double`, `static func hueDistance(_:_:) -> Double`
    - `func linearSRGB()`, `var isInSRGBGamut: Bool`, `func gamutMapped() -> OKLCH`, `var hex: String`
  - `enum ColorVocabulary` with:
    - `enum Family: Int, CaseIterable` (`.pink … .purple`, with `name` and `center`)
    - `static func family(forHue:) -> Family`, `static func ringDistance(_:_:) -> Int`
    - Word lists: `static let hueWords: [String: Double]`, `moodHues`, `greyWords`, `whiteWords`, `darkWords`, `lightWords`, `vividWords`, `darkToneWords`, `lightToneWords`, `mutedToneWords`, `vividToneWords`
    - `static func tokens(_:) -> [String]`, `static func describe(hex:) -> String`
    - `static func isPlausible(name:forHex:) -> Bool`, `static func isPlausible(name:for: OKLCH) -> Bool`, `static func isPlausibleTitle(_:forHexes:) -> Bool`

- [ ] **Step 1: Write the failing tests**

Create `PalettesTests/OKLCHTests.swift`:

```swift
//
//  OKLCHTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class OKLCHTests: XCTestCase {

    /// Reference values for sRGB red, from Björn Ottosson's OKLab definition.
    func testRedMatchesPublishedOKLCHValues() {
        let red = OKLCH(hex: "#FF0000")!
        XCTAssertEqual(red.L, 0.6280, accuracy: 0.001)
        XCTAssertEqual(red.C, 0.2577, accuracy: 0.001)
        XCTAssertEqual(red.h, 29.23, accuracy: 0.1)
    }

    func testWhiteAndBlackHaveNoChroma() {
        let white = OKLCH(hex: "#FFFFFF")!
        XCTAssertEqual(white.L, 1, accuracy: 0.0001)
        XCTAssertEqual(white.C, 0, accuracy: 0.0001)
        let black = OKLCH(hex: "#000000")!
        XCTAssertEqual(black.L, 0, accuracy: 0.0001)
        XCTAssertEqual(black.C, 0, accuracy: 0.0001)
    }

    func testHexRoundTripsExactly() {
        for hex in ["#3366CC", "#E2683C", "#3E8E5E", "#D9B44A", "#000000", "#FFFFFF", "#7F7F7F", "#010203"] {
            XCTAssertEqual(OKLCH(hex: hex)?.hex, hex)
        }
    }

    func testParsesLowercaseAndRejectsMalformedHex() {
        XCTAssertEqual(OKLCH(hex: "3366cc")?.hex, "#3366CC")
        XCTAssertNil(OKLCH(hex: "#12345"))
        XCTAssertNil(OKLCH(hex: "nothex"))
    }

    /// Clipping a too-saturated color must keep its lightness and hue, so a
    /// palette's lightness ladder and hue family survive the gamut.
    func testGamutMappingKeepsLightnessAndHue() {
        let wild = OKLCH(L: 0.7, C: 0.35, h: 145)
        XCTAssertFalse(wild.isInSRGBGamut)
        let mapped = wild.gamutMapped()
        XCTAssertTrue(mapped.isInSRGBGamut)
        XCTAssertEqual(mapped.L, 0.7, accuracy: 1e-9)
        XCTAssertEqual(mapped.h, 145, accuracy: 1e-9)
        XCTAssertLessThan(mapped.C, 0.35)
        XCTAssertGreaterThan(mapped.C, 0.15)
    }

    func testHueDistanceWrapsAroundTheCircle() {
        XCTAssertEqual(OKLCH.hueDistance(350, 10), 20, accuracy: 1e-9)
        XCTAssertEqual(OKLCH.hueDistance(0, 180), 180, accuracy: 1e-9)
        XCTAssertEqual(OKLCH.wrap(-30), 330, accuracy: 1e-9)
    }
}
```

Create `PalettesTests/ColorVocabularyTests.swift`:

```swift
//
//  ColorVocabularyTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ColorVocabularyTests: XCTestCase {

    func testReferenceColorsLandInTheirFamilies() {
        let expected: [(String, ColorVocabulary.Family)] = [
            ("#FF0000", .red), ("#FFA500", .orange), ("#FFFF00", .yellow), ("#00FF00", .green),
            ("#008080", .teal), ("#0000FF", .blue), ("#800080", .purple), ("#FFC0CB", .pink),
        ]
        for (hex, family) in expected {
            XCTAssertEqual(ColorVocabulary.family(forHue: OKLCH(hex: hex)!.h), family, hex)
        }
    }

    func testRingDistanceWraps() {
        XCTAssertEqual(ColorVocabulary.ringDistance(.pink, .purple), 1)
        XCTAssertEqual(ColorVocabulary.ringDistance(.red, .teal), 4)
        XCTAssertEqual(ColorVocabulary.ringDistance(.blue, .blue), 0)
    }

    func testDescriptionsComeFromTheSwatch() {
        XCTAssertEqual(ColorVocabulary.describe(hex: "#2F6BD8"), "medium, vivid blue")
        XCTAssertEqual(ColorVocabulary.describe(hex: "#808080"), "medium neutral grey")
        XCTAssertEqual(ColorVocabulary.describe(hex: "#021741"), "very dark, moderate blue")
    }

    func testPlausibleNamesPass() {
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Ocean Blue", forHex: "#2F6BD8"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Terracotta", forHex: "#E2683C"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Blue Grey", forHex: "#6B7F8E"))
    }

    func testNamesThatContradictTheSwatchFail() {
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Blue Lagoon", forHex: "#E2683C"), "blue word on an orange")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Midnight Ink", forHex: "#F1F5FD"), "dark words on a near-white")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Pale Mist", forHex: "#021741"), "light words on a near-black")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Charcoal", forHex: "#2C7284"), "grey word on a saturated teal")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Vivid Coral", forHex: "#808080"), "a hue on a true grey")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Color 7", forHex: "#808080"), "digits")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "  ", forHex: "#808080"), "empty")
    }

    func testTitleColorWordsMustMatchThePalette() {
        let blues = ["#2E5F8A", "#3E7FB0", "#1E3F5A"]
        XCTAssertFalse(ColorVocabulary.isPlausibleTitle("Crimson Tide", forHexes: blues))
        XCTAssertTrue(ColorVocabulary.isPlausibleTitle("Blue Hour", forHexes: blues))
        XCTAssertTrue(ColorVocabulary.isPlausibleTitle("Harbor Dusk", forHexes: blues), "no color words")
    }
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/OKLCHTests -only-testing:PalettesTests/ColorVocabularyTests`
Expected: build failure, `cannot find 'OKLCH' in scope`.

- [ ] **Step 3: Create `Palettes/Utilities/OKLCH.swift`**

```swift
//
//  OKLCH.swift
//  Palettes
//
//  OKLCH (Björn Ottosson's OKLab in polar form). Equal steps of lightness
//  and hue in OKLCH look equal to the eye, which HSB steps do not: an HSB
//  brightness ladder turns muddy in blues and garish in yellows. The palette
//  builder works in this space. Pure math — safe to unit test.
//

import Foundation

struct OKLCH: Equatable {
    /// Perceptual lightness, 0 (black) ... 1 (white).
    var L: Double
    /// Chroma, 0 (grey) ... about 0.32 for the most saturated sRGB colors.
    var C: Double
    /// Hue angle in degrees, 0 ..< 360.
    var h: Double

    init(L: Double, C: Double, h: Double) {
        self.L = min(1, max(0, L))
        self.C = max(0, C)
        self.h = OKLCH.wrap(h)
    }

    // MARK: - Hue helpers

    static func wrap(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    /// Shortest angle between two hues, 0 ... 180.
    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(wrap(a) - wrap(b))
        return min(d, 360 - d)
    }

    // MARK: - sRGB → OKLCH

    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    /// Gamma-encoded sRGB components, each 0...1.
    init(r: Double, g: Double, b: Double) {
        let lr = OKLCH.linearize(r), lg = OKLCH.linearize(g), lb = OKLCH.linearize(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        let okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        let chroma = (okA * okA + okB * okB).squareRoot()
        // Hue is meaningless for a grey; 0 keeps it deterministic.
        let hue = chroma < 1e-6 ? 0 : atan2(okB, okA) * 180 / .pi
        self.init(L: okL, C: chroma, h: hue)
    }

    // MARK: - OKLCH → sRGB

    /// Linear-light sRGB, unclamped. A component outside 0...1 means the
    /// color is outside the sRGB gamut.
    func linearSRGB() -> (r: Double, g: Double, b: Double) {
        let radians = h * .pi / 180
        let a = C * cos(radians)
        let b = C * sin(radians)
        let l = OKLCH.cube(L + 0.3963377774 * a + 0.2158037573 * b)
        let m = OKLCH.cube(L - 0.1055613458 * a - 0.0638541728 * b)
        let s = OKLCH.cube(L - 0.0894841775 * a - 1.2914855480 * b)
        return (
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    var isInSRGBGamut: Bool {
        let c = linearSRGB()
        let range = -0.0001...1.0001
        return range.contains(c.r) && range.contains(c.g) && range.contains(c.b)
    }

    /// The same lightness and hue with chroma reduced just enough to fit in
    /// sRGB. Holding L and h fixed keeps a clipped color on its hue and its
    /// place in the lightness ladder; RGB clamping would shift both.
    func gamutMapped() -> OKLCH {
        if isInSRGBGamut { return self }
        var low = 0.0
        var high = C
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if OKLCH(L: L, C: mid, h: h).isInSRGBGamut { low = mid } else { high = mid }
        }
        return OKLCH(L: L, C: low, h: h)
    }

    /// "#RRGGBB" of the gamut-mapped color.
    var hex: String {
        let c = gamutMapped().linearSRGB()
        func byte(_ linear: Double) -> Int {
            Int((OKLCH.gammaEncode(min(1, max(0, linear))) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", byte(c.r), byte(c.g), byte(c.b))
    }

    // MARK: - Transfer functions

    private static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func gammaEncode(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private static func cube(_ x: Double) -> Double { x * x * x }
}
```

- [ ] **Step 4: Create `Palettes/Utilities/ColorVocabulary.swift`**

```swift
//
//  ColorVocabulary.swift
//  Palettes
//
//  The words people use for colors, tied to OKLCH hue families. One source
//  for three jobs: reading a vibe into a hue and tone (PaletteBrief),
//  writing the plain descriptions the model names colors from, and
//  rejecting names that contradict their swatch ("Blue" on an orange,
//  "Dark" on a near-white, "Charcoal" on a saturated teal).
//

import Foundation

enum ColorVocabulary {

    // MARK: - Hue families

    /// Eight coarse families around the OKLCH hue circle, in ring order.
    enum Family: Int, CaseIterable {
        case pink, red, orange, yellow, green, teal, blue, purple

        var name: String {
            switch self {
            case .pink: return "pink"
            case .red: return "red"
            case .orange: return "orange"
            case .yellow: return "yellow"
            case .green: return "green"
            case .teal: return "teal"
            case .blue: return "blue"
            case .purple: return "purple"
            }
        }

        /// OKLCH hue at the family's center. A hue belongs to the nearest center.
        var center: Double {
            switch self {
            case .pink: return 0
            case .red: return 27
            case .orange: return 58
            case .yellow: return 100
            case .green: return 145
            case .teal: return 185
            case .blue: return 250
            case .purple: return 310
            }
        }
    }

    static func family(forHue hue: Double) -> Family {
        Family.allCases.min { OKLCH.hueDistance(hue, $0.center) < OKLCH.hueDistance(hue, $1.center) }!
    }

    /// Steps between two families around the ring (0 ... 4).
    static func ringDistance(_ a: Family, _ b: Family) -> Int {
        let d = abs(a.rawValue - b.rawValue)
        return min(d, Family.allCases.count - d)
    }

    // MARK: - Word lists

    /// Words that name a hue, mapped to an OKLCH hue in degrees.
    static let hueWords: [String: Double] = [
        "red": 29, "crimson": 20, "scarlet": 30, "ruby": 15, "cherry": 20, "garnet": 18,
        "wine": 10, "burgundy": 12, "maroon": 22, "brick": 35, "rust": 45, "terracotta": 45,
        "coral": 38, "salmon": 35, "vermilion": 35,
        "orange": 60, "tangerine": 55, "apricot": 65, "peach": 60, "copper": 55, "bronze": 70,
        "amber": 75, "caramel": 70, "brown": 55, "chocolate": 45, "coffee": 55, "mocha": 50,
        "tan": 75, "ochre": 85, "cinnamon": 50,
        "yellow": 105, "gold": 95, "golden": 95, "honey": 85, "mustard": 100, "lemon": 108,
        "butter": 100, "saffron": 85, "citron": 110, "olive": 115,
        "lime": 135, "green": 145, "emerald": 160, "jade": 160, "mint": 165, "sage": 140,
        "moss": 125, "pine": 155, "fern": 140, "chartreuse": 125, "pistachio": 130,
        "teal": 190, "cyan": 200, "aqua": 195, "turquoise": 185, "lagoon": 195, "seafoam": 175,
        "blue": 260, "navy": 262, "cobalt": 262, "azure": 240, "sky": 235, "sapphire": 262,
        "denim": 255, "cerulean": 240, "indigo": 275, "ultramarine": 268, "cornflower": 265,
        "violet": 295, "purple": 310, "lavender": 300, "lilac": 310, "plum": 330,
        "amethyst": 305, "mauve": 330, "orchid": 330, "grape": 310, "periwinkle": 285,
        "magenta": 330, "fuchsia": 335, "pink": 0, "rose": 5, "blush": 10, "flamingo": 5,
        "raspberry": 355,
    ]

    /// Places and moods that imply a hue. Only used to read a vibe — a
    /// color named "Ocean Mist" or "Autumn Dusk" can be any color.
    static let moodHues: [String: Double] = [
        "sunset": 45, "sunrise": 55, "autumn": 55, "fall": 55, "desert": 75, "beach": 85,
        "ocean": 240, "sea": 230, "forest": 150, "jungle": 150, "spring": 140, "meadow": 140,
        "winter": 240, "ice": 220, "arctic": 220, "night": 265, "midnight": 265,
        "fire": 35, "lava": 30, "candy": 0, "berry": 350, "earth": 60, "earthy": 60,
        "clay": 45, "sand": 80, "sandy": 80, "harbor": 240, "rain": 245, "storm": 255,
        "leaf": 140, "leaves": 140, "citrus": 100, "tropical": 160,
    ]

    /// Words that name a grey rather than a hue.
    static let greyWords: Set<String> = [
        "grey", "gray", "black", "charcoal", "graphite", "slate", "ash", "smoke", "silver",
        "ink", "onyx", "jet", "stone", "fog", "pewter", "steel", "concrete", "cement",
    ]

    /// Words that name an off-white.
    static let whiteWords: Set<String> = ["white", "ivory", "cream", "linen", "bone", "pearl", "snow", "chalk"]

    static let darkWords: Set<String> = ["dark", "deep", "midnight", "night", "ink", "shadow", "dusk", "abyss", "noir"]
    static let lightWords: Set<String> = ["pale", "light", "pastel", "ice", "icy", "mist", "misty", "cream", "snow", "frost", "frosted", "chalk"]
    static let vividWords: Set<String> = ["vivid", "neon", "electric", "bright", "hot", "radiant", "fluorescent"]

    // Tone words for reading a vibe.
    static let darkToneWords: Set<String> = ["dark", "moody", "midnight", "night", "noir", "gothic", "deep", "shadow", "shadowy", "dusk", "nocturnal"]
    static let lightToneWords: Set<String> = ["light", "airy", "pastel", "soft", "morning", "fresh", "breezy", "cloud", "cloudy", "delicate"]
    static let mutedToneWords: Set<String> = ["muted", "dusty", "vintage", "faded", "calm", "earthy", "rustic", "pastel", "soft", "subtle", "natural", "cozy", "washed"]
    static let vividToneWords: Set<String> = ["vivid", "neon", "bold", "electric", "vibrant", "bright", "saturated", "punchy", "tropical", "pop", "arcade"]

    /// Lowercased letter-only words.
    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - Describing a color

    /// The plain description the model names a color from, e.g.
    /// "dark, muted teal". Written by code from the actual swatch, so the
    /// model never has to guess a color from its hex code.
    static func describe(hex: String) -> String {
        guard let color = OKLCH(hex: hex) else { return "unknown" }
        let lightness: String
        switch color.L {
        case ..<0.32: lightness = "very dark"
        case ..<0.48: lightness = "dark"
        case ..<0.66: lightness = "medium"
        case ..<0.84: lightness = "light"
        default: lightness = "very light"
        }
        let family = family(forHue: color.h).name
        if color.C < 0.03 {
            return color.C >= 0.012 ? "\(lightness) grey with a hint of \(family)" : "\(lightness) neutral grey"
        }
        let chroma = color.C < 0.07 ? "muted" : (color.C < 0.14 ? "moderate" : "vivid")
        return "\(lightness), \(chroma) \(family)"
    }

    // MARK: - Checking a name

    /// Whether `name` could describe `hex`. Rejects names that put the
    /// color in a hue family two or more steps away on the wheel, a hue on
    /// a true grey, only grey words on a clearly colored swatch, or a
    /// lightness or intensity the swatch doesn't have.
    static func isPlausible(name: String, forHex hex: String) -> Bool {
        guard let color = OKLCH(hex: hex) else { return false }
        return isPlausible(name: name, for: color)
    }

    static func isPlausible(name: String, for color: OKLCH) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = tokens(trimmed)
        guard !words.isEmpty, words.count <= 4, trimmed.count <= 28 else { return false }
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil, !trimmed.contains("#") else { return false }

        let named = words.compactMap { hueWords[$0] }.map(family(forHue:))
        let own = family(forHue: color.h)
        if color.C < 0.006 {
            // A true grey has no hue to name.
            if !named.isEmpty { return false }
        } else if named.contains(where: { ringDistance($0, own) > 1 }) {
            return false
        }
        if named.isEmpty {
            if color.C >= 0.06, words.contains(where: greyWords.contains) { return false }
            if words.contains(where: whiteWords.contains), color.L < 0.8 || color.C >= 0.1 { return false }
        }
        if color.L > 0.72, words.contains(where: darkWords.contains) { return false }
        if color.L < 0.40, words.contains(where: lightWords.contains) { return false }
        if color.C < 0.06, words.contains(where: vividWords.contains) { return false }
        return true
    }

    /// Whether a palette title's color words match colors in the palette.
    /// A title with no color words always passes.
    static func isPlausibleTitle(_ title: String, forHexes hexes: [String]) -> Bool {
        let named = tokens(title).compactMap { hueWords[$0] }.map(family(forHue:))
        guard !named.isEmpty else { return true }
        let present = hexes.compactMap(OKLCH.init(hex:)).filter { $0.C >= 0.04 }.map { family(forHue: $0.h) }
        return named.allSatisfy { word in present.contains { ringDistance($0, word) <= 1 } }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the same command as Step 2. Expected: 12 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Palettes/Utilities/OKLCH.swift Palettes/Utilities/ColorVocabulary.swift PalettesTests/OKLCHTests.swift PalettesTests/ColorVocabularyTests.swift
git commit -m "feat: add OKLCH color space and color vocabulary

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Deterministic palette builder

**Files:**
- Create: `Palettes/Managers/PaletteBuilder.swift`
- Test: `PalettesTests/PaletteBuilderTests.swift`

**Interfaces:**
- Consumes:
  - `OKLCH` (Task 1)
  - `HarmonyScheme` (existing, in `ColorHarmony.swift`)
  - `ColorNamer.perceptualDistance(hex1:hex2:)` (existing)
- Produces:
  - `struct PaletteTone: Equatable { var lightness: Lightness; var chroma: Chroma; static let balanced }`, where `Lightness` is `.light/.balanced/.dark` and `Chroma` is `.muted/.balanced/.vivid`
  - `struct PaletteBuildRequest { var anchors: [String]; var size: Int; var scheme: HarmonyScheme; var tone: PaletteTone = .balanced; var hue: Double? = nil; var seed: UInt64 }`
  - `struct BuiltPalette: Equatable { let scheme: HarmonyScheme; let entries: [Entry]; var hexes: [String]; var roles: [String] }`, where `Entry` has `hex`, `role: String?` and `group: Group` (`.anchor/.dominant/.secondary/.accent/.neutral/.interface`)
  - `struct SplitMix64: RandomNumberGenerator` (top level; the old one nested in `ColorHarmony` is removed in Task 6)
  - `enum PaletteBuilder` with:
    - `static func build(_:) -> BuiltPalette`
    - `static func groupCounts(size:scheme:) -> GroupCounts`, where `GroupCounts` has `dominant/secondary/accent/neutral: Int`
    - `static func offsets(for:) -> [Double]`
    - `static func normalize(_:) -> [String]`

**Behavior, for the reviewer:**
- **Anchors:** the user's colors (anchors) ship first, verbatim, normalized to `#RRGGBB` and deduped. In harmonic schemes they are tagged `Primary` and `Secondary`; interface modes add `Accent` for a third.
- **Harmonic schemes:**
  - About half the palette is tones of each root, round-robin over the roots. The roots are the anchors, or the brief's main color when there are none.
  - About a third goes to the scheme's other hue(s). Sizes of 4 or more get one high-chroma `Accent`.
  - Sizes of 6 or more get tinted neutrals: one at 6–7, `Background` and `Text` at 8 or more.
  - Monochromatic has no secondary or accent.
  - With no anchors, harmonic palettes carry no roles.
- **Interface modes:** use fixed recipes in this fill order: Primary, Background, Text, Accent, Surface, Muted Text, Border, Secondary, Primary Container, Success, Warning, Error. Roles taken by anchors are skipped.
- **Distinctness:** each slot takes the first candidate at least 12 (CIEDE2000) from everything placed. Failing that it tries 9, then 6 (interface modes use 5, then 3). Failing all floors, it takes the farthest candidate. Neutrals are placed first so the tone ladders can step around them.
- **Auto:**
  - With two or more chosen colors, it reads their hue relationship.
  - A grey resolves to monochromatic.
  - Otherwise it draws by seed: analogous 30%, complementary 25%, split 25%, triadic 10%, monochromatic 10%.
- **Determinism:** the result depends only on the request and its seed.

- [ ] **Step 1: Write the failing test**

Create `PalettesTests/PaletteBuilderTests.swift`:

```swift
//
//  PaletteBuilderTests.swift
//  PalettesTests
//
//  The builder makes every color a generated palette ships, so these tests
//  pin its promises directly over fixed seeds: exact size, the user's
//  colors first and verbatim, hues on the scheme's offsets, colors that
//  read as different, even shares for several chosen colors, and the
//  interface roles. Fixed seeds make every run identical.
//

import XCTest
@testable import Palettes

final class PaletteBuilderTests: XCTestCase {

    private let harmonicSchemes: [HarmonyScheme] = [.complementary, .splitComplementary, .analogous, .triadic, .monochromatic]
    /// Single colors around the wheel, plus no anchor at all (hue 200).
    private let anchorSets: [[String]] = [["#3366CC"], ["#3E8E5E"], ["#E2683C"], []]
    private let seeds: [UInt64] = [0, 1, 2, 3, 4, 5]

    private func build(
        _ anchors: [String],
        size: Int,
        scheme: HarmonyScheme,
        tone: PaletteTone = .balanced,
        seed: UInt64
    ) -> BuiltPalette {
        PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: size, scheme: scheme, tone: tone, hue: 200, seed: seed))
    }

    // MARK: - Structure

    func testGroupCountsFollowSixtyThirtyTen() {
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 2, scheme: .complementary), .init(dominant: 1, secondary: 1, accent: 0, neutral: 0))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 4, scheme: .complementary), .init(dominant: 2, secondary: 1, accent: 1, neutral: 0))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 6, scheme: .triadic), .init(dominant: 3, secondary: 1, accent: 1, neutral: 1))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 12, scheme: .analogous), .init(dominant: 6, secondary: 3, accent: 1, neutral: 2))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 8, scheme: .monochromatic), .init(dominant: 6, secondary: 0, accent: 0, neutral: 2))
    }

    func testEveryRequestReachesItsSizeWithoutRepeats() {
        for scheme in HarmonyScheme.allCases {
            for anchors in anchorSets + [["#3366CC", "#CC6633"]] {
                for size in [2, 3, 4, 6, 8, 10, 12] {
                    for seed in seeds.prefix(3) {
                        let hexes = build(anchors, size: size, scheme: scheme, seed: seed).hexes
                        XCTAssertEqual(hexes.count, size, "\(scheme) \(anchors) size \(size) seed \(seed)")
                        XCTAssertEqual(Set(hexes).count, hexes.count, "repeated color: \(hexes)")
                    }
                }
            }
        }
    }

    func testAnchorsShipFirstAndVerbatim() {
        let palette = build(["3366cc", "#CC6633", "#3366CC"], size: 6, scheme: .complementary, seed: 1)
        XCTAssertEqual(Array(palette.hexes.prefix(2)), ["#3366CC", "#CC6633"])
        XCTAssertEqual(Array(palette.roles.prefix(2)), ["Primary", "Secondary"])
        XCTAssertEqual(palette.entries.filter { $0.group == .anchor }.count, 2)
    }

    func testAnchorsAloneWhenTheyFillTheSize() {
        let anchors = ["#2E4756", "#C9A15A", "#8B4A3F"]
        XCTAssertEqual(build(anchors, size: 2, scheme: .auto, seed: 1).hexes, anchors)
    }

    // MARK: - Hue fidelity

    /// Every clearly colored swatch sits on one of its scheme's hues,
    /// measured in OKLCH, the space the builder works in. Greys and
    /// near-blacks are skipped: their hue angle is rounding noise.
    func testEverySchemeStaysOnItsHues() {
        for scheme in harmonicSchemes {
            let offsets = [0] + PaletteBuilder.offsets(for: scheme)
            for anchors in anchorSets {
                let rootHue = anchors.first.flatMap { OKLCH(hex: $0)?.h } ?? 200
                for size in [4, 6, 8, 12] {
                    for seed in seeds {
                        let palette = build(anchors, size: size, scheme: scheme, seed: seed)
                        for hex in palette.hexes {
                            let color = OKLCH(hex: hex)!
                            guard color.C >= 0.04, color.L >= 0.2 else { continue }
                            let miss = offsets.map { OKLCH.hueDistance(color.h, rootHue + $0) }.min()!
                            XCTAssertLessThanOrEqual(miss, 5, "\(scheme) \(anchors) size \(size) seed \(seed): \(hex) is \(miss)° off — \(palette.hexes)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Distinctness

    /// Small palettes clear the full CIEDE2000 floor of 12; larger ones may
    /// step down to 6 (still a visible step) rather than leave the family.
    func testGeneratedColorsReadAsDifferent() {
        for scheme in harmonicSchemes {
            for anchors in anchorSets {
                for size in [2, 4, 6, 8] {
                    for seed in seeds {
                        let hexes = build(anchors, size: size, scheme: scheme, seed: seed).hexes
                        let floor: Double = size <= 4 ? 12 : 6
                        for i in hexes.indices {
                            for j in hexes.indices where j > i && j >= anchors.count {
                                let distance = ColorNamer.perceptualDistance(hex1: hexes[i], hex2: hexes[j])
                                XCTAssertGreaterThanOrEqual(distance, floor, "\(scheme) size \(size) seed \(seed): \(hexes[i]) vs \(hexes[j])")
                            }
                        }
                    }
                }
            }
        }
    }

    /// Two chosen colors split the generated tones evenly. The old HSB
    /// planner refilled a rejected tone from the other color, so this came
    /// out [2, 4] about one run in seven.
    func testTwoAnchorsShareTheTonesEvenly() {
        let anchors = ["#3366CC", "#CC6633"]
        let hues = anchors.map { OKLCH(hex: $0)!.h }
        for seed in UInt64(0)..<20 {
            let palette = build(anchors, size: 8, scheme: .monochromatic, seed: seed)
            var shares = [0, 0]
            for entry in palette.entries where entry.group == .dominant {
                let hue = OKLCH(hex: entry.hex)!.h
                shares[OKLCH.hueDistance(hue, hues[0]) < OKLCH.hueDistance(hue, hues[1]) ? 0 : 1] += 1
            }
            XCTAssertEqual(shares, [2, 2], "seed \(seed): \(palette.hexes)")
        }
    }

    // MARK: - Tone

    func testBalancedPalettesSpanLightAndDark() {
        for scheme in harmonicSchemes {
            for anchors in anchorSets {
                for size in [4, 6, 8] {
                    for seed in seeds {
                        let lightness = build(anchors, size: size, scheme: scheme, seed: seed).hexes.map { OKLCH(hex: $0)!.L }
                        XCTAssertGreaterThanOrEqual(lightness.max()! - lightness.min()!, 0.2, "\(scheme) \(anchors) size \(size) seed \(seed)")
                    }
                }
            }
        }
    }

    func testToneMovesTheMainColor() {
        func mainLightness(_ lightness: PaletteTone.Lightness) -> Double {
            OKLCH(hex: build([], size: 6, scheme: .analogous, tone: PaletteTone(lightness: lightness), seed: 1).hexes[0])!.L
        }
        XCTAssertLessThan(mainLightness(.dark) + 0.1, mainLightness(.balanced))
        XCTAssertLessThan(mainLightness(.balanced) + 0.1, mainLightness(.light))
    }

    func testMutedToneLowersChroma() {
        func meanChroma(_ chroma: PaletteTone.Chroma) -> Double {
            let generated = build(["#3366CC"], size: 6, scheme: .analogous, tone: PaletteTone(chroma: chroma), seed: 1).hexes.dropFirst()
            return generated.map { OKLCH(hex: $0)!.C }.reduce(0, +) / Double(generated.count)
        }
        XCTAssertLessThan(meanChroma(.muted), meanChroma(.balanced))
    }

    // MARK: - Auto

    func testAutoReadsTheRelationshipBetweenTwoAnchors() {
        // Blue (262°) and orange (45°) sit 143° apart: nearest to triadic.
        XCTAssertEqual(build(["#3366CC", "#CC6633"], size: 6, scheme: .auto, seed: 1).scheme, .triadic)
        XCTAssertEqual(build(["#3366CC", "#4D7FE0"], size: 6, scheme: .auto, seed: 1).scheme, .analogous)
    }

    func testAutoOnAGreyIsMonochromatic() {
        XCTAssertEqual(build(["#808080"], size: 6, scheme: .auto, seed: 1).scheme, .monochromatic)
    }

    /// The old Auto always picked split-complementary for one color at
    /// size 5 and up. It now varies with the seed.
    func testAutoVariesForASingleColor() {
        let schemes = Set((UInt64(0)..<40).map { build(["#3366CC"], size: 6, scheme: .auto, seed: $0).scheme })
        XCTAssertGreaterThanOrEqual(schemes.count, 4)
        XCTAssertFalse(schemes.contains(.auto))
        XCTAssertFalse(schemes.contains { $0.isUIMode })
    }

    // MARK: - Roles

    func testHarmonicPalettesWithoutAnchorsHaveNoRoles() {
        for scheme in harmonicSchemes {
            XCTAssertTrue(build([], size: 8, scheme: scheme, seed: 1).roles.allSatisfy(\.isEmpty), "\(scheme)")
        }
    }

    func testNeutralsCarryBackgroundAndText() {
        let roles = build(["#3060A0"], size: 8, scheme: .complementary, seed: 1).roles
        XCTAssertEqual(roles.first, "Primary")
        XCTAssertTrue(roles.contains("Accent"))
        XCTAssertTrue(roles.contains("Background"))
        XCTAssertTrue(roles.contains("Text"))
    }

    func testInterfaceModesFillTheirRolesInOrder() {
        let light = build([], size: 4, scheme: .uiLight, seed: 1)
        XCTAssertEqual(light.roles, ["Primary", "Background", "Text", "Accent"])
        XCTAssertGreaterThan(OKLCH(hex: light.hexes[1])!.L, 0.95)
        XCTAssertLessThan(OKLCH(hex: light.hexes[2])!.L, 0.3)

        let dark = build([], size: 4, scheme: .uiDark, seed: 1)
        XCTAssertEqual(dark.roles, ["Primary", "Background", "Text", "Accent"])
        XCTAssertLessThan(OKLCH(hex: dark.hexes[1])!.L, 0.25)
        XCTAssertGreaterThan(OKLCH(hex: dark.hexes[2])!.L, 0.9)
    }

    func testInterfaceModeKeepsTheUsersColorAsPrimary() {
        let palette = build(["#3060A0"], size: 5, scheme: .uiLight, seed: 1)
        XCTAssertEqual(palette.hexes.first, "#3060A0")
        XCTAssertEqual(palette.roles, ["Primary", "Background", "Text", "Accent", "Surface"])
    }

    // MARK: - Determinism

    func testSameRequestBuildsTheSamePalette() {
        for scheme in HarmonyScheme.allCases {
            XCTAssertEqual(build(["#3366CC"], size: 8, scheme: scheme, seed: 9), build(["#3366CC"], size: 8, scheme: scheme, seed: 9))
        }
        let differing = [4, 6, 8].filter {
            build(["#3366CC"], size: $0, scheme: .complementary, seed: 1).hexes
                != build(["#3366CC"], size: $0, scheme: .complementary, seed: 2).hexes
        }
        XCTAssertFalse(differing.isEmpty, "the seed should vary the palette")
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/PaletteBuilderTests`
Expected: build failure, `cannot find 'PaletteBuilder' in scope`.

- [ ] **Step 3: Create `Palettes/Managers/PaletteBuilder.swift`**

```swift
//
//  PaletteBuilder.swift
//  Palettes
//
//  Builds every color a generated palette ships, deterministically, in
//  OKLCH. The language model never picks color values: it supplies a brief
//  (main hue, tone, harmony suggestion) and names. This file turns the
//  brief plus the user's own colors into the palette.
//
//  Structure follows the 60/30/10 rule: about half the palette is tones of
//  the main color(s), about a third sits on the scheme's other hue(s), one
//  saturated accent stands out, and palettes of six or more get tinted
//  neutrals. Interface modes use fixed role recipes instead.
//
//  Pure — no UIKit, no FoundationModels — so it is fully unit-testable.
//

import Foundation

/// Lightness and saturation bias read from a vibe ("moody" → dark,
/// "pastel" → light and muted).
struct PaletteTone: Equatable {
    enum Lightness: String, CaseIterable { case light, balanced, dark }
    enum Chroma: String, CaseIterable { case muted, balanced, vivid }

    var lightness: Lightness = .balanced
    var chroma: Chroma = .balanced

    static let balanced = PaletteTone()
}

struct PaletteBuildRequest {
    /// The user's colors. They ship verbatim, in order, at the front.
    var anchors: [String]
    var size: Int
    var scheme: HarmonyScheme
    var tone: PaletteTone = .balanced
    /// OKLCH hue (degrees) of the main color when there are no anchors,
    /// usually read from the vibe. nil lets the seed choose.
    var hue: Double? = nil
    var seed: UInt64
}

struct BuiltPalette: Equatable {
    enum Group: Equatable { case anchor, dominant, secondary, accent, neutral, interface }

    struct Entry: Equatable {
        let hex: String
        let role: String?
        let group: Group
    }

    /// The concrete scheme that was built (`.auto` resolved).
    let scheme: HarmonyScheme
    let entries: [Entry]

    var hexes: [String] { entries.map(\.hex) }
    /// Roles in the parallel-array form `PaletteViewModel` stores ("" = none).
    var roles: [String] { entries.map { $0.role ?? "" } }
}

/// Deterministic PRNG: the same request must always build the same palette,
/// so the builder never touches SystemRandomNumberGenerator.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

enum PaletteBuilder {

    // MARK: - Structure

    struct GroupCounts: Equatable {
        var dominant: Int
        var secondary: Int
        var accent: Int
        var neutral: Int
    }

    /// How a harmonic palette of `size` splits into groups. The user's own
    /// colors count toward `dominant`. Monochromatic has no second hue, so
    /// no secondary or accent.
    static func groupCounts(size: Int, scheme: HarmonyScheme) -> GroupCounts {
        let neutral = size >= 8 ? 2 : (size >= 6 ? 1 : 0)
        if scheme == .monochromatic {
            return GroupCounts(dominant: max(0, size - neutral), secondary: 0, accent: 0, neutral: neutral)
        }
        let accent = size >= 4 ? 1 : 0
        let rest = max(0, size - neutral - accent)
        let secondary = min(rest, max(1, Int((Double(rest) * 0.35).rounded())))
        return GroupCounts(dominant: rest - secondary, secondary: secondary, accent: accent, neutral: neutral)
    }

    /// Hue offsets (degrees) of a harmonic scheme's other hues.
    static func offsets(for scheme: HarmonyScheme) -> [Double] {
        switch scheme {
        case .complementary: return [180]
        case .splitComplementary: return [150, 210]
        case .triadic: return [120, 240]
        case .analogous: return [30, -30]
        case .monochromatic, .auto, .uiLight, .uiDark: return [0]
        }
    }

    // MARK: - Build

    static func build(_ request: PaletteBuildRequest) -> BuiltPalette {
        let anchorHexes = normalize(request.anchors)
        let anchors = anchorHexes.compactMap(OKLCH.init(hex:))
        let size = max(request.size, anchorHexes.count)
        var rng = SplitMix64(seed: request.seed)

        let scheme = request.scheme == .auto ? resolveAuto(anchors: anchors, rng: &rng) : request.scheme
        let anchorEntries = anchorHexes.indices.map { index in
            BuiltPalette.Entry(hex: anchorHexes[index], role: anchorRole(index, scheme: scheme), group: .anchor)
        }
        guard size > anchorHexes.count else {
            return BuiltPalette(scheme: scheme, entries: anchorEntries)
        }

        let hue = request.hue ?? Double(rng.next() % 360)
        let rotation = Int(rng.next() % 3)
        let main = mainColor(hue: hue, tone: request.tone)

        let generated = scheme.isUIMode
            ? interfaceEntries(anchors: anchors, placed: anchorHexes, main: main, size: size, tone: request.tone, isDark: scheme == .uiDark)
            : harmonicEntries(anchors: anchors, placed: anchorHexes, main: main, size: size, scheme: scheme, tone: request.tone, rotation: rotation)

        var entries = anchorEntries + generated
        // With none of the user's colors, nothing anchors "Primary" and the
        // rest in a harmonic palette. Interface palettes keep their roles:
        // the roles are what an interface palette is for.
        if anchorHexes.isEmpty && !scheme.isUIMode {
            entries = entries.map { BuiltPalette.Entry(hex: $0.hex, role: nil, group: $0.group) }
        }
        return BuiltPalette(scheme: scheme, entries: entries)
    }

    /// Normalizes to "#RRGGBB", drops unparseable and repeated hexes, keeps order.
    static func normalize(_ hexes: [String]) -> [String] {
        var result: [String] = []
        for raw in hexes {
            var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard OKLCH(hex: hex) != nil, !result.contains(hex) else { continue }
            result.append(hex)
        }
        return result
    }

    // MARK: - Auto

    /// Two or more of the user's colors already imply a harmony; otherwise
    /// Auto draws one, weighted toward the calmer schemes.
    private static func resolveAuto(anchors: [OKLCH], rng: inout SplitMix64) -> HarmonyScheme {
        let chromatic = anchors.filter { $0.C >= 0.03 }
        if chromatic.count >= 2 {
            let d = OKLCH.hueDistance(chromatic[0].h, chromatic[1].h)
            if d <= 45 { return .analogous }
            if abs(d - 180) <= 30 { return .complementary }
            if abs(d - 120) <= 25 { return .triadic }
            return .splitComplementary
        }
        if !anchors.isEmpty && chromatic.isEmpty { return .monochromatic }
        let roll = rng.nextUnit()
        if roll < 0.30 { return .analogous }
        if roll < 0.55 { return .complementary }
        if roll < 0.80 { return .splitComplementary }
        if roll < 0.90 { return .triadic }
        return .monochromatic
    }

    private static func anchorRole(_ index: Int, scheme: HarmonyScheme) -> String? {
        let roles = scheme.isUIMode ? ["Primary", "Secondary", "Accent"] : ["Primary", "Secondary"]
        return index < roles.count ? roles[index] : nil
    }

    // MARK: - Harmonic schemes

    private static func harmonicEntries(
        anchors: [OKLCH],
        placed initial: [String],
        main: OKLCH,
        size: Int,
        scheme: HarmonyScheme,
        tone: PaletteTone,
        rotation: Int
    ) -> [BuiltPalette.Entry] {
        var placed = initial
        var entries: [BuiltPalette.Entry] = []
        func place(_ candidates: [OKLCH], floors: [Double], role: String?, group: BuiltPalette.Group) -> BuiltPalette.Entry {
            let hex = pick(candidates, placed: placed, floors: floors)
            placed.append(hex)
            return BuiltPalette.Entry(hex: hex, role: role, group: group)
        }

        // Each root heads a family of tones: the user's colors, or the
        // brief's main color when there are none.
        let roots = anchors.isEmpty ? [main] : anchors
        if anchors.isEmpty {
            entries.append(place([main], floors: [0], role: nil, group: .dominant))
        }

        let counts = groupCounts(size: size, scheme: scheme)
        var slots: [BuiltPalette.Group] = Array(repeating: .dominant, count: max(0, counts.dominant - roots.count))
        if counts.secondary > 0 { slots.append(.secondary) }
        slots += Array(repeating: .accent, count: counts.accent)
        slots += Array(repeating: .secondary, count: max(0, counts.secondary - 1))
        slots += Array(repeating: .neutral, count: counts.neutral)
        // Many anchors can outnumber the dominant share; neutrals, then
        // extra secondaries, then the accent give way first.
        slots = Array(slots.prefix(size - placed.count))

        let schemeOffsets = offsets(for: scheme)
        let accentOffset = schemeOffsets.count > 1 ? schemeOffsets[1] : schemeOffsets[0]
        let neutralOrder: [Bool] = counts.neutral == 1 ? [tone.lightness != .dark] : [true, false]
        var dominantIndex = 0
        var secondaryIndex = 0
        var neutralIndex = 0

        // Neutrals are placed first: they have only a few candidates, while
        // the tone ladders have many and can step around them. Entries still
        // come out in slot order.
        let placementOrder = slots.indices.filter { slots[$0] == .neutral } + slots.indices.filter { slots[$0] != .neutral }
        var slotted = [BuiltPalette.Entry?](repeating: nil, count: slots.count)
        for position in placementOrder {
            switch slots[position] {
            case .dominant:
                // Round-robin over the roots, so two chosen colors get equal shares.
                let root = roots[dominantIndex % roots.count]
                dominantIndex += 1
                slotted[position] = place(toneCandidates(root: root, tone: tone, rotation: rotation), floors: [12, 9, 6], role: nil, group: .dominant)
            case .secondary:
                let root = roots[secondaryIndex % roots.count]
                let offset = schemeOffsets[(secondaryIndex / roots.count) % schemeOffsets.count]
                secondaryIndex += 1
                slotted[position] = place(secondaryCandidates(root: root, offset: offset, schemeOffsets: schemeOffsets, tone: tone), floors: [12, 9, 6], role: nil, group: .secondary)
            case .accent:
                slotted[position] = place(accentCandidates(root: roots[0], offset: accentOffset, tone: tone), floors: [12, 9, 6], role: "Accent", group: .accent)
            case .neutral:
                let light = neutralOrder[neutralIndex % neutralOrder.count]
                neutralIndex += 1
                slotted[position] = place(neutralCandidates(root: roots[0], light: light), floors: [12, 9, 6], role: light ? "Background" : "Text", group: .neutral)
            case .anchor, .interface:
                break
            }
        }
        entries += slotted.compactMap { $0 }
        return entries
    }

    /// Lightness rungs for tones of a root, in dark/light pairs, most useful
    /// first: a dark and a light tone come before the mid-tones, so even
    /// four colors span a real lightness range. The seed rotates the ladder
    /// by whole pairs, which varies the palette without breaking that order.
    private static let toneLadder: [Double] = [0.30, 0.86, 0.22, 0.94, 0.42, 0.76, 0.16, 0.97, 0.37, 0.68, 0.51, 0.58]
    private static let secondaryLadder: [Double] = [0.62, 0.42, 0.76, 0.32, 0.86, 0.52, 0.24, 0.92]
    private static let accentLadder: [Double] = [0.68, 0.58, 0.76, 0.50]

    private static func mainColor(hue: Double, tone: PaletteTone) -> OKLCH {
        let L: Double = tone.lightness == .light ? 0.78 : (tone.lightness == .dark ? 0.42 : 0.6)
        let C: Double = tone.chroma == .muted ? 0.07 : (tone.chroma == .vivid ? 0.19 : 0.13)
        return OKLCH(L: L, C: C, h: hue).gamutMapped()
    }

    /// Squeezes the ladder toward the light or dark end for a light or dark vibe.
    private static func remap(_ L: Double, _ lightness: PaletteTone.Lightness) -> Double {
        switch lightness {
        case .balanced: return L
        case .light: return 0.50 + (L - 0.16) * (0.975 - 0.50) / (0.97 - 0.16)
        case .dark: return 0.10 + (L - 0.16) * (0.70 - 0.10) / (0.97 - 0.16)
        }
    }

    private static func chromaFactor(_ chroma: PaletteTone.Chroma) -> Double {
        switch chroma {
        case .muted: return 0.55
        case .balanced: return 1
        case .vivid: return 1.3
        }
    }

    /// Chroma shrinks toward the ends of the lightness range, where sRGB
    /// holds little of it anyway, so a near-white stays a tint of its hue
    /// instead of being clipped into a different one.
    private static func lightnessChromaScale(_ L: Double) -> Double {
        min(1, max(0.35, 1 - 0.55 * abs(L - 0.6) / 0.4))
    }

    private static func toneCandidates(root: OKLCH, tone: PaletteTone, rotation: Int) -> [OKLCH] {
        let factor = chromaFactor(tone.chroma)
        let rungs = toneLadder.indices.map { toneLadder[($0 + rotation * 2) % toneLadder.count] }
        // A grey has only lightness to vary, so it always gets the full
        // range; squeezing it for a light or dark vibe leaves too few steps.
        let lightness = root.C < 0.03 ? .balanced : tone.lightness
        let full = rungs.map { rung -> OKLCH in
            let L = remap(rung, lightness)
            return OKLCH(L: L, C: root.C * lightnessChromaScale(L) * factor, h: root.h)
        }
        // Long single-hue palettes run past the main rungs: half-chroma
        // tones, then a fine sweep that fills whatever gaps remain.
        let fine = stride(from: 0.14, through: 0.98, by: 0.04).map { rung -> OKLCH in
            OKLCH(L: rung, C: root.C * lightnessChromaScale(rung) * factor, h: root.h)
        }
        return full + full.map { OKLCH(L: $0.L, C: $0.C * 0.5, h: $0.h) } + fine
    }

    private static func secondaryCandidates(root: OKLCH, offset: Double, schemeOffsets: [Double], tone: PaletteTone) -> [OKLCH] {
        let factor = chromaFactor(tone.chroma)
        let chroma = max(root.C, 0.06) * 0.9
        // The assigned hue first; the scheme's other hues only as a fallback.
        let hueOffsets = [offset] + schemeOffsets.filter { $0 != offset }
        return hueOffsets.flatMap { hueOffset in
            secondaryLadder.map { rung -> OKLCH in
                let L = remap(rung, tone.lightness)
                return OKLCH(L: L, C: chroma * lightnessChromaScale(L) * factor, h: root.h + hueOffset)
            }
        }
    }

    private static func accentCandidates(root: OKLCH, offset: Double, tone: PaletteTone) -> [OKLCH] {
        let shift: Double = tone.lightness == .dark ? -0.06 : (tone.lightness == .light ? 0.04 : 0)
        let chroma = 0.25 * (tone.chroma == .muted ? 0.6 : (tone.chroma == .vivid ? 1.15 : 1))
        return accentLadder.map { OKLCH(L: $0 + shift, C: chroma, h: root.h + offset) }
    }

    /// Near-white and near-black tinted with the root's hue — or true
    /// greys when the root is itself grey, whose hue angle means nothing.
    private static func neutralCandidates(root: OKLCH, light: Bool) -> [OKLCH] {
        let tint = root.C < 0.03 ? 0 : 1.0
        return light
            ? [0.97, 0.94, 0.91, 0.99].map { OKLCH(L: $0, C: 0.012 * tint, h: root.h) }
            : [0.21, 0.26, 0.17, 0.31].map { OKLCH(L: $0, C: 0.02 * tint, h: root.h) }
    }

    // MARK: - Interface modes

    private enum HueRule: Equatable {
        case primary
        case offset(Double)
        case fixed(Double)
    }

    private struct InterfaceRecipe {
        let role: String
        let light: (L: Double, C: Double)
        let dark: (L: Double, C: Double)
        let hue: HueRule
        let chromaFollowsTone: Bool
    }

    /// In fill order: a 4-color interface palette gets Primary, Background,
    /// Text and Accent; larger ones add surfaces, then status colors.
    private static let interfaceRecipes: [InterfaceRecipe] = [
        InterfaceRecipe(role: "Primary", light: (0.55, 0.15), dark: (0.72, 0.14), hue: .primary, chromaFollowsTone: true),
        InterfaceRecipe(role: "Background", light: (0.985, 0.006), dark: (0.18, 0.012), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Text", light: (0.24, 0.02), dark: (0.95, 0.008), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Accent", light: (0.64, 0.16), dark: (0.74, 0.14), hue: .offset(140), chromaFollowsTone: true),
        InterfaceRecipe(role: "Surface", light: (0.94, 0.01), dark: (0.25, 0.016), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Muted Text", light: (0.50, 0.02), dark: (0.70, 0.015), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Border", light: (0.86, 0.015), dark: (0.35, 0.02), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Secondary", light: (0.45, 0.10), dark: (0.66, 0.09), hue: .offset(30), chromaFollowsTone: true),
        InterfaceRecipe(role: "Primary Container", light: (0.90, 0.05), dark: (0.32, 0.06), hue: .primary, chromaFollowsTone: true),
        InterfaceRecipe(role: "Success", light: (0.62, 0.15), dark: (0.72, 0.15), hue: .fixed(150), chromaFollowsTone: false),
        InterfaceRecipe(role: "Warning", light: (0.78, 0.15), dark: (0.82, 0.14), hue: .fixed(80), chromaFollowsTone: false),
        InterfaceRecipe(role: "Error", light: (0.58, 0.19), dark: (0.68, 0.17), hue: .fixed(27), chromaFollowsTone: false),
    ]

    private static func interfaceEntries(
        anchors: [OKLCH],
        placed initial: [String],
        main: OKLCH,
        size: Int,
        tone: PaletteTone,
        isDark: Bool
    ) -> [BuiltPalette.Entry] {
        var placed = initial
        var entries: [BuiltPalette.Entry] = []
        let primary = anchors.first ?? main
        let taken = Set(anchors.indices.compactMap { anchorRole($0, scheme: .uiLight) })
        let factor = chromaFactor(tone.chroma)

        for recipe in interfaceRecipes where placed.count < size && !taken.contains(recipe.role) {
            let spec = isDark ? recipe.dark : recipe.light
            let hue: Double
            switch recipe.hue {
            case .primary: hue = primary.h
            case .offset(let degrees): hue = primary.h + degrees
            case .fixed(let degrees): hue = degrees
            }
            // A grey primary has no meaningful hue to tint the surfaces with.
            let tint = primary.C < 0.03 && recipe.hue == .primary && !recipe.chromaFollowsTone ? 0 : 1.0
            let chroma = (recipe.chromaFollowsTone ? spec.C * factor : spec.C) * tint
            // Surfaces sit close together by design, so interface colors use
            // a lower distinctness floor than harmonic ones.
            let candidates = [0, 0.03, -0.03, 0.06, -0.06].map { OKLCH(L: min(0.99, max(0.05, spec.L + $0)), C: chroma, h: hue) }
            let hex = pick(candidates, placed: placed, floors: [5, 3])
            placed.append(hex)
            entries.append(BuiltPalette.Entry(hex: hex, role: recipe.role, group: .interface))
        }
        // Only reachable with many anchors: top up with tones of the primary.
        while placed.count < size {
            let hex = pick(toneCandidates(root: primary, tone: tone, rotation: 0), placed: placed, floors: [12, 9, 6])
            placed.append(hex)
            entries.append(BuiltPalette.Entry(hex: hex, role: nil, group: .dominant))
        }
        return entries
    }

    // MARK: - Distinctness

    /// The first candidate at least `floor` (CIEDE2000) from every placed
    /// color, trying each floor in turn. If none clears even the lowest,
    /// the candidate farthest from everything placed.
    private static func pick(_ candidates: [OKLCH], placed: [String], floors: [Double]) -> String {
        let hexes = candidates.map(\.hex)
        for floor in floors {
            if let hex = hexes.first(where: { !placed.contains($0) && minDistance($0, to: placed) >= floor }) {
                return hex
            }
        }
        return hexes.max { minDistance($0, to: placed) < minDistance($1, to: placed) } ?? hexes[0]
    }

    private static func minDistance(_ hex: String, to placed: [String]) -> Double {
        placed.map { ColorNamer.perceptualDistance(hex1: hex, hex2: $0) }.min() ?? .greatestFiniteMagnitude
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run the same command as Step 2. Expected: 18 tests pass, in a few seconds.

- [ ] **Step 5: Commit**

```bash
git add Palettes/Managers/PaletteBuilder.swift PalettesTests/PaletteBuilderTests.swift
git commit -m "feat: add deterministic OKLCH palette builder with 60/30/10 structure

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Dictionary names agree with their swatch

**Files:**
- Modify: `Palettes/Utilities/HEXParser.swift` (the `ColorNamer` enum)
- Test: `PalettesTests/ColorNamerTests.swift`

**Interfaces:**
- Consumes: `OKLCH` and `ColorVocabulary` (Task 1), `PaletteBuilder` (Task 2, test only)
- Produces:
  - `ColorNamer.hex(forName: String) -> String?`
  - `ColorNamer.uniqueNames(forHexes:preferred:)` with the same signature, where:
    - Dictionary entries from the color's own hue family, whose own names fit the swatch, are preferred.
    - A modifier is only used when it is true of the color itself.
    - An entry that already has a modifier never gets a second one.

- [ ] **Step 1: Write the failing tests**

Add these methods inside `final class ColorNamerTests` in `PalettesTests/ColorNamerTests.swift`, after `testEmptyPreferredFallsBackToDescriptiveName`:

```swift
    // MARK: - Names agree with the swatch

    func testLightColorIsNotGivenADarkEntryName() {
        // A light teal whose nearest dictionary entry is "Dark Turquoise".
        let name = ColorNamer.uniqueNames(forHexes: ["#2FD4DE"])[0]
        XCTAssertFalse(ColorVocabulary.tokens(name).contains("dark"), name)
    }

    func testSaturatedTealIsNotNamedAfterAGrey() {
        // Its nearest dictionary entry is "Steel".
        let name = ColorNamer.uniqueNames(forHexes: ["#2C7284"])[0]
        XCTAssertFalse(ColorVocabulary.tokens(name).contains { ColorVocabulary.greyWords.contains($0) }, name)
    }

    func testPaleIsNeverPutOnADarkColor() {
        // Used to be "Pale Space Blue".
        let name = ColorNamer.uniqueNames(forHexes: ["#3D405B"])[0]
        XCTAssertFalse(name.hasPrefix("Pale") || name.hasPrefix("Light"), name)
    }

    func testGreyEntriesNeverGetAChromaModifier() {
        // Used to be "Vivid Black".
        let name = ColorNamer.uniqueNames(forHexes: ["#26131D"])[0]
        XCTAssertFalse(name.hasPrefix("Vivid") || name.hasPrefix("Rich"), name)
    }

    /// Every dictionary name the generator can ship passes the same check
    /// the model's names must pass.
    func testBuiltPalettesGetPlausibleNames() {
        for scheme in HarmonyScheme.allCases where scheme != .auto {
            for seed in UInt64(0)..<12 {
                let hexes = PaletteBuilder.build(PaletteBuildRequest(
                    anchors: [], size: 8, scheme: scheme, hue: Double(seed * 29 % 360), seed: seed
                )).hexes
                for (hex, name) in zip(hexes, ColorNamer.uniqueNames(forHexes: hexes)) {
                    XCTAssertTrue(ColorVocabulary.isPlausible(name: name, forHex: hex), "\(name) on \(hex)")
                }
            }
        }
    }

    func testHexForNameIgnoresCaseAndSpacing() {
        XCTAssertEqual(ColorNamer.hex(forName: "red"), "#FF0000")
        XCTAssertEqual(ColorNamer.hex(forName: " Red "), "#FF0000")
        XCTAssertNil(ColorNamer.hex(forName: "Not A Color"))
    }
```

- [ ] **Step 2: Run them to verify they fail**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/ColorNamerTests`
Expected: build failure, `type 'ColorNamer' has no member 'hex'`. With that test temporarily commented out, the five naming tests fail. For example, `#2FD4DE` is named "Dark Turquoise" and `#2C7284` "Steel".

- [ ] **Step 3: Add `hex(forName:)`**

In `Palettes/Utilities/HEXParser.swift`, insert directly above `static func name(forHex hex: String) -> String {`:

```swift
    /// The dictionary color named `name` (any casing), as "#RRGGBB".
    static func hex(forName name: String) -> String? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let entry = namedColors.first(where: { $0.name.lowercased() == target }) else { return nil }
        return String(format: "#%02X%02X%02X", Int(entry.r), Int(entry.g), Int(entry.b))
    }
```

- [ ] **Step 4: Add the fitting helpers**

Insert directly below the `namedColorsLab` declaration (the two lines starting `private static let namedColorsLab`), above `// ── Public API ──`:

```swift
    private static let namedColorsOKLCH: [OKLCH] =
        namedColors.map { OKLCH(r: $0.r / 255.0, g: $0.g / 255.0, b: $0.b / 255.0) }

    /// Words that already modify an entry name ("Dark Orange", "Pale Gold");
    /// such an entry never gets a second modifier.
    private static let modifierWords: Set<String> = [
        "dark", "deep", "light", "pale", "medium", "vivid", "rich", "muted", "soft",
        "bright", "hot", "neon", "electric", "dim", "dusty", "pastel",
    ]

    /// Whether a dictionary entry belongs to the same broad color as `color`:
    /// greys only for greys, never a grey for a clearly colored swatch, a
    /// hue family at most one step away, and an entry name that doesn't
    /// itself contradict the color ("Dark Turquoise" on a light teal).
    private static func entryFits(_ index: Int, color: OKLCH) -> Bool {
        let entry = namedColorsOKLCH[index]
        if color.C < 0.03 {
            guard entry.C < 0.05 else { return false }
        } else if color.C >= 0.045 && entry.C < 0.025 {
            return false
        } else if color.C >= 0.04 && entry.C >= 0.04 {
            let a = ColorVocabulary.family(forHue: color.h)
            let b = ColorVocabulary.family(forHue: entry.h)
            guard ColorVocabulary.ringDistance(a, b) <= 1 else { return false }
        }
        return ColorVocabulary.isPlausible(name: namedColors[index].name, for: color)
    }

    /// Whether a modifier is true of the color itself, not just of its
    /// difference from the dictionary entry.
    private static func modifierFits(_ word: String, color: OKLCH) -> Bool {
        switch word {
        case "Pale", "Light": return color.L >= 0.62
        case "Dark", "Deep": return color.L <= 0.6
        case "Vivid": return color.C >= 0.12
        case "Rich": return color.C >= 0.08
        default: return true
        }
    }
```

- [ ] **Step 5: Replace the ranking and candidate logic in `uniqueNames`**

In `uniqueNames(forHexes:preferred:)`, replace everything from the line `let ranked: [[(index: Int, delta: Double)]] = labs.map { lab in` up to, but not including, `var result = Array(repeating: "", count: n)`. That span is the `ranked` declaration, `enum Axis`, `modifierWord` and `candidates`. Replace it with:

```swift
        let oklch: [OKLCH?] = hexes.map(OKLCH.init(hex:))
        let ranked: [[(index: Int, delta: Double)]] = hexes.indices.map { i in
            guard let lab = labs[i] else { return [] }
            let byDistance = namedColorsLab.enumerated()
                .map { (index: $0.offset, delta: ciede2000(lab, $0.element.lab)) }
                .sorted { $0.delta < $1.delta }
            // Entries in the color's own hue family (and greys for greys)
            // come first, even when a wrong-family entry is a little nearer
            // in Lab — that nearness is what named a deep teal "Charcoal".
            guard let color = oklch[i] else { return byDistance }
            let fits = byDistance.map { entryFits($0.index, color: color) }
            let fitting = byDistance.indices.filter { fits[$0] }.map { byDistance[$0] }
            let others = byDistance.indices.filter { !fits[$0] }.map { byDistance[$0] }
            return fitting + others
        }

        enum Axis { case lightness, chroma }
        func modifierWord(dL: Double, dC: Double, axis: Axis) -> String {
            switch axis {
            case .lightness:
                return dL < 0 ? (dC > 0 ? "Deep" : "Dark") : (dC < 0 ? "Pale" : "Light")
            case .chroma:
                return dC > 0 ? (dL < 0 ? "Rich" : "Vivid") : (dL < 0 ? "Muted" : "Soft")
            }
        }

        // Every candidate name for a given color at a given rank into its
        // ranked-entries list: the plain entry name if it's a close match,
        // otherwise the dominant-axis modifier first, then the secondary
        // axis's modifier, keeping only modifiers that are true of the
        // color itself (never "Pale" on a dark color, "Vivid" on a grey, or
        // a second modifier on an entry that already has one).
        func candidates(colorIndex: Int, rank: Int) -> [String] {
            guard let lab = labs[colorIndex], rank < ranked[colorIndex].count else { return [] }
            let entry = ranked[colorIndex][rank]
            let entryName = namedColorsLab[entry.index].name
            guard entry.delta >= modifierThreshold else { return [entryName] }
            guard let color = oklch[colorIndex],
                  !ColorVocabulary.tokens(entryName).contains(where: modifierWords.contains) else { return [entryName] }

            let entryLab = namedColorsLab[entry.index].lab
            let entryIsGrey = namedColorsOKLCH[entry.index].C < 0.03
            let dL = lab.L - entryLab.L
            let dC = labChroma(lab) - labChroma(entryLab)
            let dominant: Axis = abs(dL) >= abs(dC) ? .lightness : .chroma
            let secondary: Axis = dominant == .lightness ? .chroma : .lightness

            var names: [String] = []
            for axis in [dominant, secondary] where !(axis == .chroma && entryIsGrey) {
                let word = modifierWord(dL: dL, dC: dC, axis: axis)
                guard modifierFits(word, color: color) else { continue }
                let name = "\(word) \(entryName)"
                if !names.contains(name) { names.append(name) }
            }
            return names.isEmpty ? [entryName] : names
        }
```

Also update the doc comment above `uniqueNames`. Replace these lines:

```swift
    /// everything else gets a descriptive name built from the nearest
    /// dictionary entry plus a modifier reflecting how the color actually
    /// deviates from that entry in Lab (lightness → Deep/Dark/Pale/Light,
    /// chroma → Muted/Soft/Vivid/Rich). Colors very close to their nearest
    /// entry get the plain entry name, no modifier.
```

with:

```swift
    /// everything else gets a descriptive name built from the nearest
    /// dictionary entry that fits the color (same hue family, greys for
    /// greys, an entry name that doesn't contradict the swatch), plus a
    /// modifier only when it is true of the color itself (lightness →
    /// Deep/Dark/Pale/Light, chroma → Muted/Soft/Vivid/Rich). Colors very
    /// close to their nearest entry get the plain entry name, no modifier.
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/ColorNamerTests`
Expected: every test passes, the existing ones included. `#FF0000` is still "Red" and `#7A6F5D` still gets a two-word name.

- [ ] **Step 7: Commit**

```bash
git add Palettes/Utilities/HEXParser.swift PalettesTests/ColorNamerTests.swift
git commit -m "fix: dictionary color names agree with their swatch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Vibe brief

**Files:**
- Create: `Palettes/Managers/PaletteBrief.swift`
- Test: `PalettesTests/PaletteBriefTests.swift`

**Interfaces:**
- Consumes: `ColorVocabulary` and `OKLCH` (Task 1), `PaletteTone` (Task 2), `ColorNamer.hex(forName:)` (Task 3)
- Produces: `struct PaletteBrief: Equatable { var hue: Double?; var tone: PaletteTone; var scheme: HarmonyScheme? }` with:
  - `static let neutral`
  - `static func heuristic(from vibe: String) -> PaletteBrief`
  - `static func hue(forColorWord: String) -> Double?`

  Task 6 adds the model initializer in `PaletteGenerator.swift`, behind `@available(iOS 26.0, *)`.

- [ ] **Step 1: Write the failing test**

Create `PalettesTests/PaletteBriefTests.swift`:

```swift
//
//  PaletteBriefTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class PaletteBriefTests: XCTestCase {

    func testColorWordSetsTheHue() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "moody navy library").hue, 262)
        XCTAssertEqual(PaletteBrief.heuristic(from: "Cerulean").hue, 240)
    }

    func testColorWordBeatsAPlaceWord() {
        // "ocean" alone reads as blue; the color word wins.
        XCTAssertEqual(PaletteBrief.heuristic(from: "terracotta by the ocean").hue, 45)
    }

    func testPlaceWordSetsTheHueWhenNoColorIsNamed() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "sunset over the ocean").hue, 45)
        XCTAssertNil(PaletteBrief.heuristic(from: "neon arcade").hue)
    }

    func testToneWords() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "moody navy library").tone, PaletteTone(lightness: .dark))
        XCTAssertEqual(PaletteBrief.heuristic(from: "pastel spring garden").tone, PaletteTone(lightness: .light, chroma: .muted))
        XCTAssertEqual(PaletteBrief.heuristic(from: "neon arcade").tone, PaletteTone(chroma: .vivid))
        XCTAssertEqual(PaletteBrief.heuristic(from: "calm").tone, PaletteTone(chroma: .muted))
    }

    func testHarmonyWords() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "monochrome lavender").scheme, .monochromatic)
        XCTAssertEqual(PaletteBrief.heuristic(from: "complementary sunset").scheme, .complementary)
        XCTAssertNil(PaletteBrief.heuristic(from: "warm autumn forest").scheme)
    }

    func testHueForColorWord() {
        XCTAssertEqual(PaletteBrief.hue(forColorWord: "navy"), 262)
        // "Tomato" is only in the color dictionary.
        let tomato = PaletteBrief.hue(forColorWord: "Tomato")
        XCTAssertNotNil(tomato)
        XCTAssertEqual(ColorVocabulary.family(forHue: tomato ?? 0), .red)
        XCTAssertNil(PaletteBrief.hue(forColorWord: "Gray"), "a grey has no hue")
        XCTAssertNil(PaletteBrief.hue(forColorWord: "unicorn"))
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/PaletteBriefTests`
Expected: build failure, `cannot find 'PaletteBrief' in scope`.

- [ ] **Step 3: Create `Palettes/Managers/PaletteBrief.swift`**

```swift
//
//  PaletteBrief.swift
//  Palettes
//
//  What a vibe asks of a palette, in terms the builder understands: a main
//  hue, a tone, and optionally a harmony. On device the language model
//  fills this in; `heuristic(from:)` reads the vibe's own words instead, on
//  the Simulator and whenever the model fails. Either way the model never
//  chooses color values.
//

import Foundation

struct PaletteBrief: Equatable {
    /// OKLCH hue (degrees) of the palette's main color, if the vibe names one.
    var hue: Double?
    var tone: PaletteTone
    /// A harmonic scheme the vibe calls for. Never `.auto` or an interface mode.
    var scheme: HarmonyScheme?

    static let neutral = PaletteBrief(hue: nil, tone: .balanced, scheme: nil)

    /// Reads a vibe from its words: a color word sets the hue (a place or
    /// mood word only if no color word appears), tone words set lightness
    /// and saturation, and harmony words set the scheme.
    static func heuristic(from vibe: String) -> PaletteBrief {
        let words = ColorVocabulary.tokens(vibe)
        let hue = words.lazy.compactMap { ColorVocabulary.hueWords[$0] }.first
            ?? words.lazy.compactMap { ColorVocabulary.moodHues[$0] }.first

        var tone = PaletteTone.balanced
        if words.contains(where: ColorVocabulary.darkToneWords.contains) {
            tone.lightness = .dark
        } else if words.contains(where: ColorVocabulary.lightToneWords.contains) {
            tone.lightness = .light
        }
        if words.contains(where: ColorVocabulary.mutedToneWords.contains) {
            tone.chroma = .muted
        } else if words.contains(where: ColorVocabulary.vividToneWords.contains) {
            tone.chroma = .vivid
        }

        var scheme: HarmonyScheme?
        if words.contains(where: ["monochrome", "monochromatic", "tonal"].contains) {
            scheme = .monochromatic
        } else if words.contains("complementary") {
            scheme = .complementary
        } else if words.contains("analogous") {
            scheme = .analogous
        } else if words.contains("triadic") {
            scheme = .triadic
        }
        return PaletteBrief(hue: hue, tone: tone, scheme: scheme)
    }

    /// The OKLCH hue of a color word such as "terracotta" or "navy blue":
    /// the vocabulary first, then the color dictionary. nil for words that
    /// name no hue (including greys).
    static func hue(forColorWord word: String) -> Double? {
        let words = ColorVocabulary.tokens(word)
        if let hue = words.lazy.compactMap({ ColorVocabulary.hueWords[$0] }).first
            ?? words.lazy.compactMap({ ColorVocabulary.moodHues[$0] }).first {
            return hue
        }
        guard let hex = ColorNamer.hex(forName: word),
              let color = OKLCH(hex: hex),
              color.C >= 0.03 else { return nil }
        return color.h
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Palettes/Managers/PaletteBrief.swift PalettesTests/PaletteBriefTests.swift
git commit -m "feat: read a vibe into a palette brief

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Titles follow the main color

**Files:**
- Modify: `Palettes/Managers/PaletteNamer.swift`
- Test: `PalettesTests/PaletteNamerTests.swift`

**Interfaces:**
- Consumes: `ColorVocabulary.isPlausibleTitle(_:forHexes:)` (Task 1)
- Produces: `PaletteNamer.resolvedName(aiName:hexes:existingNames:)` and `descriptiveName(forHexes:existingNames:)`, with unchanged signatures:
  - The title's family comes from the first clearly colored swatch. Generated palettes list the user's colors and the main family first.
  - No filler words.
  - AI titles that name a color absent from the palette are replaced.

- [ ] **Step 1: Write the failing tests**

Add inside `final class PaletteNamerTests`, after `testNilAINameFallsBackToDescriptive`:

```swift
    // MARK: - Titles follow the main color

    /// Generated palettes list the main color first. The title must name
    /// that family, not the loudest accent: a blue palette with one orange
    /// accent was being titled after the orange.
    func testTitleFamilyComesFromTheFirstColor() {
        let name = PaletteNamer.descriptiveName(
            forHexes: ["#2E5F8A", "#3E7FB0", "#1E3F5A", "#FF5A00"],
            existingNames: []
        )
        let warmFamilies = ["Garnet", "Coral", "Terracotta", "Ember", "Copper", "Apricot"]
        XCTAssertFalse(warmFamilies.contains { name.contains($0) }, name)
    }

    func testTitlesDropFillerWords() {
        let palettes = [
            ["#A9603F", "#C08552"], ["#2E5F8A", "#3E7FB0"], ["#4E7A4F", "#6FA36F"],
            ["#E8E2D8", "#D8D2C8"], ["#6B4E8A", "#8E6FB0"],
        ]
        var names: [String] = []
        for hexes in palettes {
            for _ in 0..<6 {
                names.append(PaletteNamer.descriptiveName(forHexes: hexes, existingNames: names))
            }
        }
        for name in names {
            for filler in ["Textured", "Woven", "Measured"] {
                XCTAssertFalse(name.contains(filler), name)
            }
        }
    }

    func testAITitleNamingAColorNotInThePaletteIsReplaced() {
        let name = PaletteNamer.resolvedName(
            aiName: "Crimson Tide",
            hexes: ["#2E5F8A", "#3E7FB0", "#1E3F5A"],
            existingNames: []
        )
        XCTAssertNotEqual(name, "Crimson Tide")
        XCTAssertFalse(name.isEmpty)
    }
```

- [ ] **Step 2: Run them to verify they fail**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/PaletteNamerTests`
Expected: all three new tests fail. The first title names the orange family, filler words appear, and "Crimson Tide" is kept.

- [ ] **Step 3: Check the AI title against the palette**

In `resolvedName`, add the plausibility condition:

```swift
        if let candidate = aiName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !candidate.isEmpty,
           !isGeneric(candidate),
           !usesClichedTitleLanguage(candidate),
           ColorVocabulary.isPlausibleTitle(candidate, forHexes: hexes),
           !taken.contains(candidate.lowercased()) {
            return candidate
        }
```

Update its doc comment's first sentence to "Resolves the final palette title: keeps `aiName` when it's specific, names only colors the palette has, and isn't already taken; otherwise synthesizes a descriptive one from the palette's colors."

- [ ] **Step 4: Name the family after the first colored swatch**

In `Traits`, replace the doc comment on `hue` with:

```swift
        /// Hue of the palette's first clearly colored swatch, never an
        /// average (averaging opposing hues names a family that isn't in
        /// the palette at all). Generated palettes list the user's colors
        /// and the main color's family first, so this is the main color,
        /// not the loudest accent.
```

In `traits(forHexes:)`, replace:

```swift
        // The palette's "signature" color: the most saturated one, tie-broken
        // deterministically by hex order. Its hue names the family, so the
        // title always points at a color that is genuinely present.
        let signature = chromatic.max { lhs, rhs in
            lhs.s == rhs.s ? false : lhs.s < rhs.s
        }
```

with:

```swift
        // The palette's "signature" color: its first clearly colored swatch.
        // Its hue names the family, so the title always points at a color
        // that is genuinely present — and at the main one.
        let signature = chromatic.first
```

- [ ] **Step 5: Drop filler words**

In `characterWords(for:)`, delete the line:

```swift
        words += ["Textured", "Woven", "Measured"]
```

The list is never empty without it: chromatic palettes always add warm or cool words, and neutral palettes add five.

In `closerWords(for:)`, replace `"Saffron"` with `"Hearth"`. Saffron is a yellow color word and contradicted red-family titles.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/PaletteNamerTests`
Expected: all PaletteNamerTests pass, including the 11 existing ones.

- [ ] **Step 7: Commit**

```bash
git add Palettes/Managers/PaletteNamer.swift PalettesTests/PaletteNamerTests.swift
git commit -m "fix: palette titles follow the main color and drop filler words

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Brief → build → names pipeline; remove the HSB planner

**Files:**
- Rewrite: `Palettes/Managers/PaletteGenerator.swift`
- Shrink: `Palettes/Managers/ColorHarmony.swift` (keep only `HarmonyScheme`)
- Delete: `Palettes/Managers/PaletteValidation.swift`, `PalettesTests/PaletteValidationTests.swift`, `PalettesTests/ColorHarmonyTests.swift`
- Rewrite: `PalettesTests/SchemeFidelityTests.swift`
- Modify: `PalettesTests/PaletteGeneratorTests.swift`, `Palettes/Utilities/HEXParser.swift` (one comment)

**Interfaces:**
- Consumes: Tasks 1–5
- Produces:
  - `PaletteGenerator.generate(baseColors:size:vibe:scheme:existingNames:onPartialColors:)` with an unchanged signature.
  - `PaletteGenerator.BaseColor`, unchanged.
  - `static func acceptedNames(_ proposals: [(number: Int, name: String)], hexes: [String], unnamed: [Int]) -> [Int: String]`.
  - `PaletteBrief.init(model: GeneratedBrief, vibe: String)` (iOS 26).
  - `@Generable` types `GeneratedBrief`, `BriefLightness`, `BriefSaturation`, `BriefHarmony`, `GeneratedNames` and `GeneratedColorName`. They replace `GeneratedPalette` and `GeneratedColor`.
- Callers that must keep compiling unchanged: `GenerateView.performGeneration`, `GeneratePaletteIntent.perform`.

- [ ] **Step 1: Update the generator tests (failing first)**

In `PalettesTests/PaletteGeneratorTests.swift`:

1. Delete these tests. They exercise `repairViolations` and `fillToTarget`, which this task removes:
   - `testRepairViolationsConvergesForAFixableCase`
   - `testRepairViolationsTerminatesAndAcceptsPaletteWhenUnresolvable`
   - `testRepairViolationsPadsWhenNoViolationsButShortOfTarget`
   - `testRepairViolationsFillsSingleValidColorToRequestedSizeWithoutThrowing`
   - `testRepairViolationsKeepsRolesAlignedAfterRemovingAColor`
   - `testRepairViolationsWithNoLockedColorsSuppressesRolesEvenWhenPlanFillTriggersNeutrals`
   - `testFillToTargetNeverAssignsADuplicateRoleOnPlanReplay`
   - `testRepairViolationsDoesNotInheritRolesFromAdHocPlanWhenBaseColorsPresent`
   - `testFillToTargetNeverAppendsAColorWithinMinDeltaEOfAnExisting`
   - `testFillToTargetStillReachesTargetWhenDistinctColorsAreAchievable`

   Also delete any `// MARK:` header left with no tests under it.
2. Replace `testGenerateSizeSixFromSaturatedBaseTagsBackgroundAndText` (and its doc comment) with:

```swift
    /// Harmonic palettes of 8 or more get two tinted neutrals tagged
    /// Background and Text, whichever scheme Auto resolves to.
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateSizeEightFromSaturatedBaseTagsBackgroundAndText() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: "#3060A0", name: "Ocean Blue")],
            size: 8,
            vibe: nil
        )
        let roles = Set(result.paletteColors.compactMap(\.role))
        XCTAssertEqual(result.paletteColors.first?.role, "Primary")
        XCTAssertTrue(roles.contains("Background"), "expected a Background role among \(roles)")
        XCTAssertTrue(roles.contains("Text"), "expected a Text role among \(roles)")
    }
```

3. Replace `testGeneratedPaletteOfEightHasAllPairsAtLeastMinDeltaEApart` (and its doc comment) with:

```swift
    /// No two colors in a generated palette read as the same: every pair
    /// is at least CIEDE2000 6 apart (palettes of up to 8 colors; only long
    /// monochromatic palettes may sit closer).
    @available(iOS 26.0, *)
    @MainActor
    func testGeneratedPaletteOfEightKeepsEveryPairDistinct() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 8, vibe: nil)
        let hexes = result.hexCodes
        XCTAssertEqual(hexes.count, 8)
        for i in hexes.indices {
            for j in hexes.indices where j > i {
                let distance = ColorNamer.perceptualDistance(hex1: hexes[i], hex2: hexes[j])
                XCTAssertGreaterThanOrEqual(distance, 6, "\(hexes[i]) and \(hexes[j]) are only ΔE \(distance) apart")
            }
        }
    }
```

4. Add at the end of the class:

```swift
    // MARK: - Brief, modes and names

    @available(iOS 26.0, *)
    @MainActor
    func testVibeColorWordSetsTheMainHue() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 6, vibe: "navy evening", scheme: .analogous)
        let main = OKLCH(hex: result.hexCodes[0])!
        XCTAssertLessThanOrEqual(OKLCH.hueDistance(main.h, 262), 5, "\(result.hexCodes)")
    }

    /// A mode chosen alongside a vibe (no colors selected) shapes the palette.
    @available(iOS 26.0, *)
    @MainActor
    func testChosenModeAppliesToAVibeOnlyPalette() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 6, vibe: "warm autumn forest", scheme: .monochromatic)
        let hue = OKLCH(hex: result.hexCodes[0])!.h
        for hex in result.hexCodes {
            let color = OKLCH(hex: hex)!
            guard color.C >= 0.04, color.L >= 0.2 else { continue }
            XCTAssertLessThanOrEqual(OKLCH.hueDistance(color.h, hue), 5, "\(hex) in \(result.hexCodes)")
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    func testInterfaceModeWithAVibeCarriesItsRoles() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 4, vibe: "calm ocean", scheme: .uiLight)
        XCTAssertEqual(result.paletteColors.map(\.role), ["Primary", "Background", "Text", "Accent"])
    }

    /// The model's names are matched by list number, never by position, and
    /// only ship when they fit their swatch.
    @available(iOS 26.0, *)
    func testModelNamesAreMatchedByNumberAndChecked() {
        let hexes = ["#2F6BD8", "#E2683C", "#F1F5FD", "#3E8E5E"]
        let accepted = PaletteGenerator.acceptedNames(
            [
                (number: 4, name: "Fern"),           // out of order: still lands on #3E8E5E
                (number: 2, name: "Blue Lagoon"),    // a blue name on an orange: rejected
                (number: 3, name: "Morning Frost"),  // fits a near-white
                (number: 1, name: "Harbor"),         // color 1 is the user's, already named
                (number: 9, name: "Nowhere"),        // there is no color 9
                (number: 2, name: "Fern"),           // a repeat: rejected
            ],
            hexes: hexes,
            unnamed: [1, 2, 3]
        )
        XCTAssertEqual(accepted, [3: "Fern", 2: "Morning Frost"])
    }
```

- [ ] **Step 2: Rewrite `PalettesTests/SchemeFidelityTests.swift`**

Replace the whole file. The `UIColor(hexForFidelity:)` helper that lived at its bottom goes with it; check that nothing else uses it (`grep -rn hexForFidelity PalettesTests`).

```swift
//
//  SchemeFidelityTests.swift
//  PalettesTests
//
//  End-to-end checks that a generated palette keeps the mode the user
//  picked. PaletteBuilderTests pins the builder over fixed seeds; these go
//  through `PaletteGenerator.generate` (the Simulator path, random seed) so
//  the wiring between the two is covered too.
//

import XCTest
@testable import Palettes

@available(iOS 26.0, *)
final class SchemeFidelityTests: XCTestCase {

    private let base = "#3366CC"

    private func generate(_ scheme: HarmonyScheme, size: Int, bases: [String]? = nil) async throws -> PaletteViewModel {
        try await PaletteGenerator.generate(
            baseColors: (bases ?? [base]).map { PaletteGenerator.BaseColor(hex: $0, name: "") },
            size: size,
            vibe: nil,
            scheme: scheme
        )
    }

    /// Every clearly colored swatch sits on one of its scheme's hues
    /// (OKLCH; greys and near-blacks skipped, their hue is rounding noise).
    @MainActor
    func testEverySchemeShipsOnlyInFamilyHues() async throws {
        let baseHue = OKLCH(hex: base)!.h
        for scheme in [HarmonyScheme.complementary, .splitComplementary, .analogous, .triadic, .monochromatic] {
            let offsets = [0] + PaletteBuilder.offsets(for: scheme)
            for size in [4, 6, 8, 12] {
                for _ in 0..<3 {
                    let palette = try await generate(scheme, size: size)
                    for hex in palette.hexCodes {
                        let color = OKLCH(hex: hex)!
                        guard color.C >= 0.04, color.L >= 0.2 else { continue }
                        let miss = offsets.map { OKLCH.hueDistance(color.h, baseHue + $0) }.min()!
                        XCTAssertLessThanOrEqual(miss, 5, "\(scheme) size \(size): \(hex) is \(miss)° off — \(palette.hexCodes)")
                    }
                }
            }
        }
    }

    @MainActor
    func testEverySchemeReachesTheRequestedSize() async throws {
        for scheme in HarmonyScheme.allCases {
            for size in [2, 4, 6, 8, 10, 12] {
                let palette = try await generate(scheme, size: size)
                XCTAssertEqual(palette.hexCodes.count, size, "\(scheme) size \(size)")
                XCTAssertEqual(palette.colorNames.count, size)
                XCTAssertEqual(palette.colorRoles.count, size)
                XCTAssertEqual(Set(palette.colorNames).count, size, "names must be unique: \(palette.colorNames)")
            }
        }
    }

    /// Two chosen colors split the generated tones evenly. This used to
    /// fail about one run in seven.
    @MainActor
    func testTwoSelectedBasesShareTheTonesEvenly() async throws {
        let bases = ["#3366CC", "#CC6633"]
        let hues = bases.map { OKLCH(hex: $0)!.h }
        for _ in 0..<10 {
            // Size 8 monochromatic: 2 bases + 4 tones + 2 neutrals (low chroma, skipped).
            let palette = try await generate(.monochromatic, size: 8, bases: bases)
            var shares = [0, 0]
            for hex in palette.hexCodes.dropFirst(2) {
                let color = OKLCH(hex: hex)!
                guard color.C >= 0.03 else { continue }
                shares[OKLCH.hueDistance(color.h, hues[0]) < OKLCH.hueDistance(color.h, hues[1]) ? 0 : 1] += 1
            }
            XCTAssertEqual(shares, [2, 2], "\(palette.hexCodes)")
        }
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/PaletteGeneratorTests -only-testing:PalettesTests/SchemeFidelityTests`
Expected: build failure, `type 'PaletteGenerator' has no member 'acceptedNames'`.

- [ ] **Step 4: Rewrite `Palettes/Managers/PaletteGenerator.swift`**

Replace the whole file:

```swift
//
//  PaletteGenerator.swift
//  Palettes
//
//  Generation in three steps:
//   1. Brief — the on-device model reads the vibe into a main color word,
//      a tone and a harmony (`GeneratedBrief`). It never picks color values.
//   2. Build — `PaletteBuilder` makes every color, deterministically.
//   3. Names — the model names each color from a plain description that
//      code writes from the swatch (`ColorVocabulary.describe`). Names are
//      matched back by list number and must pass
//      `ColorVocabulary.isPlausible`; the color dictionary fills any gap.
//  A model failure falls back (heuristic brief, dictionary names), so only
//  cancellation or an unavailable model stops a generation.
//

import Foundation
import SwiftUI
import FoundationModels
import os

// MARK: - Guided generation types

@available(iOS 26.0, *)
@Generable
enum BriefLightness {
    case light, balanced, dark
}

@available(iOS 26.0, *)
@Generable
enum BriefSaturation {
    case muted, balanced, vivid
}

@available(iOS 26.0, *)
@Generable
enum BriefHarmony {
    case analogous, complementary, splitComplementary, triadic, monochromatic
}

@available(iOS 26.0, *)
@Generable
struct GeneratedBrief {
    @Guide(description: "One plain color word for the vibe's main color, such as terracotta, navy, sage, mustard or plum")
    var mainColor: String

    @Guide(description: "How light or dark the palette should feel overall")
    var lightness: BriefLightness

    @Guide(description: "How muted or vivid the palette's colors should be")
    var saturation: BriefSaturation

    @Guide(description: "The color harmony that best suits the vibe")
    var harmony: BriefHarmony
}

@available(iOS 26.0, *)
@Generable
struct GeneratedColorName {
    @Guide(description: "The number of the color in the list")
    var number: Int

    @Guide(description: "A short, evocative name of one to three words that fits the color's description")
    var name: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedNames {
    @Guide(description: "A specific two or three word title for this palette, drawn from its colors or mood, for example 'Harbor Dusk' or 'Terracotta Bloom'. Never generic: do not use the words palette, colors, scheme, theme, custom, generated, whisper, horizon, harmony, dream, or serene.")
    var title: String

    @Guide(description: "One name for every color in the list")
    var colors: [GeneratedColorName]
}

@available(iOS 26.0, *)
extension PaletteBrief {
    /// The model's brief in builder terms. A main color word that neither
    /// the vocabulary nor the dictionary knows keeps the vibe's own reading.
    init(model: GeneratedBrief, vibe: String) {
        let lightness: PaletteTone.Lightness
        switch model.lightness {
        case .light: lightness = .light
        case .balanced: lightness = .balanced
        case .dark: lightness = .dark
        }
        let chroma: PaletteTone.Chroma
        switch model.saturation {
        case .muted: chroma = .muted
        case .balanced: chroma = .balanced
        case .vivid: chroma = .vivid
        }
        let scheme: HarmonyScheme
        switch model.harmony {
        case .analogous: scheme = .analogous
        case .complementary: scheme = .complementary
        case .splitComplementary: scheme = .splitComplementary
        case .triadic: scheme = .triadic
        case .monochromatic: scheme = .monochromatic
        }
        self.init(
            hue: PaletteBrief.hue(forColorWord: model.mainColor) ?? PaletteBrief.heuristic(from: vibe).hue,
            tone: PaletteTone(lightness: lightness, chroma: chroma),
            scheme: scheme
        )
    }
}

// MARK: - Generator

/// Generates palettes on device. The model reads the vibe and names the
/// colors; `PaletteBuilder` makes them.
@available(iOS 26.0, *)
enum PaletteGenerator {

    struct BaseColor {
        let hex: String
        let name: String
    }

    /// Generates a palette, streaming its colors to `onPartialColors` one at
    /// a time for the generation orb. The streamed colors are the final
    /// ones: the builder knows them before the model names them.
    /// - Parameter existingNames: names already in the user's library, so
    ///   the generated palette's title stays distinct from them.
    static func generate(
        baseColors: [BaseColor],
        size: Int,
        vibe: String?,
        scheme: HarmonyScheme = .auto,
        existingNames: [String] = [],
        onPartialColors: (@MainActor ([Color]) -> Void)? = nil
    ) async throws -> PaletteViewModel {
        #if !targetEnvironment(simulator)
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppError.aiUnavailable
        }
        #endif

        // The user's chosen colors are locked: they ship verbatim, in order.
        let locked = lockedEntries(from: baseColors)
        let targetCount = max(size, locked.count)
        guard targetCount >= 2 else { throw AppError.generationFailed }
        let trimmedVibe = vibe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 1. Brief.
        let brief = trimmedVibe.isEmpty ? PaletteBrief.neutral : await makeBrief(vibe: trimmedVibe)
        try Task.checkCancellation()

        // The user's mode always wins. Auto follows the brief's harmony,
        // unless two or more chosen colors already imply one.
        var resolvedScheme = scheme
        if scheme == .auto, locked.count < 2, let suggested = brief.scheme {
            resolvedScheme = suggested
        }

        // 2. Build.
        let built = PaletteBuilder.build(PaletteBuildRequest(
            anchors: locked.map(\.hex),
            size: targetCount,
            scheme: resolvedScheme,
            tone: brief.tone,
            hue: brief.hue,
            seed: UInt64.random(in: .min ... .max)
        ))
        let hexCodes = built.hexes
        let colors = hexCodes.compactMap { Color(hex: $0) }
        guard colors.count == hexCodes.count, colors.count >= 2 else { throw AppError.generationFailed }

        // 3. Names, requested while the orb shows the colors arriving. The
        //    user's own names are kept; the rest come from the model.
        let userNames = Dictionary(locked.map { ($0.hex, $0.name) }, uniquingKeysWith: { first, _ in first })
        var preferred: [String?] = hexCodes.map { hex in
            guard let name = userNames[hex], !name.isEmpty else { return nil }
            return name
        }
        let unnamed = hexCodes.indices.filter { preferred[$0] == nil }
        async let naming = modelNames(hexes: hexCodes, unnamed: unnamed, vibe: trimmedVibe.isEmpty ? nil : trimmedVibe)

        if let onPartialColors {
            let firstGenerated = min(locked.count, colors.count)
            if firstGenerated == colors.count {
                // Nothing to reveal one by one (e.g. a photo palette): show it whole.
                await MainActor.run { onPartialColors(colors) }
            }
            for index in firstGenerated..<colors.count {
                try await Task.sleep(for: .milliseconds(700))
                let preview = Array(colors.prefix(index + 1))
                await MainActor.run { onPartialColors(preview) }
            }
        }

        let names = await naming
        try Task.checkCancellation()
        for (index, name) in names.colorNames {
            preferred[index] = name
        }

        return PaletteViewModel(
            // The model's title is kept only when it's specific, names only
            // colors the palette has, and is unused; otherwise a descriptive
            // title is derived from the palette's main color.
            name: PaletteNamer.resolvedName(aiName: names.title, hexes: hexCodes, existingNames: existingNames),
            colors: colors,
            hexCodes: hexCodes,
            colorNames: ColorNamer.uniqueNames(forHexes: hexCodes, preferred: preferred),
            colorRoles: built.roles
        )
    }

    // MARK: - Locked base colors

    private struct LockedColor {
        let hex: String   // normalized "#RRGGBB"
        let name: String
    }

    /// Normalizes and de-duplicates the user's chosen colors, preserving
    /// order. `name` stays the user's own text (or empty); the final
    /// `ColorNamer.uniqueNames` pass fills in any empty name.
    private static func lockedEntries(from baseColors: [BaseColor]) -> [LockedColor] {
        var result: [LockedColor] = []
        var seen = Set<String>()
        for base in baseColors {
            var hex = base.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard Color(hex: hex) != nil, seen.insert(hex).inserted else { continue }
            let name = base.name.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LockedColor(hex: hex, name: name))
        }
        return result
    }

    // MARK: - Model steps

    private static let logger = Logger(subsystem: "com.halilbagosi.Palettes", category: "generation")

    /// Reads the vibe into a brief. On the Simulator, or when the model
    /// fails, the vibe's own words are read instead.
    private static func makeBrief(vibe: String) async -> PaletteBrief {
        #if targetEnvironment(simulator)
        return PaletteBrief.heuristic(from: vibe)
        #else
        do {
            let session = LanguageModelSession(instructions: """
                You are a color designer. Read the mood or theme someone describes and \
                decide what its color palette should be like. Answer only with the fields asked for.
                """)
            let response = try await session.respond(
                to: "Describe the palette for this vibe: \(vibe)",
                generating: GeneratedBrief.self
            )
            return PaletteBrief(model: response.content, vibe: vibe)
        } catch is CancellationError {
            return PaletteBrief.heuristic(from: vibe)
        } catch {
            logFailure(error, step: "brief")
            return PaletteBrief.heuristic(from: vibe)
        }
        #endif
    }

    private struct Naming {
        var title: String?
        var colorNames: [Int: String]
    }

    /// Asks the model for a title and for names of the colors at `unnamed`.
    /// Every color is described in words, so the model never names from a
    /// hex code; its answers are matched back by number, not position.
    private static func modelNames(hexes: [String], unnamed: [Int], vibe: String?) async -> Naming {
        #if targetEnvironment(simulator)
        return Naming(title: nil, colorNames: [:])
        #else
        let list = hexes.indices
            .map { "\($0 + 1). \(ColorVocabulary.describe(hex: hexes[$0]))" }
            .joined(separator: "\n")
        let theme = vibe.map { " inspired by \"\($0)\"" } ?? ""
        let prompt = """
            Name each color in this palette\(theme), and give the palette a title. \
            Each name must fit its description: never call a light color dark, a grey \
            colorful, or one hue by another hue's name.
            \(list)
            """
        do {
            let session = LanguageModelSession(instructions: """
                You name colors for a design app. Use concrete, evocative names drawn from \
                materials, places, food and nature, one to three words each. Never repeat a \
                name, and never use the words color, shade, tone or palette in a name.
                """)
            let response = try await session.respond(to: prompt, generating: GeneratedNames.self)
            let proposals = response.content.colors.map { (number: $0.number, name: $0.name) }
            return Naming(
                title: response.content.title,
                colorNames: acceptedNames(proposals, hexes: hexes, unnamed: unnamed)
            )
        } catch is CancellationError {
            return Naming(title: nil, colorNames: [:])
        } catch {
            logFailure(error, step: "names")
            return Naming(title: nil, colorNames: [:])
        }
        #endif
    }

    /// The model's names that can ship: matched to colors by list number
    /// (1-based), only for colors that still need a name, and only when the
    /// name fits its swatch and doesn't repeat one already accepted.
    /// Outside the Simulator gate so tests can exercise it.
    static func acceptedNames(_ proposals: [(number: Int, name: String)], hexes: [String], unnamed: [Int]) -> [Int: String] {
        let needed = Set(unnamed)
        var accepted: [Int: String] = [:]
        var used = Set<String>()
        for proposal in proposals {
            let index = proposal.number - 1
            let name = proposal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard needed.contains(index),
                  accepted[index] == nil,
                  ColorVocabulary.isPlausible(name: name, forHex: hexes[index]),
                  used.insert(name.lowercased()).inserted else { continue }
            accepted[index] = name
        }
        return accepted
    }

    /// Type name only: an error's description can echo prompt or model
    /// content, which must never reach device logs.
    private static func logFailure(_ error: Error, step: String) {
        logger.error("Palette \(step, privacy: .public) failed: \(String(describing: type(of: error)), privacy: .public)")
    }
}
```

- [ ] **Step 5: Shrink `Palettes/Managers/ColorHarmony.swift` to the mode enum**

Replace the whole file with the following. The `HarmonyScheme` body is unchanged; everything else is deleted:

```swift
//
//  ColorHarmony.swift
//  Palettes
//
//  The palette modes a user can pick. `PaletteBuilder` builds them.
//

import Foundation

/// A named color-harmony scheme, plus `.auto` (which `PaletteBuilder`
/// resolves to a concrete harmonic scheme) and the two interface modes.
enum HarmonyScheme: String, CaseIterable, Identifiable {
    case auto, complementary, splitComplementary, analogous, triadic, monochromatic, uiLight, uiDark

    var id: String { rawValue }

    var isUIMode: Bool {
        self == .uiLight || self == .uiDark
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .complementary: return "Complementary"
        case .splitComplementary: return "Split Complementary"
        case .analogous: return "Analogous"
        case .triadic: return "Triadic"
        case .monochromatic: return "Monochromatic"
        case .uiLight: return "UI Light"
        case .uiDark: return "UI Dark"
        }
    }
}
```

- [ ] **Step 6: Delete the old planner's leftovers**

```bash
git rm Palettes/Managers/PaletteValidation.swift PalettesTests/PaletteValidationTests.swift PalettesTests/ColorHarmonyTests.swift
```

In `Palettes/Utilities/HEXParser.swift`, find the comment that reads "Chosen well under `PaletteValidation.minDeltaE` (12) so a". Change it to "Chosen well under the palette builder's distinctness floor (12) so a".

Then confirm nothing references the removed code:

```bash
grep -rn "PaletteValidation\|HarmonyPlan\|HarmonySlot\|ColorHarmony\.\|repairViolations\|fillToTarget\|GeneratedPalette\b\|GeneratedColor\b" Palettes PalettesTests
```

Expected: no output.

- [ ] **Step 7: Build, then run the generation tests**

Run the build. Expected: success, zero warnings.
Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -only-testing:PalettesTests/PaletteGeneratorTests -only-testing:PalettesTests/SchemeFidelityTests -only-testing:PalettesTests/PaletteBuilderTests`
Expected: all pass. The preview test (`testGenerationPreviewMatchesTheFinalPaletteImmediately`) still sees exactly `count - 1` previews.

- [ ] **Step 8: Run the full suite**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>"`
Expected: everything passes. The two old flaky tests no longer exist; their replacements (`testTwoAnchorsShareTheTonesEvenly`, `testTwoSelectedBasesShareTheTonesEvenly`, `testEverySchemeStaysOnItsHues`) hold for every seed. Run the suite a second time to confirm it is stable.

- [ ] **Step 9: Commit**

```bash
git add -A Palettes PalettesTests
git commit -m "feat: generate palettes as brief, deterministic build, checked names; remove HSB planner

The model now reads the vibe into a brief and names colors from written
descriptions; PaletteBuilder makes every color. Removes ColorHarmony.plan,
fillToTarget, repairViolations and PaletteValidation, and with them the
two flaky SchemeFidelity tests.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Modes with a vibe in the UI; even sizes for Siri

**Prerequisite:** the "generation options" rework of `GenerateView.swift` (Palette Size and Mode menus, `canGenerateFromSource`) is currently uncommitted on `dev` in the main checkout. Before starting, confirm it is committed and present on this branch: `grep -n "generationOptionsSection" Palettes/Views/Color/GenerateView.swift` must print a match. If it doesn't, stop and report BLOCKED. Do not recreate that work.

**Files:**
- Modify: `Palettes/Views/Color/GenerateView.swift`
- Modify: `Palettes/Intents/GeneratePaletteIntent.swift`

**Interfaces:**
- Consumes: `PaletteGenerator.generate`, unchanged.

- [ ] **Step 1: Let the Mode menu appear with a vibe alone**

In `GenerateView.swift`, add this next to `canGenerateFromSource`:

```swift
    /// Modes shape every generation now, including one from a vibe alone.
    private var canChooseMode: Bool {
        canGenerateFromSource || !vibeDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }
```

In `generationOptionsSection`, change the condition around the Mode `Menu` from `if canGenerateFromSource {` to `if canChooseMode {`. Change the section's `.animation(…, value: canGenerateFromSource)` to `value: canChooseMode`.

- [ ] **Step 2: Stop resetting the mode, and ignore it when it is hidden**

Delete the `.onChange(of: selectedColorIDs) { _, ids in … if ids.isEmpty { scheme = .auto } }` modifier and its comment. Deselecting the last color no longer makes the mode meaningless.

In `performGeneration`, pass the mode only while the menu is visible, so a hidden choice never applies silently:

```swift
            scheme: canChooseMode ? scheme : .auto,
```

Leave `resetForm()`'s `scheme = .auto` as it is.

- [ ] **Step 3: Even sizes for the Siri intent**

In `GeneratePaletteIntent.swift`, change the size parameter:

```swift
    @Parameter(title: "Number of Colors", default: 6, controlStyle: .stepper, inclusiveRange: (2, 12))
    var size: Int
```

In `perform()`, round up to an even size:

```swift
        // Palettes come in even sizes (2–12), matching the in-app picker.
        let evenSize = min(12, max(2, size + size % 2))
        let generated = try await PaletteGenerator.generate(
            baseColors: [],
            size: evenSize,
            vibe: vibe,
            scheme: .auto,
            existingNames: AppData.shared.palettes.map { $0.name }
        )
```

- [ ] **Step 4: Build and check in the Simulator**

Build. Expected: success, zero warnings. Then run the app in the Simulator:
1. On Generate, with no colors selected, type a vibe. The Mode menu appears.
2. Choose UI Light and generate. The palette shows Primary, Background, Text and Accent roles, with a near-white background and a dark text color.
3. Clear the vibe. The Mode menu hides.
4. Select a color and choose Monochromatic. The palette is tones of that color plus near-neutrals.

Take a screenshot of each step for the report.

- [ ] **Step 5: Run the full suite**

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Palettes/Views/Color/GenerateView.swift Palettes/Intents/GeneratePaletteIntent.swift
git commit -m "feat: choose a palette mode with a vibe; Siri generates even sizes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## After the tasks

- Add plan 013's row to `plans/README.md` on this branch, marked DONE.
- Run `graphify update .` to refresh the code graph.
- **On a device with Apple Intelligence** (the Simulator never calls the model), generate several palettes with vibes and check:
  - The brief reads the vibe sensibly.
  - Names fit their swatches.
  - Titles name colors that are present.
  - Generation stays fast. There are two short model calls, and the name call runs while the orb shows the colors arriving.

## Out of scope

- **Paywall size caps:** free users get 2/4/6 colors and Pro gets 8/10/12. The Siri intent allows up to 12 until the paywall exists.
- **Rewording the Generate screen's copy.**
- **Re-generating names for palettes already saved.**
