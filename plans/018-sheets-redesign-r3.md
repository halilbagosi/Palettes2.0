# Sheets Redesign r3: Color & Palette Editors (018) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implementers are Sonnet subagents; an Opus reviewer gates every task and the final branch.

**Goal:** Replace the New Color / Edit Color / New Palette / Edit Palette / Add Colors sheets with one family of editors where the thing being made is the hero and the controls are direct, so they need no explaining.

**Architecture:** Two editors. `ColorComposer` (reworked) is the one color editor: a pinned hero (compact swatch with name and eyedropper) over an always-visible picker (Spectrum / Grid / Sliders), with Fine-tune and Values scrolling below. `PaletteEditor` (new) is the one palette editor, used by both New Palette and Edit Palette over a value-type `PaletteDraft`: empty-state start tiles, then an interactive palette strip that *is* the editor. Pure logic (draft ops, grid, starters, harmony previews, photo pin locations) lives in small testable types; views stay thin.

**Tech Stack:** SwiftUI (iOS 17.0 deployment target, iOS 26/27 SDK), Swift Testing (`import Testing`), existing `PaletteBuilder`, `ImageColorExtractor`, `PhotoLoupeGeometry`, `ColorAdjustment`.

**Design source:** the grilling session of 2026-10-11 (decisions Q1–Q22, recorded in "Decisions" below). Plan 017 is revision 2; this is revision 3.

## Global Constraints

- Branch: `feature/sheets-redesign`. Never commit to `main`/`dev` directly.
- Deployment target stays **iOS 17.0**. iOS 26-only APIs go behind `if #available(iOS 26.0, *)` in view-level shims under `Palettes/Compatibility/`; never raise the target.
- New `.swift` files under `Palettes/` or `PalettesTests/` are auto-included (synchronized groups). **Never edit `project.pbxproj`.**
- Every new file imports every module whose members it uses (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`): `@Published`/`ObservableObject` need `import Combine`.
- `AppData` is the single source of truth; editors work on drafts and write back through `appData.palettes` / `appData.colors` only on confirm.
- **Toolbar button rule (all iOS versions):** adding something → **+** symbol, title "Add" (or "Add N"); creating or saving → **✓** symbol, title "Create"/"Save". Cancel → ✕, title "Cancel". Every toolbar item is a titled `Label` (plan 016, A5).
- **Motion spec:** layout = `.spring(duration: 0.35, bounce: 0)`; small hops `.snappy`; reorder lift `scaleEffect(1.03)` + settle `.spring(duration: 0.35, bounce: 0.15)`; drags (spectrum, sliders, pins, reorder) track 1:1 with **no** animation; `.sensoryFeedback(.selection, …)` on grid-cell snap and band reorder slot change; Reduce Motion → `.opacity` transitions only, no scale/offset; nothing animates on keyboard-initiated actions.
- Settings is out of scope and must not change.
- Copy: sentence-level plain language, no jargon; buttons are verbs.
- Test command (use a throwaway sim — the shared sim `208E09D6` is used by other sessions):

  ```bash
  xcrun simctl create sheets-018 "iPhone 17 Pro" com.apple.CoreSimulator.SimRuntime.iOS-27-0
  xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=sheets-018" -derivedDataPath /tmp/sheets-018-dd -only-testing:PalettesTests/<SuiteName>
  ```
  Delete the sim at the end: `xcrun simctl delete sheets-018`.

---

## Decisions (from grilling, 2026-10-11)

| # | Decision |
|---|---|
| Q1 | Problems: New Color has no clear first step and competing inputs; picker hidden behind a row; New Palette feels like a form; too many paths; looks less polished than Settings. |
| Q2 | Scope: New Color, Edit Color, New Palette, Edit Palette, Add Colors — one family. |
| Q3 | Hybrid look: hero color/palette pinned on top, Settings-style grouped rows below. |
| Q4 | New Palette starts from a source; Generate stays in the Generate tab (redirect). |
| Q5 | Inline picker with Spectrum / Grid / Sliders modes; **keep** the relative Temperature/Saturation/Brightness tuning sliders as Fine-tune. Sliders mode = **absolute RGB**. |
| Q6 | Empty-state tiles: From a Photo, From My Colors, From One Color, Generate with AI (→ Generate tab); "Start Blank" text button. |
| Q7 | The strip is the editor: tap band → edit, hold-drag → reorder, context menu Edit/Duplicate/Tag…/Remove, **+** at the end. No separate list. |
| Q8 | Edit Palette is a draft: Cancel discards, ✓ saves. |
| Q9 | Add → **+**; create/save → **✓**; all iOS versions. |
| Q10 | Eyedropper button on the swatch → menu Choose Photo / Take Photo → existing `PhotoColorPickerView`. |
| Q11 | Pinned: compact swatch (name on it, tap to rename) + mode switch + picker. Scrolls: Fine-tune, Values. Swatch shrinks while a value field has focus. |
| Q12 | Grid = hue columns × lightness rows, with a "Your Colors" row on top. |
| Q13 | From One Color: picker on top, live harmony strips below; tap one → fills the palette, back in the editor. |
| Q14 | From a Photo: auto-extract, then the photo with a draggable pin per color; dragging updates the strip live; **+** accepts. |
| Q15 | `AddColorToPaletteSheet` is removed; adding happens in Edit Palette's **+** menu. |
| Q16 | **+** menu: New Color, From My Colors, From a Photo (appends), Colors That Go With… (harmony from the selected band). |
| Q17 | Edit Color saves by context: from a palette → only that palette's color changes (plus the new hex is added to the library if absent; existing library colors are never modified); from the library → the library color. No overwrite dialog. |
| Q18 | New Color opens on a random color from a curated vivid set. |
| Q19 | Motion spec above. |
| Q20 | Settings unchanged. |
| Q21 | Plan → prototype → Sonnet implementers + Opus review → `improve-animations` audit → iOS 17 + iOS 26 builds. |
| Q22 | Color editor goes two-column at regular width; palette editor stays one column. |
| Tags | Band menu "Tag…" and a Tag row in the pushed color editor; the role list **pushes** and edits the draft. |

Carried over unchanged from 017: 2-color minimum; inline duplicate notices; blank name uses the `PaletteNamer` suggestion; unsaved palette can't be swiped away and Cancel asks; HEX paste, keyboard Done, half-typed value revert.

## File Structure

**Create**
- `Palettes/ViewModels/PaletteDraft.swift` — value-type draft of a palette (colors, name, ops, validation, save conversion).
- `Palettes/Utilities/ColorPickerModel.swift` — pure helpers: grid swatches, vivid starters, harmony previews.
- `Palettes/Utilities/PhotoPinLocator.swift` — finds where each extracted color sits in a photo.
- `Palettes/Views/Components/ColorPicking/SpectrumPad.swift` — hue × brightness field + saturation track, 1:1 drag.
- `Palettes/Views/Components/ColorPicking/SwatchGridPicker.swift` — "Your Colors" row + grid.
- `Palettes/Views/Components/ColorPicking/RGBSliders.swift` — absolute R/G/B sliders.
- `Palettes/Views/Components/ColorPicking/ColorPickerPanel.swift` — segmented mode switch hosting the three.
- `Palettes/Views/Components/RoleList.swift` — the role/tag list body, extracted from `RolePickerSheet`, driven by a value + callback.
- `Palettes/Views/Palette/Editor/PaletteEditor.swift` — the shared palette editor (New + Edit).
- `Palettes/Views/Palette/Editor/PaletteStripEditor.swift` — the interactive strip (tap, reorder, menu, +).
- `Palettes/Views/Palette/Editor/PaletteStartTiles.swift` — empty-state tiles.
- `Palettes/Views/Palette/Editor/HarmonyPage.swift` — From One Color / Colors That Go With….
- `Palettes/Views/Palette/Editor/PhotoPinsPage.swift` — photo with draggable pins.
- Tests: `PalettesTests/PaletteDraftTests.swift`, `PalettesTests/ColorPickerModelTests.swift`, `PalettesTests/PhotoPinLocatorTests.swift`.

**Modify**
- `Palettes/Views/Components/ColorComposer.swift` — new layout; drop system `ColorPicker` row and photo capsule buttons.
- `Palettes/Compatibility/SheetToolbarCompat.swift` — `SheetConfirmButton(kind:)` with ✓ / + on every OS.
- `Palettes/Views/Color/NewColorView.swift`, `Palettes/Views/Color/ColorEditView.swift` — start color, context save, no overwrite alert.
- `Palettes/Views/Components/PaletteColorPages.swift` — `NewPaletteColorPage` + button, `LibraryColorPicker` "+ Add N".
- `Palettes/Views/Palette/NewPaletteView.swift` — thin wrapper over `PaletteEditor`.
- `Palettes/Views/Components/PaletteEditSheet.swift` — thin wrapper over `PaletteEditor` (draft + ✓).
- `Palettes/Views/Components/RolePickerSheet.swift` — body becomes `RoleList`.
- `Palettes/Views/Palette/PaletteDetailView.swift` — Edit Color call site + `syncEditedPaletteColor` per Q17.
- `plans/README.md`, `plans/017-sheet-redesign.md` (status line), this plan (prototype findings).

**Delete**
- `Palettes/Views/Components/AddColorToPaletteSheet.swift`.

---

### Task 1: Prototype gate — Spectrum pad in a pinned header, and strip reorder

Throwaway. Answers two risks before real code: (a) does a drag surface in the pinned region (not inside the `Form`) track cleanly with no scroll conflict on iOS 17 and 26; (b) does long-press-drag reorder on a horizontal strip feel right and coexist with tap and context menu.

**Files:**
- Create (then delete in Step 5): `Palettes/Prototypes/Proto018.swift`

- [ ] **Step 1: Write the prototype**

```swift
#if DEBUG
import SwiftUI

/// Throwaway for plan 018 Task 1. Delete after recording findings.
struct Proto018: View {
    @State private var hue = 0.6, brightness = 0.9
    @State private var bands: [Color] = [.red, .orange, .yellow, .green, .blue]
    @State private var dragging: Int?
    @State private var dragX: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20).fill(Color(hue: hue, saturation: 0.8, brightness: brightness)).frame(height: 80)
            GeometryReader { geo in
                LinearGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 0.8, brightness: 1) }, startPoint: .leading, endPoint: .trailing)
                    .overlay(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        hue = min(max(v.location.x / geo.size.width, 0), 1)
                        brightness = 1 - min(max(v.location.y / geo.size.height, 0), 1)
                    })
            }
            .frame(height: 180)
            GeometryReader { geo in
                let w = geo.size.width / CGFloat(bands.count)
                HStack(spacing: 0) {
                    ForEach(bands.indices, id: \.self) { i in
                        Rectangle().fill(bands[i])
                            .scaleEffect(dragging == i ? 1.03 : 1)
                            .offset(x: dragging == i ? dragX : 0)
                            .zIndex(dragging == i ? 1 : 0)
                            .onTapGesture { print("tap \(i)") }
                            .gesture(LongPressGesture(minimumDuration: 0.3).sequenced(before: DragGesture()).onChanged { value in
                                if case .second(true, let drag?) = value { dragging = i; dragX = drag.translation.width }
                            }.onEnded { _ in
                                if let from = dragging {
                                    let to = min(max(from + Int((dragX / w).rounded()), 0), bands.count - 1)
                                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) { bands.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to) }
                                }
                                dragging = nil; dragX = 0
                            })
                            .contextMenu { Button("Remove") {} }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .frame(height: 96)
            Form { Section("Fine-tune") { ForEach(0..<12) { Text("Row \($0)") } } }
        }
        .padding()
    }
}

#Preview { Proto018() }
#endif
```

- [ ] **Step 2: Host it temporarily**: in a scratch local edit (do not commit), present `Proto018()` from `SettingsView`'s DEBUG section as a `NavigationLink("Proto 018") { Proto018() }`.
- [ ] **Step 3: Run on the `sheets-018` sim (iOS 27) and an iOS 17 sim**; screenshot. Check: spectrum drag tracks with zero lag and never scrolls the Form; tap vs long-press-drag vs context menu disambiguate (expect: context menu and long-press drag conflict — record which wins and at what duration).
- [ ] **Step 4: Record findings** under "Prototype findings" at the bottom of this plan. If long-press-drag and `.contextMenu` conflict, the chosen fallback is: **drag starts on long-press + movement ≥ 10 pt; a long-press without movement opens the menu** (implement via `.onLongPressGesture` + `DragGesture(minimumDistance: 10)` in Task 9). Record whether that was needed.
- [ ] **Step 5: Delete** `Palettes/Prototypes/Proto018.swift`, revert the Settings scratch edit (`git checkout -- Palettes/Views/Settings/SettingsView.swift`), and commit only the plan findings:

```bash
git add plans/018-sheets-redesign-r3.md
git commit -m "Plan 018: record prototype findings for spectrum pad and strip reorder"
```

---

### Task 2: `PaletteDraft` — the palette being made or edited

**Files:**
- Create: `Palettes/ViewModels/PaletteDraft.swift`
- Test: `PalettesTests/PaletteDraftTests.swift`

**Interfaces:**
- Consumes: `PaletteColor` (`id`, `color`, `hex`, `name`, `role`), `PaletteViewModel(name:paletteColors:)`, `ColorNamer.name(forHex:)`.
- Produces:
  ```swift
  struct PaletteDraft: Equatable {
      var name: String
      var colors: [PaletteColor]
      init(name: String = "", colors: [PaletteColor] = [])
      init(palette: PaletteViewModel)
      static let minimumColors = 2
      var canSave: Bool
      var hexes: Set<String>                      // uppercased "#RRGGBB"
      func contains(hex: String) -> Bool
      mutating func append(_ new: [PaletteColor]) -> Int   // dedups by hex, returns count added
      mutating func replaceAll(with new: [PaletteColor])
      mutating func remove(id: UUID) -> (index: Int, color: PaletteColor)?
      mutating func duplicate(id: UUID)          // copy inserted right after, hex nudged to stay unique
      mutating func move(id: UUID, to index: Int)
      mutating func setRole(_ role: String?, for id: UUID)   // one holder per role (case-insensitive)
      mutating func update(id: UUID, color: Color, hex: String, name: String)
      func resolvedName(suggestion: String) -> String
      func finalizedColors() -> [PaletteColor]   // blank names → ColorNamer
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import SwiftUI
@testable import Palettes

struct PaletteDraftTests {
    private func pc(_ hex: String, _ name: String = "", role: String? = nil) -> PaletteColor {
        PaletteColor(color: Color(hex: hex) ?? .gray, hex: hex, name: name, role: role)
    }

    @Test func appendSkipsDuplicateHexesCaseInsensitively() {
        var draft = PaletteDraft(colors: [pc("#FF0000")])
        let added = draft.append([pc("#ff0000"), pc("#00FF00"), pc("#00FF00")])
        #expect(added == 1)
        #expect(draft.colors.map(\.hex) == ["#FF0000", "#00FF00"])
    }

    @Test func canSaveNeedsTwoColors() {
        var draft = PaletteDraft()
        #expect(!draft.canSave)
        _ = draft.append([pc("#111111"), pc("#222222")])
        #expect(draft.canSave)
    }

    @Test func moveByIDReorders() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#222222"), pc("#333333")])
        let first = draft.colors[0].id
        draft.move(id: first, to: 2)
        #expect(draft.colors.map(\.hex) == ["#222222", "#333333", "#111111"])
    }

    @Test func removeReturnsIndexForUndo() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#222222")])
        let id = draft.colors[1].id
        let removed = draft.remove(id: id)
        #expect(removed?.index == 1)
        #expect(draft.colors.count == 1)
    }

    @Test func duplicateInsertsAfterWithUniqueHex() {
        var draft = PaletteDraft(colors: [pc("#808080", "Gray"), pc("#000000")])
        draft.duplicate(id: draft.colors[0].id)
        #expect(draft.colors.count == 3)
        #expect(draft.colors[1].name == "Gray")
        #expect(draft.colors[1].hex != "#808080")
        #expect(Set(draft.colors.map(\.hex)).count == 3)
    }

    @Test func setRoleKeepsOneHolderPerRole() {
        var draft = PaletteDraft(colors: [pc("#111111", role: "Primary"), pc("#222222")])
        draft.setRole("primary", for: draft.colors[1].id)
        #expect(draft.colors[0].role == nil)
        #expect(draft.colors[1].role == "primary")
    }

    @Test func resolvedNameFallsBackToSuggestionThenUntitled() {
        #expect(PaletteDraft(name: "  Dusk ").resolvedName(suggestion: "Ocean") == "Dusk")
        #expect(PaletteDraft(name: " ").resolvedName(suggestion: "Ocean") == "Ocean")
        #expect(PaletteDraft().resolvedName(suggestion: "") == "Untitled Palette")
    }

    @Test func finalizedColorsNamesBlankEntries() {
        let draft = PaletteDraft(colors: [pc("#FF0000", "  ")])
        #expect(draft.finalizedColors()[0].name == ColorNamer.name(forHex: "#FF0000"))
    }

    @Test func initFromPaletteRoundTripsEquality() {
        let palette = PaletteViewModel(name: "P", paletteColors: [pc("#111111"), pc("#222222")])
        let draft = PaletteDraft(palette: palette)
        #expect(draft == PaletteDraft(palette: palette))
        #expect(draft.name == "P")
    }
}
```

- [ ] **Step 2: Run** `-only-testing:PalettesTests/PaletteDraftTests` → FAIL ("cannot find 'PaletteDraft'").
- [ ] **Step 3: Implement**

```swift
//
//  PaletteDraft.swift
//  Palettes
//
//  The palette being made or edited, before it's saved. New Palette and Edit
//  Palette both work on one of these; nothing reaches AppData until ✓.
//

import SwiftUI

struct PaletteDraft: Equatable {
    var name: String
    var colors: [PaletteColor]

    static let minimumColors = 2

    init(name: String = "", colors: [PaletteColor] = []) {
        self.name = name
        self.colors = colors
    }

    init(palette: PaletteViewModel) {
        self.init(name: palette.name, colors: palette.paletteColors)
    }

    var canSave: Bool { colors.count >= Self.minimumColors }

    var hexes: Set<String> { Set(colors.map { $0.hex.uppercased() }) }

    func contains(hex: String) -> Bool { hexes.contains(hex.uppercased()) }

    @discardableResult
    mutating func append(_ new: [PaletteColor]) -> Int {
        var seen = hexes
        var added = 0
        for color in new where !seen.contains(color.hex.uppercased()) {
            seen.insert(color.hex.uppercased())
            colors.append(color)
            added += 1
        }
        return added
    }

    mutating func replaceAll(with new: [PaletteColor]) {
        colors = []
        append(new)
    }

    @discardableResult
    mutating func remove(id: UUID) -> (index: Int, color: PaletteColor)? {
        guard let index = colors.firstIndex(where: { $0.id == id }) else { return nil }
        return (index, colors.remove(at: index))
    }

    /// Inserts a copy right after the original. A palette can't hold the same
    /// hex twice, so the copy's blue channel steps until it's unique.
    mutating func duplicate(id: UUID) {
        guard let index = colors.firstIndex(where: { $0.id == id }) else { return }
        let source = colors[index]
        let rgb = source.color.rgbComponents
        var b = Int(rgb.b.rounded())
        var hex = source.hex
        for step in 1...255 {
            b = (Int(rgb.b.rounded()) + step) % 256
            hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: Double(b))
            if !contains(hex: hex) { break }
        }
        let copy = PaletteColor(
            color: ColorAdjustment.color(r: rgb.r, g: rgb.g, b: Double(b)),
            hex: hex,
            name: source.name,
            role: nil
        )
        colors.insert(copy, at: index + 1)
    }

    mutating func move(id: UUID, to index: Int) {
        guard let from = colors.firstIndex(where: { $0.id == id }) else { return }
        let item = colors.remove(at: from)
        colors.insert(item, at: min(max(index, 0), colors.count))
    }

    mutating func setRole(_ role: String?, for id: UUID) {
        if let role {
            for i in colors.indices where colors[i].id != id
                && colors[i].role?.caseInsensitiveCompare(role) == .orderedSame {
                colors[i].role = nil
            }
        }
        if let i = colors.firstIndex(where: { $0.id == id }) { colors[i].role = role }
    }

    mutating func update(id: UUID, color: Color, hex: String, name: String) {
        guard let i = colors.firstIndex(where: { $0.id == id }) else { return }
        colors[i].color = color
        colors[i].hex = hex
        colors[i].name = name
    }

    func resolvedName(suggestion: String) -> String {
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return suggestion.isEmpty ? "Untitled Palette" : suggestion
    }

    func finalizedColors() -> [PaletteColor] {
        colors.map { entry in
            var entry = entry
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.name = trimmed.isEmpty ? ColorNamer.name(forHex: entry.hex) : trimmed
            return entry
        }
    }
}
```

Note: `ColorAdjustment.hexString(r:g:b:)` returns `"#RRGGBB"`, and `PaletteColor` is `Hashable` (so `Equatable`).

- [ ] **Step 4: Run** the suite → PASS.
- [ ] **Step 5: Commit**

```bash
git add Palettes/ViewModels/PaletteDraft.swift PalettesTests/PaletteDraftTests.swift
git commit -m "Add PaletteDraft: the palette being made or edited"
```

---

### Task 3: `ColorPickerModel` — grid, vivid starters, harmony previews

**Files:**
- Create: `Palettes/Utilities/ColorPickerModel.swift`
- Test: `PalettesTests/ColorPickerModelTests.swift`

**Interfaces:**
- Consumes: `PaletteBuilder.build(_:)`, `PaletteBuildRequest`, `HarmonyScheme`, `Color(hex:)`.
- Produces:
  ```swift
  enum ColorPickerModel {
      static let gridColumns = 12, gridRows = 8
      static func gridHexes() -> [[String]]          // [row][column], "#RRGGBB"; row 0 lightest, last row grays
      static let vividStarters: [String]             // 16 curated hexes
      static func randomStarter<G: RandomNumberGenerator>(using rng: inout G) -> String
      static func randomStarter() -> String
      static let previewSchemes: [HarmonyScheme]     // [.complementary, .splitComplementary, .analogous, .triadic, .monochromatic]
      static func harmonies(for hex: String, size: Int = 5) -> [(scheme: HarmonyScheme, hexes: [String])]
      static func recentColors(_ library: [ColorViewModel], limit: Int = 12) -> [ColorViewModel] // newest first
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import SwiftUI
@testable import Palettes

struct ColorPickerModelTests {
    @Test func gridHasFixedShapeAndValidHexes() {
        let grid = ColorPickerModel.gridHexes()
        #expect(grid.count == ColorPickerModel.gridRows)
        #expect(grid.allSatisfy { $0.count == ColorPickerModel.gridColumns })
        #expect(grid.joined().allSatisfy { Color(hex: $0) != nil && $0.hasPrefix("#") && $0.count == 7 })
    }

    @Test func gridLastRowIsGrayscale() {
        for hex in ColorPickerModel.gridHexes().last! {
            let c = Color(hex: hex)!.rgbComponents
            #expect(abs(c.r - c.g) < 2 && abs(c.g - c.b) < 2)
        }
    }

    @Test func randomStarterIsDeterministicForSeed() {
        var a = SplitMix64(seed: 7), b = SplitMix64(seed: 7)
        #expect(ColorPickerModel.randomStarter(using: &a) == ColorPickerModel.randomStarter(using: &b))
        #expect(ColorPickerModel.vividStarters.contains(ColorPickerModel.randomStarter(using: &a)))
    }

    @Test func harmoniesStartWithTheBaseAndCoverEveryScheme() {
        let result = ColorPickerModel.harmonies(for: "#FF5D00")
        #expect(result.map(\.scheme) == ColorPickerModel.previewSchemes)
        for item in result {
            #expect(item.hexes.first == "#FF5D00")
            #expect(item.hexes.count == 5)
        }
    }

    @Test func harmoniesAreStable() {
        #expect(ColorPickerModel.harmonies(for: "#3366CC").map(\.hexes)
                == ColorPickerModel.harmonies(for: "#3366CC").map(\.hexes))
    }

    @Test func recentColorsAreNewestFirstAndCapped() {
        let lib = (0..<20).map { ColorViewModel(name: "\($0)", color: .red, HEX: String(format: "#%06X", $0), usedInPalette: false) }
        let recent = ColorPickerModel.recentColors(lib, limit: 12)
        #expect(recent.count == 12)
        #expect(recent.first?.name == "19")
    }
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**

```swift
//
//  ColorPickerModel.swift
//  Palettes
//
//  The numbers behind the color picker: the swatch grid, the vivid colors a
//  new color starts on, and the harmony previews for "From One Color".
//

import SwiftUI

enum ColorPickerModel {
    static let gridColumns = 12
    static let gridRows = 8

    /// Hue columns × lightness rows, lightest first; the last row is grays.
    static func gridHexes() -> [[String]] {
        let brightness: [Double] = [1.0, 1.0, 1.0, 0.92, 0.75, 0.58, 0.4]
        let saturation: [Double] = [0.25, 0.5, 0.8, 1.0, 1.0, 1.0, 1.0]
        var rows: [[String]] = []
        for r in 0..<(gridRows - 1) {
            rows.append((0..<gridColumns).map { c in
                hex(Color(hue: Double(c) / Double(gridColumns), saturation: saturation[r], brightness: brightness[r]))
            })
        }
        rows.append((0..<gridColumns).map { c in
            let v = 1 - Double(c) / Double(gridColumns - 1)
            return hex(Color(white: v))
        })
        return rows
    }

    static let vividStarters: [String] = [
        "#FF5D00", "#FF2D55", "#FF9F0A", "#FFD60A", "#34C759", "#00C7BE",
        "#30B0C7", "#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F", "#AC8E68",
        "#E4572E", "#17BEBB", "#7A28CB", "#F2A541",
    ]

    static func randomStarter<G: RandomNumberGenerator>(using rng: inout G) -> String {
        vividStarters[Int(rng.next() % UInt64(vividStarters.count))]
    }

    static func randomStarter() -> String {
        var rng = SystemRandomNumberGenerator()
        return randomStarter(using: &rng)
    }

    static let previewSchemes: [HarmonyScheme] = [.complementary, .splitComplementary, .analogous, .triadic, .monochromatic]

    /// One palette per scheme, each starting with `hex`. A fixed seed per
    /// base color keeps the previews still while nothing changes.
    static func harmonies(for hex: String, size: Int = 5) -> [(scheme: HarmonyScheme, hexes: [String])] {
        let normalized = PaletteBuilder.normalize([hex]).first ?? hex
        let seed = UInt64(normalized.dropFirst(), radix: 16) ?? 0
        return previewSchemes.map { scheme in
            let built = PaletteBuilder.build(PaletteBuildRequest(anchors: [normalized], size: size, scheme: scheme, seed: seed))
            return (scheme, built.hexes)
        }
    }

    /// Library colors are appended as they're saved, so the tail is newest.
    static func recentColors(_ library: [ColorViewModel], limit: Int = 12) -> [ColorViewModel] {
        Array(library.suffix(limit).reversed())
    }

    private static func hex(_ color: Color) -> String { ColorComposer.hexKey(color) }
}
```

- [ ] **Step 4: Run** → PASS. If `harmoniesStartWithTheBase` fails because `PaletteBuilder.normalize` uppercases differently, compare against the normalized base.
- [ ] **Step 5: Commit** `git add Palettes/Utilities/ColorPickerModel.swift PalettesTests/ColorPickerModelTests.swift && git commit -m "Add ColorPickerModel: grid, vivid starters, harmony previews"`

---

### Task 4: `PhotoPinLocator` — where each photo color lives

**Files:**
- Create: `Palettes/Utilities/PhotoPinLocator.swift`
- Test: `PalettesTests/PhotoPinLocatorTests.swift`

**Interfaces:**
- Consumes: `ImageColorExtractor.PixelSampler` (`init?(image:maxDim:)`, `color(at:radius:)` with normalized points).
- Produces:
  ```swift
  enum PhotoPinLocator {
      /// Normalized (0…1, top-left origin) point whose pixel is closest to each hex.
      static func locate(hexes: [String], in sampler: ImageColorExtractor.PixelSampler, steps: Int = 48) -> [CGPoint]
  }
  ```

- [ ] **Step 1: Failing test** — build a 2×1 image (left red, right blue) and expect red → x < 0.5, blue → x > 0.5.

```swift
import Testing
import UIKit
@testable import Palettes

struct PhotoPinLocatorTests {
    private func splitImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 50, y: 0, width: 50, height: 50))
        }
    }

    @Test func pinsLandOnTheirColor() throws {
        let sampler = try #require(ImageColorExtractor.PixelSampler(image: splitImage()))
        let points = PhotoPinLocator.locate(hexes: ["#FF0000", "#0000FF"], in: sampler)
        #expect(points.count == 2)
        #expect(points[0].x < 0.5)
        #expect(points[1].x > 0.5)
    }

    @Test func pointsAreNormalized() throws {
        let sampler = try #require(ImageColorExtractor.PixelSampler(image: splitImage()))
        for p in PhotoPinLocator.locate(hexes: ["#00FF00"], in: sampler) {
            #expect((0...1).contains(p.x) && (0...1).contains(p.y))
        }
    }
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**

```swift
//
//  PhotoPinLocator.swift
//  Palettes
//
//  Where each color pulled from a photo sits in it, so From a Photo can put a
//  draggable pin on the spot. A coarse grid search is enough: the pin only
//  needs to start somewhere sensible; the user drags it from there.
//

import UIKit

enum PhotoPinLocator {
    static func locate(hexes: [String], in sampler: ImageColorExtractor.PixelSampler, steps: Int = 48) -> [CGPoint] {
        let samples: [(point: CGPoint, rgb: (r: Double, g: Double, b: Double))] = (0..<steps).flatMap { yi in
            (0..<steps).map { xi in
                let p = CGPoint(x: (Double(xi) + 0.5) / Double(steps), y: (Double(yi) + 0.5) / Double(steps))
                return (p, sampler.color(at: p, radius: 1))
            }
        }
        return hexes.map { hex in
            guard let target = rgb(hex) else { return CGPoint(x: 0.5, y: 0.5) }
            return samples.min { distance($0.rgb, target) < distance($1.rgb, target) }?.point ?? CGPoint(x: 0.5, y: 0.5)
        }
    }

    private static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
    }

    private static func distance(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b
        return dr * dr + dg * dg + db * db
    }
}
```

- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `git add Palettes/Utilities/PhotoPinLocator.swift PalettesTests/PhotoPinLocatorTests.swift && git commit -m "Add PhotoPinLocator: find each extracted color in its photo"`

---

### Task 5: Picker controls — Spectrum, Grid, RGB sliders, and the mode panel

**Files:**
- Create: `Palettes/Views/Components/ColorPicking/SpectrumPad.swift`, `SwatchGridPicker.swift`, `RGBSliders.swift`, `ColorPickerPanel.swift`

**Interfaces:**
- Consumes: `ColorPickerModel.gridHexes()`, `ColorPickerModel.recentColors(_:)`, `AppData.colors`, `Color.hsbComponents`, `Color.rgbComponents`, `ColorAdjustment.color(r:g:b:)`, `ColorComposer.hexKey(_:)`.
- Produces:
  ```swift
  struct ColorPickerPanel: View {
      @Binding var color: Color
      var onPick: (Color) -> Void          // every change made by the panel
  }
  enum ColorPickerMode: String, CaseIterable, Identifiable { case spectrum, grid, sliders }   // titles "Spectrum", "Grid", "Sliders"
  ```

Behavior (all must hold):
- **Panel:** a segmented `Picker` (`.pickerStyle(.segmented)`) over the selected control. Remember the last mode with `@AppStorage("colorPickerMode")`, default `.spectrum`. Mode switches cross-fade (`.transition(.opacity)`, `.animation(.snappy, value: mode)`).
- **SpectrumPad:** a 2D field — x = hue (0…1), y = brightness (1 at top → 0.15 at bottom), at the current saturation — with a separate saturation track beneath (gradient from gray to full hue). Both use `DragGesture(minimumDistance: 0)` updating **without animation** (`var t = Transaction(); t.disablesAnimations = true; withTransaction(t) { … }`). A white ring thumb (24 pt, 2 pt stroke, shadow) marks the current color. Respect the grab: the color jumps to the touch point on touch-down (it's a field, not a handle). Height 180 compact / 220 regular. Accessibility: the pad is one element with `.accessibilityAdjustableAction` stepping hue by 1/36, value text "Hue N degrees, brightness N percent".
- **SwatchGridPicker:** top row "Your Colors" (horizontal scroll of up to 12 `ColorPickerModel.recentColors` circles, hidden when the library is empty), then the 12×8 grid as `Grid` of rounded squares (corner 4, no gaps on the outer clip, 2 pt selection ring on the cell whose hex equals the current hex). Tap or drag across cells selects (a single `DragGesture(minimumDistance: 0)` over the grid maps location → cell), with `.sensoryFeedback(.selection, trigger: selectedHex)`.
- **RGBSliders:** three rows, each "R"/"G"/"B" label, a `Slider(0…255, step 1)` with a gradient track showing that channel's range at the current other channels, and the integer value (monospaced, 3-wide). Absolute: never recenters.

- [ ] **Step 1: Implement `SpectrumPad`**

```swift
import SwiftUI

/// Hue across, brightness down, saturation on its own track below. Drags
/// follow the finger exactly — no animation — so the swatch above answers
/// as the finger moves.
struct SpectrumPad: View {
    @Binding var color: Color
    var height: CGFloat = 180
    var onPick: (Color) -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var lastHex = ""

    private static let minBrightness = 0.15

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { Color(hue: $0, saturation: saturation, brightness: 1) },
                        startPoint: .leading, endPoint: .trailing
                    )
                    LinearGradient(colors: [.clear, .black.opacity(1 - Self.minBrightness)], startPoint: .top, endPoint: .bottom)
                    thumb.position(x: hue * geo.size.width, y: (1 - (brightness - Self.minBrightness) / (1 - Self.minBrightness)) * geo.size.height)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let x = min(max(value.location.x / geo.size.width, 0), 1)
                    let y = min(max(value.location.y / geo.size.height, 0), 1)
                    set(hue: x, brightness: 1 - y * (1 - Self.minBrightness))
                })
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Color field")
            .accessibilityValue("Hue \(Int(hue * 360)) degrees, brightness \(Int(brightness * 100)) percent")
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 1.0 / 36 : -1.0 / 36
                set(hue: (hue + step + 1).truncatingRemainder(dividingBy: 1), brightness: brightness)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(
                        colors: [Color(hue: hue, saturation: 0, brightness: brightness), Color(hue: hue, saturation: 1, brightness: brightness)],
                        startPoint: .leading, endPoint: .trailing))
                    thumb.position(x: saturation * geo.size.width, y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    saturation = min(max(value.location.x / geo.size.width, 0), 1)
                    commit()
                })
            }
            .frame(height: 28)
            .accessibilityElement()
            .accessibilityLabel("Saturation")
            .accessibilityValue("\(Int(saturation * 100)) percent")
            .accessibilityAdjustableAction { direction in
                saturation = min(max(saturation + (direction == .increment ? 0.05 : -0.05), 0), 1)
                commit()
            }
        }
        .onAppear { read(color) }
        .onChange(of: ColorComposer.hexKey(color)) { _, hex in
            if hex != lastHex { read(color) }
        }
    }

    private var thumb: some View {
        Circle()
            .strokeBorder(.white, lineWidth: 2)
            .background(Circle().fill(Color(hue: hue, saturation: saturation, brightness: brightness)))
            .frame(width: 24, height: 24)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .allowsHitTesting(false)
    }

    private func set(hue: Double, brightness: Double) {
        self.hue = hue
        self.brightness = brightness
        commit()
    }

    private func commit() {
        let new = Color(hue: hue, saturation: saturation, brightness: brightness)
        lastHex = ColorComposer.hexKey(new)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { onPick(new) }
    }

    /// Reads an outside change. Gray has no hue, so keep the last hue rather
    /// than snapping the thumb to red.
    private func read(_ color: Color) {
        let hsb = color.hsbComponents
        if hsb.s > 0.01 { hue = hsb.h }
        saturation = hsb.s
        brightness = max(hsb.b, Self.minBrightness)
        lastHex = ColorComposer.hexKey(color)
    }
}
```

`Color.hsbComponents` returns all three in 0…1 (`Palettes/Extensions/Color+Extensions.swift:63`).

- [ ] **Step 2: Implement `SwatchGridPicker`** (per behavior above; selection compares `ColorComposer.hexKey(color)` to the cell hex; the "Your Colors" row uses 32 pt circles with a 2 pt ring when selected and `accessibilityLabel(colorVM.name)`).
- [ ] **Step 3: Implement `RGBSliders`** (per behavior above; reading the channels via `color.rgbComponents`, writing via `ColorAdjustment.color(r:g:b:)` inside a no-animation transaction).
- [ ] **Step 4: Implement `ColorPickerPanel`**

```swift
import SwiftUI

enum ColorPickerMode: String, CaseIterable, Identifiable {
    case spectrum, grid, sliders
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spectrum: "Spectrum"
        case .grid: "Grid"
        case .sliders: "Sliders"
        }
    }
}

/// The always-visible picker: Spectrum, Grid or Sliders — the same three
/// modes as Apple's color picker, so it reads as familiar.
struct ColorPickerPanel: View {
    @Binding var color: Color
    var compact = true
    var onPick: (Color) -> Void

    @AppStorage("colorPickerMode") private var modeRaw = ColorPickerMode.spectrum.rawValue
    private var mode: ColorPickerMode { ColorPickerMode(rawValue: modeRaw) ?? .spectrum }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Picker", selection: $modeRaw) {
                ForEach(ColorPickerMode.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)

            Group {
                switch mode {
                case .spectrum: SpectrumPad(color: $color, height: compact ? 180 : 220, onPick: onPick)
                case .grid: SwatchGridPicker(color: $color, onPick: onPick)
                case .sliders: RGBSliders(color: $color, onPick: onPick)
                }
            }
            .transition(.opacity)
        }
        .animation(.snappy, value: modeRaw)
    }
}
```

- [ ] **Step 5: Build** (`xcodebuild build … -destination 'generic/platform=iOS Simulator'`) → succeeds with no new warnings. Add `#Preview { ColorPickerPanel(color: .constant(.orange), onPick: { _ in }).padding().environmentObject(AppData(inMemory: true)) }` in `ColorPickerPanel.swift`.
- [ ] **Step 6: Commit** `git add Palettes/Views/Components/ColorPicking && git commit -m "Add the inline color picker: Spectrum, Grid and RGB Sliders"`

---

### Task 6: `ColorComposer` layout — pinned hero + picker, scrolling Fine-tune and Values

**Files:**
- Modify: `Palettes/Views/Components/ColorComposer.swift`

**Interfaces:**
- Consumes: `ColorPickerPanel(color:compact:onPick:)` (Task 5), existing `apply(_:from:)`, `AdjustmentSlider`, `PhotoColorPickerView`, `CameraPicker`.
- Produces (unchanged public API, plus one addition): `ColorComposer(color:name:namesFollowColor:notice:)` and new optional `var tag: (role: String?, onTap: () -> Void)? = nil` — when non-nil, a "Tag" row (`LabeledContent("Tag") { Text(role ?? "None") }` as a `Button`, chevron) appears as the first section in the scrolling part.

Changes:
1. **Header (pinned):** a compact swatch, 96 pt tall (64 pt while a value field has focus), corner 22, `color.gradient`, with:
   - bottom-leading: the name as a borderless `TextField` in `legibleInk`, `.title3.weight(.semibold)`, placeholder "Name"; under it the hex in `.subheadline.monospaced()` at 0.7 opacity. Long-press the swatch → context menu "Copy HEX" (keep).
   - top-trailing: an eyedropper `Menu` (`Image(systemName: "eyedropper")` in a 36 pt circle of `.ultraThinMaterial`, `accessibilityLabel("Sample a Photo")`) with `Button("Choose Photo", systemImage: "photo.on.rectangle")` and, when the camera exists, `Button("Take Photo", systemImage: "camera")`. These drive the existing `showPhotoLibrary` / `showCamera` state.
   - the notice line stays under the swatch.
2. **Picker (pinned):** `ColorPickerPanel(color: $color, compact: !isRegular, onPick: { apply($0, from: .outside) })` directly under the header, horizontal padding 16. Hidden while a value field has focus (`if !isEditingValues`), with `.transition(.opacity)`.
3. **Form (scrolls):** remove `pickerSection` and `photoActions`. Sections in order: optional Tag, **Fine-tune** (rename header from "Adjustments"; same three `AdjustmentSlider`s; footer "Nudge the color warmer, richer or lighter.") and **Values** (unchanged).
4. **Regular width (Q22):** read `@Environment(\.horizontalSizeClass)`; when `.regular`, lay out `HStack(alignment: .top, spacing: 20) { VStack { header; picker }.frame(maxWidth: 380); Form { … } }`.
5. Motion: swatch height change and picker hide/show use `.spring(duration: 0.35, bounce: 0)`; with `@Environment(\.accessibilityReduceMotion)` true, use `.easeInOut(duration: 0.2)` and opacity only. Keyboard focus changes do not animate anything else.

- [ ] **Step 1: Make the changes above.** Keep every existing binding/sync helper (`apply`, `syncedHex`, `restoreIncompleteField`, hex paste, `hexKey`) untouched.
- [ ] **Step 2: Build** → succeeds.
- [ ] **Step 3: Run on the sim** (New Color from the Colors tab): drag the spectrum — swatch, HEX/RGB fields and Fine-tune all follow; switch to Grid and Sliders; focus HEX — swatch shrinks, picker hides; Done restores. Screenshot each state into the task report.
- [ ] **Step 4: Commit** `git commit -am "Color editor: pinned swatch and inline picker; Fine-tune and Values scroll below"`

---

### Task 7: Toolbar buttons — ✓ for create/save, + for add, on every iOS

**Files:**
- Modify: `Palettes/Compatibility/SheetToolbarCompat.swift`, `Palettes/Views/Components/PaletteColorPages.swift`, and every `SheetConfirmButton(title:)` call site (`NewColorView`, `ColorEditView`, `NewPaletteView`).

**Interfaces:**
- Produces:
  ```swift
  struct SheetConfirmButton: View {
      enum Kind { case create, save, add(count: Int? = nil) }
      let kind: Kind
      var action: () -> Void
  }
  ```
  Titles: `.create` "Create", `.save` "Save", `.add(nil)` "Add", `.add(n)` "Add \(n)". Symbols: create/save `checkmark`, add `plus`.

- [ ] **Step 1: Implement**

```swift
struct SheetConfirmButton: View {
    enum Kind {
        case create, save, add(count: Int? = nil)
    }
    let kind: Kind
    var action: () -> Void

    private var title: String {
        switch kind {
        case .create: "Create"
        case .save: "Save"
        case .add(let count?): "Add \(count)"
        case .add(nil): "Add"
        }
    }

    private var symbol: String {
        if case .add = kind { return "plus" }
        return "checkmark"
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Label(title, systemImage: symbol)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(action: action) {
                Label(title, systemImage: symbol)
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
            }
            .accessibilityLabel(title)
        }
    }
}
```

For `.add(count:)` with a count ≥ 1, use `.labelStyle(.titleAndIcon)` on both branches so "+ Add 3" reads. Update the file header comment to state the rule. `SheetCancelButton` on iOS 17–25 becomes an ✕ `Label("Cancel", systemImage: "xmark")` with `.labelStyle(.iconOnly)` too, so both sides match.

- [ ] **Step 2: Update call sites**: New Color → `.create`; Edit Color → `.save`; New Palette → `.create`; Edit Palette (Task 11) → `.save`; `NewPaletteColorPage` "Add" → `SheetConfirmButton(kind: .add()) { add() }`; `LibraryColorPicker` → `SheetConfirmButton(kind: .add(count: selection.count)) { add() }` (keep `.disabled(selection.isEmpty)`).
- [ ] **Step 3: Build** on iOS 26 and iOS 17 destinations → both succeed.
- [ ] **Step 4: Commit** `git commit -am "Sheet buttons: ✓ to create or save, + to add, on every iOS"`

---

### Task 8: New Color and Edit Color — vivid start, context save, no overwrite dialog

**Files:**
- Modify: `Palettes/Views/Color/NewColorView.swift`, `Palettes/Views/Color/ColorEditView.swift`, `Palettes/Views/Palette/PaletteDetailView.swift:177-187` and `:436-462`, `Palettes/Views/Components/PaletteEditSheet.swift` (call site only until Task 11 replaces it).

**Interfaces:**
- Produces: `ColorEditView(colorName:hexCode:colorValue:onSave:)` — `promptOnNameMatch` and `onSaveWithAction` are removed.

Steps:
- [ ] **Step 1: New Color start** — initial state `Color(hex: ColorPickerModel.randomStarter()) ?? .orange`, with `namesFollowColor: true` (already true) so the name follows.
- [ ] **Step 2: Edit Color** — delete `promptOnNameMatch`, `onSaveWithAction`, `showOverwriteAlert` and the alert; `handleSaveTapped()` → `saveChanges(); dismiss()`; `saveChanges()` writes the bindings then calls `onSave()`.
- [ ] **Step 3: Palette detail (Q17)** — the call site passes `onSave: { syncEditedPaletteColor(at: wrapper.id) }`, and `syncEditedPaletteColor(at:)` becomes:

```swift
/// A color edited from a palette changes only that palette. If its new hex
/// isn't in the library yet, it joins it; library colors are never altered.
private func syncEditedPaletteColor(at index: Int) {
    guard let paletteIdx = paletteIndex,
          index < appData.palettes[paletteIdx].paletteColors.count else { return }
    let edited = appData.palettes[paletteIdx].paletteColors[index]
    let known = appData.colors.contains { $0.HEX.caseInsensitiveCompare(edited.hex) == .orderedSame }
    if !known {
        appData.colors.append(ColorViewModel(name: edited.name, color: edited.color, HEX: edited.hex, usedInPalette: true))
    }
}
```

- [ ] **Step 4:** Make `PaletteEditSheet`'s Edit Color call compile the same way (temporary; Task 11 replaces the file).
- [ ] **Step 5: Build + run**: edit a color in palette detail → only that palette changes; the library gains the new hex; no dialog. Edit from the Colors tab → library color changes.
- [ ] **Step 6: Commit** `git commit -am "Edit Color saves by context; New Color starts on a vivid color"`

---

### Task 9: `RoleList` — the tag list, usable from a draft

**Files:**
- Create: `Palettes/Views/Components/RoleList.swift`
- Modify: `Palettes/Views/Components/RolePickerSheet.swift`

**Interfaces:**
- Produces:
  ```swift
  struct RoleList: View {
      let current: String?
      var onSelect: (String?) -> Void      // nil = remove tag
  }
  ```
  It holds the `List` body currently inside `RolePickerSheet` (built-in roles, custom tags, new-tag field, rename, remove) and reads `appData.customTags` from the environment. It never writes palettes.

- [ ] **Step 1:** Move the list body from `RolePickerSheet` into `RoleList`, replacing every direct palette write with `onSelect(role)`. Tag creation/rename stay as they are (they edit `appData.customTags`, which is app-wide, not palette data).
- [ ] **Step 2:** `RolePickerSheet.body` becomes `NavigationStack { RoleList(current: liveCurrentRole, onSelect: assign(role:)) … }` with its existing title/toolbar; `assign(role:)` keeps its delayed write (palette detail still uses the sheet).
- [ ] **Step 3: Build + run**: tagging from palette detail still works and still animates the badge.
- [ ] **Step 4: Commit** `git commit -am "Extract RoleList so tags can be edited in a draft"`

---

### Task 10: `PaletteStripEditor` — the strip is the editor

**Files:**
- Create: `Palettes/Views/Palette/Editor/PaletteStripEditor.swift`

**Interfaces:**
- Consumes: `PaletteDraft` (Task 2), Task 1 findings.
- Produces:
  ```swift
  struct PaletteStripEditor: View {
      @Binding var draft: PaletteDraft
      @Binding var selection: UUID?             // the band "Colors That Go With…" uses
      var onEdit: (UUID) -> Void
      var onTag: (UUID) -> Void
      var addMenu: AnyView                     // the + menu content, supplied by PaletteEditor
      var onRemove: (_ index: Int, _ color: PaletteColor) -> Void   // for the Undo toast
  }
  ```

Behavior:
- Height 120 (one column, all widths). Bands share width equally; the **+** sits as a 44 pt-wide trailing tile inside the strip's rounded shape (dashed outline, `plus` symbol, `Menu { addMenu }`, `accessibilityLabel("Add Color")`).
- Tap a band → `selection = id` then `onEdit(id)`. The selected band shows a 3 pt inner ring in `legibleInk`.
- Context menu per band: Edit (`pencil`), Duplicate (`plus.square.on.square`), Tag… (`tag`), Remove (`trash`, destructive). Remove calls `draft.remove(id:)` then `onRemove`.
- Reorder per Task 1 findings: lifted band `scaleEffect(1.03)`, `zIndex(1)`, shadow; follows the finger 1:1 (no animation); neighbors slide with `.spring(duration: 0.35, bounce: 0)` as the target slot changes; drop settles with `.spring(duration: 0.35, bounce: 0.15)`; `.sensoryFeedback(.selection, trigger: targetSlot)`. Commit with `draft.move(id:to:)`.
- Each band: `accessibilityElement`, label "\(name), \(hex)", `accessibilityHint("Double-tap to edit")`, custom actions Move Left / Move Right / Duplicate / Tag / Remove.
- Reduce Motion: no scale/offset; reorder via the accessibility actions and an opacity cross-fade on drop.
- Band with a role shows a small capsule with the role name at the bottom, in `legibleInk` on `ink.opacity(0.15)`.

- [ ] **Step 1: Implement** per above, reusing the Task 1 gesture setup.
- [ ] **Step 2: Preview** with a 5-color draft; build.
- [ ] **Step 3: Commit** `git add Palettes/Views/Palette/Editor/PaletteStripEditor.swift && git commit -m "Add PaletteStripEditor: tap, reorder, menu and + on the strip"`

---

### Task 11: `PaletteEditor` — one editor for New and Edit Palette; remove the Add Colors sheet

**Files:**
- Create: `Palettes/Views/Palette/Editor/PaletteEditor.swift`, `Palettes/Views/Palette/Editor/PaletteStartTiles.swift`
- Modify: `Palettes/Views/Palette/NewPaletteView.swift` (becomes a wrapper), `Palettes/Views/Components/PaletteEditSheet.swift` (becomes a wrapper)
- Delete: `Palettes/Views/Components/AddColorToPaletteSheet.swift`

**Interfaces:**
- Consumes: Tasks 2, 7, 9, 10; `LibraryColorPicker`, `NewPaletteColorPage`, `ColorComposer`, `PaletteNamer.descriptiveName(forHexes:existingNames:)`, `AppData.activeTab`, `TabValue.generate`.
- Produces:
  ```swift
  struct PaletteEditor: View {
      enum Mode { case create, edit(paletteID: UUID) }
      let mode: Mode
      @State var draft: PaletteDraft            // seeded by the wrapper
      var onConfirm: (PaletteDraft, _ resolvedName: String) -> Void
  }
  // routes pushed inside the editor's NavigationStack:
  enum PaletteEditorRoute: Hashable { case newColor, library, edit(UUID), tag(UUID), harmony(base: String?), photo }
  ```
  `HarmonyPage` and `PhotoPinsPage` are referenced here and built in Tasks 12–13; until then, those routes show `Text("Coming in Task 12/13")` **only on the branch, never committed past Task 13**.

Layout:
- Pinned header: `PaletteStripEditor` (when the draft has colors) or the dashed empty strip; under it the name field (as in 017, placeholder = suggestion).
- Below (a `List`, `.insetGrouped`):
  - **Empty draft:** `PaletteStartTiles` — a 2×2 grid of tiles inside one clear-background row: From a Photo (`photo.fill`, menu Choose Photo / Take Photo), From My Colors (`square.grid.2x2.fill`, hidden if the library is empty), From One Color (`circle.lefthalf.filled`), Generate with AI (`sparkles` + small `arrow.up.forward`, only when `#available(iOS 26.0, *)` and the Generate tab exists). Tiles: 88 pt tall, corner 18, `.secondarySystemGroupedBackground`, symbol in a tinted circle like `SettingsRowLabel`, title `.headline`, one-line subtitle `.footnote` secondary ("Pull colors from a picture", "Pick from colors you've saved", "Build around a single color", "Opens the Generate tab"). Pressed state `scaleEffect(0.97)` with `.snappy`. Below the grid: `Button("Start Blank")` (plain, secondary) → pushes `.newColor`.
  - **With colors:** a section with the footer text "Tap a color to edit it. Touch and hold to move it." and, when `draft.colors.count == 1`, "Add one more color to create the palette."
- **+ menu** (Q16): New Color (`.newColor`), From My Colors (`.library`), From a Photo (Choose/Take → `.photo` after loading), Colors That Go With… (`.harmony(base: selectedHex ?? last hex)`).
- **Generate tile:** `appData.activeTab = .generate; dismiss()` (draft is empty, so no discard prompt).
- Toolbar: Cancel (asks "Discard this palette?" / "Discard changes?" when `draft != original`), confirm `SheetConfirmButton(kind: mode == .create ? .create : .save)` disabled unless `draft.canSave`.
- `.interactiveDismissDisabled(draft != original)`.
- Remove → `ToastManager.shared.show("Color removed", icon: "trash.fill") { reinsert at index }` (in-draft undo).
- Pushed `.edit(id)`: `ColorComposer(color:name:)` bound into the draft (keep hex in step as in 017) with `tag: (role, { path.append(.tag(id)) })`.
- Pushed `.tag(id)`: `RoleList(current: role) { draft.setRole($0, for: id); path.removeLast() }`.

Wrappers:
- `NewPaletteView(preselectedColor:)` → `PaletteEditor(mode: .create, draft: PaletteDraft(colors: preselected.map { [PaletteColor(...)] } ?? []), onConfirm: create)`; `create` keeps 017's duplicate-palette / duplicate-name alerts and the library append, now using `draft.finalizedColors()`.
- `PaletteEditSheet(paletteName:palette:)` keeps its signature → `PaletteEditor(mode: .edit(paletteID: palette.id), draft: PaletteDraft(palette: livePalette), onConfirm: save)`; `save` writes `name` and `paletteColors` into `appData.palettes[idx]` in one assignment and appends unknown hexes to the library (as New Palette does).

- [ ] **Step 1:** Build `PaletteStartTiles`.
- [ ] **Step 2:** Build `PaletteEditor` per above.
- [ ] **Step 3:** Rewrite both wrappers; delete `AddColorToPaletteSheet.swift` and confirm nothing references it: `grep -rn AddColorToPaletteSheet Palettes` → no results.
- [ ] **Step 4: Build + run**: create a palette via each tile and Start Blank; reorder, duplicate, tag, remove + undo; Cancel with changes asks; open Edit Palette, change things, Cancel → unchanged; ✓ → saved; Generate tile switches tabs.
- [ ] **Step 5: Commit** `git add -A Palettes && git commit -m "One palette editor for New and Edit Palette; remove the Add Colors sheet"`

---

### Task 12: `HarmonyPage` — From One Color and Colors That Go With…

**Files:**
- Create: `Palettes/Views/Palette/Editor/HarmonyPage.swift`
- Modify: `PaletteEditor.swift` (route `.harmony`)

**Interfaces:**
- Consumes: `ColorPickerPanel`, `ColorPickerModel.harmonies(for:)`, `PaletteStrip`.
- Produces: `HarmonyPage(base: String?, onChoose: ([PaletteColor]) -> Void)`.

Behavior: pinned `ColorPickerPanel` (seeded with `base` or a random starter) under a 56 pt swatch; below, a `List` section "Harmonies" with one row per scheme: the scheme's `title` and a 40 pt `PaletteStrip` of its hexes, recomputed live as the color changes (debounce not needed — `PaletteBuilder` is cheap; if profiling shows >8 ms, compute in `.task(id: hex)`). Tapping a row: from the empty start → `draft.replaceAll`, from the + menu → `draft.append` (skip the base hex if it's already in the draft); then pop back to the editor. Each row's accessibility label: "\(title): \(names joined)". A row's toolbar button is not used; the tap is the add, so the row shows a trailing `plus.circle` symbol.

- [ ] **Step 1:** Implement. **Step 2:** Build + run both entry points. **Step 3:** Commit `git commit -am "From One Color: live harmony previews"`

---

### Task 13: `PhotoPinsPage` — the photo with draggable pins

**Files:**
- Create: `Palettes/Views/Palette/Editor/PhotoPinsPage.swift`
- Modify: `PaletteEditor.swift` (route `.photo`; photo loading moves here from 017's `useColors`)

**Interfaces:**
- Consumes: `ImageColorExtractor.extractColors(from:count:)`, `ImageColorExtractor.PixelSampler`, `PhotoPinLocator.locate(hexes:in:)`, `PhotoLoupeGeometry.imageRect(imageSize:in:)` / `normalizedPoint(in:at:)`, `ColorNamer.name(forHex:)`.
- Produces: `PhotoPinsPage(image: UIImage, onAdd: ([PaletteColor]) -> Void)`.

Behavior:
- On appear: extract 6 colors, build a sampler, locate pins. Show the photo aspect-fit; a 30 pt pin per color (filled with its color, 3 pt white ring, shadow, number badge for VoiceOver order).
- A 56 pt `PaletteStrip` of the current pin colors is pinned under the photo, so dragging a pin updates the strip live.
- Dragging a pin: follows the finger 1:1, clamped to the image rect, samples via `sampler.color(at:radius: 2)` each move; the pin lifts `scaleEffect(1.15)` while dragged (none with Reduce Motion); `.sensoryFeedback(.selection, trigger: pinColorHex)` is **not** used (too frequent).
- Toolbar: `SheetConfirmButton(kind: .add(count: pins.count))` → `onAdd` (empty start → replace; + menu → append), then pop.
- Accessibility: each pin is an element "Color \(n), \(name)" with adjustable action nudging it 5% left/right.

- [ ] **Step 1:** Implement. **Step 2:** Build + run with a real photo; drag pins; add. **Step 3:** Commit `git commit -am "From a Photo: draggable pins that update the palette live"`

---

### Task 14: Motion and accessibility pass, then audits and builds

- [ ] **Step 1:** Walk every editor against the Global Constraints motion spec; fix deviations. Verify Reduce Motion (Settings → Accessibility → Motion on the sim) removes scale/offset everywhere in Tasks 5–13.
- [ ] **Step 2:** Run the `improve-animations` skill over `Palettes/Views/Components/ColorPicking`, `Palettes/Views/Components/ColorComposer.swift`, `Palettes/Views/Palette/Editor`; apply the P0/P1 findings that fit the spec; list the rest under "Follow-ups".
- [ ] **Step 3:** Dynamic Type at AX5: the tiles wrap to one column; the swatch name truncates, not clips; Values fields don't overflow.
- [ ] **Step 4:** VoiceOver: the spectrum, saturation track, grid, sliders, bands and pins are all adjustable or actionable as specified.
- [ ] **Step 5:** Build for iOS 26/27 (`sheets-018`) and iOS 17 sims; run the full test suite once on `sheets-018`. Zero new warnings.
- [ ] **Step 6:** Update `plans/README.md` (row 018, status), set 017's status line to "Superseded by 018 for the color and palette sheets", run `graphify update .`, delete the throwaway sim.
- [ ] **Step 7: Commit** `git commit -am "Sheets r3: motion and accessibility pass; plans updated"`
- [ ] **Step 8:** Opus final review of the branch (`superpowers:requesting-code-review`).

---

## Verification checklist (device/sim)

- [ ] New Color opens on a vivid color; spectrum/grid/sliders/Fine-tune/HEX/RGB stay in sync; eyedropper → Choose Photo / Take Photo → sampler → color set.
- [ ] Edit Color from: Colors tab, color detail, palette detail (only the palette changes), Edit Palette (draft), Generate result.
- [ ] New Palette: each tile; Start Blank; Generate tile switches tabs; 2-color minimum; blank name uses the suggestion; duplicate alerts.
- [ ] Strip: tap edits, hold-drag reorders with lift and settle, menu Edit/Duplicate/Tag…/Remove, + menu entries, remove → Undo.
- [ ] Edit Palette: Cancel discards, ✓ saves, swipe-down blocked with changes.
- [ ] Buttons: ✓ on create/save, + on add, on iOS 17 and iOS 26.
- [ ] iPad / iPhone Duo inner display: color editor two columns; palette editor one column; toolbar items titled.
- [ ] Reduce Motion, Dynamic Type AX5, VoiceOver.

## Prototype findings

_(Filled in by Task 1.)_

## Follow-ups

- `ColorDetailView` could use `ColorWashBackground` in place of its inline copy (from 017).
- Paywall / purchase flow for Premium (from 017).
