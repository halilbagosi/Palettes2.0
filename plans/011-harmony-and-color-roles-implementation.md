# Harmony Generation & Color Roles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `plans/010-harmony-and-color-roles-design.md` — read it first; it is the authority on behavior.

**Goal:** Theory-guided complementary palette generation (with scheme override), UI/UX role tags on palette colors (defaults + app-wide custom tags) driving exports and search, vibe post-validation, and Lab-based image color extraction that no longer misses small vivid accents.

**Architecture:** A pure-math `ColorHarmony` engine feeds `PaletteGenerator` (AI polishes deterministic slot targets) and auto-assigns roles. Roles live as `String?` on `PaletteColor`, persisted as an index-aligned `colorRoles: [String]` on `StoredPalette` (CloudKit-safe inline defaults). Extraction moves k-means into Lab space with salience ranking.

**Tech Stack:** Swift / SwiftUI, SwiftData + CloudKit, FoundationModels (iOS 26 gated), XCTest.

## Global Constraints

- Deployment target iOS 17.0; anything touching FoundationModels/Liquid Glass stays behind `@available(iOS 26.0, *)` (existing pattern in `PaletteGenerator.swift`).
- SwiftData models: **no unique constraints, every stored property has an inline default** (CloudKit requirement — see header of `Palettes/App/PersistentStore.swift`).
- Never hand-edit `Palettes.xcodeproj` — new files are auto-included via synchronized groups.
- All palette/color reads and writes go through `AppData`; never touch SwiftData directly from views.
- `PaletteViewModel` zip-init must keep padding missing per-index data (hex/name/role) so array lengths can never desync.
- Build/test (per user environment): resolve a simulator with `xcrun simctl list devices available`, then
  `env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,id=<SIM_ID>"`.
  For a single test class add `-only-testing:PalettesTests/<ClassName>`.
- Git: work happens on `feature/harmony-and-color-roles` branched off `dev` (Task 0). Commit after every task; never commit to `main`.
- After each task, run `graphify update .` (AST-only, free) to keep the knowledge graph current.

---

### Task 0: Branch setup

**Files:** none (git only)

- [ ] **Step 1: Create the feature branch off dev**

```bash
git checkout dev && git pull && git checkout -b feature/harmony-and-color-roles
git cherry-pick 2e33b0a 14f937e 284ebcc 2>/dev/null || true  # bring spec/plan docs over if dev lacks them; skip conflicts by copying plans/010* and plans/011* from feature/fullscreen-photo-picker instead
git log --oneline -3
```

If the cherry-picks conflict or the docs are missing, copy `plans/010-harmony-and-color-roles-design.md` and `plans/011-harmony-and-color-roles-implementation.md` from `feature/fullscreen-photo-picker` (`git checkout feature/fullscreen-photo-picker -- plans/010-harmony-and-color-roles-design.md plans/011-harmony-and-color-roles-implementation.md`) and commit them.

---

### Task 1: ColorRole model + role on PaletteColor + persistence

**Files:**
- Create: `Palettes/Models/ColorRole.swift`
- Modify: `Palettes/ViewModels/PaletteViewModel.swift`
- Modify: `Palettes/App/PersistentStore.swift` (StoredPalette)
- Modify: `Palettes/App/AppData.swift` (`persistPalettes` ~L287, `load` ~L167 / palette hydration)
- Test: `PalettesTests/ColorRoleTests.swift`, extend `PalettesTests/AppDataPersistenceTests.swift`

**Interfaces:**
- Produces: `ColorRole` (struct, `name: String`, computed `slug: String`), `ColorRole.defaults: [ColorRole]` (Primary, Secondary, Accent, Background, Surface, Text, Error, Success, Warning, Border — in that order), `PaletteColor.role: String?`, `PaletteViewModel.colorRoles: [String]` (empty string = untagged, index-aligned), zip-init parameter `colorRoles: [String] = []`, `StoredPalette.colorRoles: [String] = []`.
- Consumes: existing `PaletteColor`, `StoredPalette`, `AppData.persistPalettes`.

- [ ] **Step 1: Write failing tests**

```swift
// PalettesTests/ColorRoleTests.swift
import XCTest
@testable import Palettes

final class ColorRoleTests: XCTestCase {
    func testDefaultRolesOrderAndSlugs() {
        XCTAssertEqual(ColorRole.defaults.map(\.name),
            ["Primary", "Secondary", "Accent", "Background", "Surface", "Text", "Error", "Success", "Warning", "Border"])
        XCTAssertEqual(ColorRole(name: "Primary").slug, "primary")
        XCTAssertEqual(ColorRole(name: "Brand Blue 2").slug, "brand-blue-2")
    }

    func testViewModelZipInitPadsRoles() {
        let vm = PaletteViewModel(name: "P",
                                  colors: [.red, .blue, .green],
                                  hexCodes: ["#FF0000", "#0000FF", "#00FF00"],
                                  colorNames: ["R", "B", "G"],
                                  colorRoles: ["Primary", ""])   // shorter than colors
        XCTAssertEqual(vm.paletteColors[0].role, "Primary")
        XCTAssertNil(vm.paletteColors[1].role)   // empty string → nil
        XCTAssertNil(vm.paletteColors[2].role)   // missing → nil
        XCTAssertEqual(vm.colorRoles, ["Primary", "", ""])   // always full length
    }
}
```

Also extend `AppDataPersistenceTests` with a round-trip: save a palette whose second color has role "Accent", reload via a fresh `AppData` on the same container (follow the existing test pattern in that file), assert `palettes[0].paletteColors[1].role == "Accent"`. Include a legacy-record case: a `StoredPalette` inserted with `colorRoles: []` hydrates to all-`nil` roles.

- [ ] **Step 2: Run tests, verify they fail** (`-only-testing:PalettesTests/ColorRoleTests`) — expected: compile errors (`ColorRole` undefined, no `colorRoles` parameter).

- [ ] **Step 3: Implement**

```swift
// Palettes/Models/ColorRole.swift
import Foundation

/// A UI/UX role a palette color can be tagged with (one per color).
/// Stored on colors as the plain `name` string; `slug` is derived for exports.
struct ColorRole: Hashable, Identifiable {
    let name: String
    var id: String { name.lowercased() }

    /// Kebab-case identifier, e.g. "Brand Blue 2" → "brand-blue-2".
    var slug: String {
        var result = ""
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber { result.append(ch) }
            else if ch == " " || ch == "-" || ch == "_" { result.append("-") }
        }
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        while result.hasPrefix("-") { result.removeFirst() }
        while result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "color" : result
    }

    static let defaults: [ColorRole] = ["Primary", "Secondary", "Accent", "Background",
                                        "Surface", "Text", "Error", "Success", "Warning", "Border"].map(ColorRole.init)
}
```

In `PaletteViewModel.swift`: add `var role: String? = nil` to `PaletteColor`; add `var colorRoles: [String] { paletteColors.map { $0.role ?? "" } }`; add `colorRoles: [String] = []` parameter to the zip-init and map `let roleRaw = index < colorRoles.count ? colorRoles[index] : ""` → `role: roleRaw.isEmpty ? nil : roleRaw`.

In `PersistentStore.swift`: add `var colorRoles: [String] = []` to `StoredPalette` plus an `colorRoles: [String] = []` init parameter (keep inline default — CloudKit rule).

In `AppData.swift`: in `persistPalettes` mirror the `hexCodes` handling (`if stored.colorRoles != palette.colorRoles { stored.colorRoles = palette.colorRoles }`, pass in insert); in the load/hydration path pass `colorRoles: stored.colorRoles` into the `PaletteViewModel` zip-init.

- [ ] **Step 4: Run tests, verify pass** (ColorRoleTests + AppDataPersistenceTests + PaletteViewModelTests — the last must stay green untouched).

- [ ] **Step 5: Commit** — `feat: add ColorRole model and role persistence on palette colors`

---

### Task 2: ColorHarmony engine

**Files:**
- Create: `Palettes/Managers/ColorHarmony.swift`
- Test: `PalettesTests/ColorHarmonyTests.swift`

**Interfaces:**
- Produces:

```swift
enum HarmonyScheme: String, CaseIterable, Identifiable {
    case auto, complementary, splitComplementary, analogous, triadic, monochromatic
    var id: String { rawValue }
    var displayName: String   // "Auto", "Complementary", "Split Complementary", ...
}

struct HarmonySlot: Equatable {
    let hue: CGFloat; let saturation: CGFloat; let brightness: CGFloat
    let role: String?                 // suggested ColorRole name
    var hex: String                   // computed "#RRGGBB" from HSB
}

struct HarmonyPlan: Equatable {
    let resolvedScheme: HarmonyScheme // never .auto
    let slots: [HarmonySlot]          // exactly `size - baseCount` (min 0)
    let roleForBase: [String?]        // one entry per (deduped) base color
}

enum ColorHarmony {
    static func plan(baseHexes: [String], size: Int, scheme: HarmonyScheme, seed: UInt64) -> HarmonyPlan
}
```

- Consumes: `Color(hex:)` from `Color+Extensions.swift` is NOT used — work in pure HSB/hex math (use `UIColor` for HSB↔RGB like `PaletteGenerator.fillToTarget` does) so tests need no SwiftUI rendering.

- [ ] **Step 1: Write failing tests** — cover, with a fixed seed:
  - `complementary` from `#FF0000` (hue 0): first slot hue within 180°±8° of base.
  - `splitComplementary`: slots near 150° and 210° offsets.
  - `analogous`: all slot hues within 40° of base. `triadic`: ±120°. `monochromatic`: all hues within 8° of base, brightness values spread ≥ 0.3.
  - Determinism: same inputs + seed → identical plan; different seed → different slot values.
  - Auto heuristics (one test each, mirroring spec §1): near-neutral base (`#808080`, sat < 0.12) → `.monochromatic` with exactly one slot of saturation ≥ 0.5 (the accent); two bases ~180° apart → complementary family; two bases ≤ 40° apart → `.analogous`; single saturated base size 6 → `.splitComplementary` **and** contains a slot with role "Background" (sat ≤ 0.08, brightness ≥ 0.94) and one with role "Text" (brightness ≤ 0.22).
  - Roles: `roleForBase[0] == "Primary"`, second base → "Secondary"; a saturated non-neutral slot carries "Accent".
  - Sizing: `slots.count == max(0, size - baseHexes.count)` after dedup; `size ≤ baseCount` → empty slots.
  - Jitter bounds: over 20 seeds, every complementary slot hue stays within 180°±6° + tolerance (assert ±8° window), saturation/brightness within spec jitter of targets.

- [ ] **Step 2: Run, verify failure** (compile error: `ColorHarmony` undefined).

- [ ] **Step 3: Implement** `ColorHarmony.swift`. Structure:
  - `SplitMix64` local PRNG struct (deterministic from seed; do NOT use `SystemRandomNumberGenerator`).
  - Parse base hexes → HSB via `UIColor` (normalize like `PaletteGenerator.lockedEntries`: trim, uppercase, add `#`, dedup preserving order).
  - `resolveScheme(bases:size:rng:)` implementing spec §1 heuristics exactly (thresholds: neutral sat < 0.12; adjacent ≤ 40°; opposite = within 30° of 180°; size ≥ 5 reserves light+dark neutral slots; single saturated base size ≤ 4 picks complementary or analogous from rng).
  - Target hue offsets per scheme: complementary [180°]; split [150°, 210°]; analogous [±20°, ±40°]; triadic [120°, 240°]; monochromatic [0°] with brightness ladder [0.25, 0.45, 0.65, 0.85, 0.95] cycling. Cycle offsets when slots > offsets, varying brightness ±0.15 per lap.
  - Jitter per slot from rng: hue ±6/360, sat ±0.06, brightness ±0.05; clamp sat 0.05…1, brightness 0.08…0.97.
  - Role assignment: bases → Primary, Secondary, then nil; slots → first complement-family slot "Accent", reserved light neutral "Background", dark neutral "Text", remainder nil.
  - `HarmonySlot.hex` via `UIColor(hue:saturation:brightness:alpha:)` → `String(format: "#%02X%02X%02X", …)` (same conversion as `fillToTarget`).

- [ ] **Step 4: Run ColorHarmonyTests, verify pass.**
- [ ] **Step 5: Commit** — `feat: add ColorHarmony engine (schemes, auto-pick, seeded jitter, role slots)`

---

### Task 3: Shared Lab helpers + image extraction improvements

**Files:**
- Modify: `Palettes/Utilities/HEXParser.swift` (~L489 `sRGBtoLab` — widen access, keep private CIEDE2000 usage intact)
- Modify: `Palettes/Utilities/ImageColorExtractor.swift` (`extractColors` L38-72, `kMeansPP` L218+, keep `extractDominantRGB`/`PixelSampler` behavior)
- Test: extend `PalettesTests/ImageColorSampleTests.swift`

**Interfaces:**
- Produces: `ColorNamer.sRGBtoLab(r:g:b:) -> (L: Double, a: Double, b: Double)` becomes `static` **internal** (rename call sites only if needed); new internal `ColorNamer.labChroma(_ lab:) -> Double` (`sqrt(a² + b²)`). `ImageColorExtractor.extractColors(from:count:)` signature unchanged.
- Consumes: `ColorNamer.perceptualDistance(hex1:hex2:)` (existing).

- [ ] **Step 1: Write failing tests** (helpers to build `UIImage` from solid rects with `UIGraphicsImageRenderer` likely already exist in `ImageColorSampleTests` — reuse):
  - **Small accent survives:** 200×200 image, all `#8A8A80` (muted) except a 30×20 patch (3% area) of `#FF3B30`; `extractColors(count: 4)` must include a color within ΔE 12 of `#FF3B30`.
  - **Lab separation:** half `#2C3E50`, half `#34495E`-like RGB-close-but-distinct pair replaced by a perceptually distinct pair (e.g. `#4A6FA5` vs `#4AA56F`); both must appear for `count: 4`.
  - **Speckle rejected:** single 1×1-ish patch (< 0.5% area at working resolution — use a 2×2 patch on 200×200 ≈ 0.01%) of `#FF00FF` on `#777777`; result must NOT contain a color within ΔE 12 of `#FF00FF`.
  - Assert existing dominant-color tests still pass unchanged.

- [ ] **Step 2: Run, verify the new tests fail** (accent/separation cases fail against current RGB size-ranked clustering).

- [ ] **Step 3: Implement:**
  - `HEXParser.swift`: change `private static func sRGBtoLab` to `static func sRGBtoLab`; add `static func labChroma(_ lab: (L: Double, a: Double, b: Double)) -> Double { (lab.a * lab.a + lab.b * lab.b).squareRoot() }`.
  - `ImageColorExtractor.extractColors`: sample at `size = 160`; map pixels → Lab (`ColorNamer.sRGBtoLab(r: px.r/255, g: px.g/255, b: px.b/255)`); run k-means in Lab (add a Lab-space variant of `kMeansPP` operating on `(L, a, b)` triples with the same deterministic init — generalize the existing function over a 3-component tuple rather than duplicating); track cluster pixel counts.
  - Per cluster: `share = count / totalPixels`; drop `share < 0.005`; `salience = share * (0.5 + min(1, labChroma(centroid) / 100))`; sort clusters by salience descending.
  - Convert winning centroids Lab → sRGB (add internal `ColorNamer.labToSRGB(_:) -> (r: Double, g: Double, b: Double)` — inverse of the existing forward transform, D65, clamp 0…1) → hex.
  - Dedup: keep ΔE < 10 merge, but iterate in salience order so the higher-salience survivor wins (current loop order already achieves this once sorted by salience).
  - `extractDominantRGB` keeps 80×80 RGB path untouched.

- [ ] **Step 4: Run full ImageColorSampleTests, verify pass.**
- [ ] **Step 5: Commit** — `feat: Lab-space salience-ranked image color extraction`

---

### Task 4: Generator integration — harmony plan, scheme param, vibe post-validation

**Files:**
- Modify: `Palettes/Managers/PaletteGenerator.swift` (generate L47, fillToTarget L186, mock L221, instructions/prompt L62-87)
- Create: `Palettes/Managers/PaletteValidation.swift` (pure, no iOS-26 gate — testable)
- Test: `PalettesTests/PaletteValidationTests.swift`
- Modify: call sites of `PaletteGenerator.generate` (find via `graphify query "who calls PaletteGenerator.generate"`; expected: `GenerateView.swift`) — pass `scheme: .auto` for now.

**Interfaces:**
- Produces:

```swift
enum PaletteValidation {
    static let minDeltaE: Double = 12
    static let minBrightnessSpan: Double = 0.35   // for size >= 4
    /// Returns indices (excluding locked prefix) that violate distinctness/brightness rules.
    static func violations(hexCodes: [String], lockedCount: Int) -> [Int]
}
// PaletteGenerator.generate gains: scheme: HarmonyScheme = .auto
// fillToTarget gains: plan: HarmonyPlan? = nil (slots consumed in order before rotation fallback)
```

- Consumes: `ColorHarmony.plan`, `ColorNamer.perceptualDistance`, `HarmonySlot.hex`.

- [ ] **Step 1: Write failing PaletteValidationTests** — too-similar pair (`#FF0000`, `#FE0102`) flags the later, non-locked index; locked colors never flagged even if similar; all-midtone 4-color palette (brightness span < 0.35) flags the index whose removal lets a light/dark repair enter (assert at least one violation); distinct + spread palette → `[]`.
- [ ] **Step 2: Run, verify fail.** Implement `PaletteValidation` (brightness via `UIColor(hex→RGB).getHue`; iterate pairs, later non-locked index loses). **Run, verify pass. Commit** — `feat: palette post-validation rules`.
- [ ] **Step 3: Integrate in `generate`:**
  - New parameter `scheme: HarmonyScheme = .auto`; `let seed = UInt64.random(in: .min ... .max)`.
  - No-vibe + bases path: `let plan = ColorHarmony.plan(baseHexes: locked.map(\.hex), size: size, scheme: scheme, seed: seed)`; prompt lists each slot target hex with "refine each target only slightly (keep within about 8 degrees of its hue) and give every color an evocative name"; keep locked-colors wording.
  - Vibe path: rewrite `instructions` per spec §2 (harmony strategy naming, lightness spread for size ≥ 4, neighbor distinctness, prefer saturated accents); mention non-auto scheme in prompt.
  - After collection + existing dedup loop: `let bad = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: locked.count)`; remove flagged indices (colors/hexCodes/colorNames together, descending index order); then `fillToTarget(..., plan: repairPlan)` where `repairPlan` is the no-vibe plan if one exists, else `ColorHarmony.plan(baseHexes: hexCodes, size: targetCount, scheme: .auto, seed: seed)` (seeded from the model's own surviving colors, per spec).
  - `fillToTarget(plan:)`: consume unused `plan.slots` (skip any whose hex fails the `seen` dedup) before falling back to the existing golden-ratio rotation. Simulator mock: replace the fixed pool path's fill with plan slots the same way.
- [ ] **Step 4: Build for simulator + run full test suite** (generator itself is exercised via mock path at runtime; no new unit tests beyond validation — the AI path can't run in CI). Manually verify in simulator: Generate tab → pick a base color, no vibe → palette is harmonious and complete.
- [ ] **Step 5: Commit** — `feat: harmony-guided generation with post-validation repair`

---

### Task 5: Auto-assign roles on generation

**Files:**
- Modify: `Palettes/Managers/PaletteGenerator.swift` (result assembly, both device and mock paths)

**Interfaces:**
- Consumes: `HarmonyPlan.roleForBase`, `HarmonySlot.role`, `PaletteColor.role`.
- Produces: generated `PaletteViewModel` arrives with roles assigned (base[0] Primary, base[1] Secondary, accent slot Accent, light neutral Background, dark neutral Text; smaller sizes assign in that priority order — already encoded in the plan's role fields).

- [ ] **Step 1:** Thread roles: build `var colorRoles: [String]` alongside colors — locked colors take `plan.roleForBase`, streamed/filled colors take the role of the slot they satisfied (match filled colors to slots by consumption order in `fillToTarget`; model-refined colors inherit the role of the slot at their position index). Construct the result with the zip-init's `colorRoles:` parameter. When no plan exists (pure vibe, no bases) roles stay empty.
- [ ] **Step 2:** Simulator run: generate from one base color → detail view shows the palette; save it; verify (after Task 8 lands, badges appear — for now assert via a temporary print or existing tests that `paletteColors[0].role == "Primary"`). Add a mock-path unit test if `mockGenerate` is reachable from tests (it is simulator-only): assert first color role Primary, palette contains Background/Text roles at size 6.
- [ ] **Step 3: Commit** — `feat: auto-assign UI roles to generated palettes`

---

### Task 6: Role-driven export names

**Files:**
- Modify: `Palettes/Managers/PaletteExporter.swift` (`namesAndHexes` L58, `uniqueSlugs` L98 — role slug takes precedence)
- Test: extend `PalettesTests/PaletteExporterTests.swift`

**Interfaces:**
- Consumes: `PaletteViewModel.paletteColors[i].role`, `ColorRole(name:).slug`.
- Produces: internal change only — `namesAndHexes` becomes `slugSourcesAndHexes` returning `[(slugSource: String, hex: String)]` where `slugSource` is the role name when present, else the color name. All format functions unchanged externally.

- [ ] **Step 1: Failing tests:** palette with colors [role "Primary" name "Ocean", role nil name "Sand"] → CSS contains `--primary:` and `--sand:`; SCSS `$primary`; Tailwind/JSON/SwiftUI use `primary` (camelCased where applicable); duplicate role name vs color name ("Primary" role + a color literally named "Primary") → `primary` and `primary-2`; plainHex/SVG/Coolors byte-identical to pre-change output for the same palette.
- [ ] **Step 2: Run, verify fail. Step 3:** implement — in the pair-builder use `let source = (i < palette.paletteColors.count ? palette.paletteColors[i].role : nil) ?? name`; slug pipeline (`slugify`/`uniqueSlugs`/`camelCase`) untouched.
- [ ] **Step 4: Run PaletteExporterTests, verify pass. Step 5: Commit** — `feat: role tags drive export variable names`

---

### Task 7: App-wide custom tag library

**Files:**
- Modify: `Palettes/App/PersistentStore.swift` (add `StoredTag`)
- Modify: `Palettes/App/AppData.swift` (published `customTags`, add/rename/delete, persistence + load, schema registration in `init` ~L47)
- Test: extend `PalettesTests/AppDataPersistenceTests.swift`

**Interfaces:**
- Produces:

```swift
@Model final class StoredTag {
    var id: UUID = UUID(); var name: String = ""; var sortIndex: Int = 0
    init(id: UUID, name: String, sortIndex: Int)
}
// AppData:
@Published var customTags: [String]           // ordered, deduped
func addCustomTag(_ name: String) -> Bool     // false if empty/duplicate (case-insensitive, incl. ColorRole.defaults)
func renameCustomTag(_ old: String, to new: String)  // rewrites role on every palette color using it
func deleteCustomTag(_ name: String)          // clears role on every palette color using it
```

- [ ] **Step 1: Failing tests:** add "Brand" → appears in `customTags`, persists across a reloaded AppData; `addCustomTag("primary")` returns false (collides with built-in, case-insensitive); `addCustomTag("brand")` after "Brand" returns false; rename "Brand"→"Marketing" rewrites a palette color tagged "Brand" to "Marketing" and persists; delete clears the role to nil.
- [ ] **Step 2: Run, fail. Step 3:** implement — register `StoredTag.self` in the ModelContainer schema alongside `StoredColor`/`StoredPalette`; load in `load()`; persist with the same upsert-by-id + debounce pattern as `persistColors`; rename/delete iterate `palettes`, mutate `paletteColors[i].role`, reassign the array (value types) and mark palettes dirty.
- [ ] **Step 4: Tests pass. Step 5: Commit** — `feat: app-wide custom tag library with rename/delete propagation`

---

### Task 8: Role tag UI (badge + picker + manage)

**Files:**
- Create: `Palettes/Views/Components/RoleBadge.swift`, `Palettes/Views/Components/RolePickerSheet.swift`
- Modify: `Palettes/Views/Palette/PaletteDetailView.swift` (swatch rows; context menu at `.colorContextMenu()` ~L209)

**Interfaces:**
- Consumes: `ColorRole.defaults`, `AppData.customTags`/`addCustomTag`, `PaletteColor.role`, existing `AppData` palette-update API (use the same mutation path `PaletteDetailView` already uses for color edits — check `.colorViewModel()` ~L32 and how edits write back).
- Produces: `RoleBadge(role: String)` capsule view; `RolePickerSheet(currentRole: String?, palette: PaletteViewModel, colorIndex: Int)` presented from detail view.

- [ ] **Step 1: RoleBadge** — small capsule: `Text(role).font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3)` on `.ultraThinMaterial` (iOS 17 base; add an `@available(iOS 26.0, *)` glass variant via the existing `Palettes/Compatibility/` shims if one exists for glassEffect — check before inventing). Shown on a swatch row when `role != nil`, with `.transition(.scale(scale: 0.8).combined(with: .opacity))` and `.animation(.spring(duration: 0.35, bounce: 0.25), value: role)`.
- [ ] **Step 2: RolePickerSheet** — sections: built-in roles (`ColorRole.defaults`), custom tags (`appData.customTags`), "New tag…" (TextField + add via `addCustomTag`, inline error on false), "Remove tag" when tagged, "Manage tags" section (rename/delete customs via `renameCustomTag`/`deleteCustomTag`, swipe-to-delete). Selecting a role: if another color in the palette holds it, clear that color's role first (spec §5 uniqueness), then assign; write through the detail view's existing palette-update path. Present with `.presentationDetents([.medium, .large])`.
- [ ] **Step 3: Wire into PaletteDetailView** — badge on each swatch row; tap badge or context-menu item "Tag…" opens the sheet for that color index.
- [ ] **Step 4: Manual verification in simulator:** tag a color Primary; badge animates in; assign Primary to a second color → first loses it; create custom tag; rename it; delete it; relaunch app → tags persist. Run full test suite (no regressions).
- [ ] **Step 5: Commit** — `feat: role badge and picker UI in palette detail`

---

### Task 9: Harmony scheme override UI in GenerateView

**Files:**
- Modify: `Palettes/Views/Color/GenerateView.swift` (base-color selection area; the `generate` call site updated in Task 4)

- [ ] **Step 1:** `@State private var scheme: HarmonyScheme = .auto`. When ≥ 1 base color is selected, show a `Menu` labeled with the current `scheme.displayName` + `Image(systemName: "paintpalette")` styled like neighboring controls (match existing glass/material styling in this view — read the surrounding code first). Menu lists Auto + five schemes with checkmark on current. Appears/disappears with `.transition(.opacity.combined(with: .move(edge: .top)))` under the view's existing animation driver. Not persisted; resets to `.auto` when base colors are cleared.
- [ ] **Step 2:** Pass `scheme: scheme` to `PaletteGenerator.generate`.
- [ ] **Step 3:** Simulator: select a base color → control appears; force Monochromatic → generated palette is visibly monochrome + accent. Commit — `feat: harmony scheme override control in generate view`

---

### Task 10: Tag-based search & filtering

**Files:**
- Modify: `Palettes/Views/Main/SearchView.swift` (`filteredPalettes` L43-49, browse chips ~L55+ hue-chip pattern)
- Create: `Palettes/Utilities/SearchMatching.swift` (pure matching helpers, testable)
- Test: `PalettesTests/SearchMatchingTests.swift`

**Interfaces:**
- Produces:

```swift
enum SearchMatching {
    static func paletteMatchesQuery(_ palette: PaletteViewModel, query: String, hexQuery: String) -> Bool
    static func paletteMatchesTags(_ palette: PaletteViewModel, tags: Set<String>) -> Bool  // any-of, case-insensitive
    static func tagsInUse(palettes: [PaletteViewModel]) -> [String]  // built-in order first, then customs alphabetical
}
```

- [ ] **Step 1: Failing tests:** query "primary" matches a palette whose only hit is a color tagged Primary (name/hex untouched); existing name/colorName/hex matching preserved (port the current `filteredPalettes` predicate into `paletteMatchesQuery` and test it); `paletteMatchesTags` any-of semantics + case-insensitivity; `tagsInUse` ordering and deduping; empty-tag palettes → chip list empty.
- [ ] **Step 2: Run, fail. Step 3:** implement `SearchMatching`; refactor `SearchView.filteredPalettes` to call `paletteMatchesQuery`; add `@State private var selectedTags: Set<String> = []`; tag chip row rendered with the same chip component/styling as the hue chips, only when `!SearchMatching.tagsInUse(palettes: appData.palettes).isEmpty`; browse palette list filtered by `paletteMatchesTags` (palettes section only, per spec §8).
- [ ] **Step 4: Tests pass + simulator check** (chips hidden with no tags; appear after tagging; filtering works). **Step 5: Commit** — `feat: tag-based palette search and browse filtering`

---

### Task 11: Motion pass, README, verification, merge prep

**Files:** as discovered; `README.md`

- [ ] **Step 1:** Run the `find-animation-opportunities` skill scoped to the new UI (RoleBadge, RolePickerSheet, scheme menu, tag chips), then apply accepted suggestions per the `apple-design` / `improve-animations` skills (respect Reduce Motion via existing patterns in the codebase).
- [ ] **Step 2:** Update `README.md`: add role tags, tag search, harmony schemes, and improved extraction to Features (mirror existing tone; the README was recently rewritten — extend, don't restructure).
- [ ] **Step 3:** Full verification (superpowers:verification-before-completion): entire test suite green; manual simulator sweep of spec §§1-9 behaviors; `graphify update .`.
- [ ] **Step 4:** Commit, then use superpowers:finishing-a-development-branch — merge target is `dev` (never straight to main); request review via superpowers:requesting-code-review first.
