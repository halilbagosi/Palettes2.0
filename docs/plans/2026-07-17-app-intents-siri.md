# App Intents + Siri (Apple Intelligence) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose generate/create/save/find/open/get-hex capabilities to Siri, Apple Intelligence, Spotlight, and Shortcuts via App Intents.

**Architecture:** A new `Palettes/Intents/` folder holds App Entities backed by the app's single shared `AppData` store (which becomes a singleton), six intents, snippet views, and an `AppShortcutsProvider`. Entities are donated to Spotlight via `IndexedEntity` so the LLM Siri can resolve library content. Open intents deep-link through a new `pendingOpenPaletteID` on `AppData`.

**Tech Stack:** Swift, SwiftUI, App Intents, CoreSpotlight, SwiftData (existing store), FoundationModels (existing `PaletteGenerator`).

## Global Constraints

- Spec: `docs/specs/2026-07-17-app-intents-siri-design.md`.
- All new intent code is `@available(iOS 26.0, *)` (matches `PaletteGenerator`; entities/queries may be iOS 18+ but keeping one floor is simpler and the app targets iOS 26+ devices anyway).
- New files under `Palettes/Intents/` and `PalettesTests/` are auto-included via synchronized groups — do NOT edit `project.pbxproj`.
- **This machine has no Xcode.** "Run tests" steps cannot execute locally: perform a careful self-review of the code instead, and leave the checkbox annotated `(deferred: needs Xcode)` — never claim tests passed. The final task collects the on-device checklist.
- Persistence must go through `AppData` published arrays (debounced upsert persistence, plan-002 hardened). Never create a second `ModelContainer`.
- Palette size clamped to 2–10, default 5.

---

### Task 1: AppData singleton + intent-facing mutation API

**Files:**
- Modify: `Palettes/App/AppData.swift` (class `AppData`, `init` unchanged)
- Modify: `Palettes/Views/Main/PaletteTabView.swift:12`
- Test: `PalettesTests/AppDataIntentAPITests.swift`

**Interfaces:**
- Produces: `AppData.shared: AppData` (main-actor singleton), plus on `AppData`:
  - `@discardableResult func addPalette(name: String, paletteColors: [PaletteColor]) -> PaletteViewModel`
  - `@discardableResult func addColor(name: String, hex: String) -> ColorViewModel`
  - `@Published var pendingOpenPaletteID: UUID?`
- Consumes: existing `PaletteViewModel`, `ColorViewModel`, `PaletteColor` value types.

- [ ] **Step 1: Write the failing tests**

Create `PalettesTests/AppDataIntentAPITests.swift`:

```swift
import Testing
import SwiftUI
@testable import Palettes

@MainActor
struct AppDataIntentAPITests {
    @Test func addPaletteAppendsAndReturnsModel() {
        let data = AppData(inMemory: true)
        let before = data.palettes.count
        let colors = [PaletteColor(color: .red, hex: "#FF0000", name: "Red")]
        let created = data.addPalette(name: "Test Reds", paletteColors: colors)
        #expect(data.palettes.count == before + 1)
        #expect(data.palettes.last?.id == created.id)
        #expect(created.name == "Test Reds")
        #expect(created.hexCodes == ["#FF0000"])
    }

    @Test func addColorAppendsAndReturnsModel() {
        let data = AppData(inMemory: true)
        let before = data.colors.count
        let created = data.addColor(name: "Crimson", hex: "#DC143C")
        #expect(data.colors.count == before + 1)
        #expect(data.colors.last?.id == created.id)
        #expect(created.HEX == "#DC143C")
        #expect(created.usedInPalette == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Palettes -only-testing:PalettesTests/AppDataIntentAPITests` — expected FAIL (`addPalette` undefined). No Xcode here: self-review and annotate `(deferred: needs Xcode)`.

- [ ] **Step 3: Implement**

In `Palettes/App/AppData.swift`, inside `class AppData`, add below the `@Published` properties:

```swift
    /// Single app-wide instance shared by the UI and App Intents so both see
    /// (and persist through) the same in-memory library.
    static let shared = AppData()

    /// Palette id an Open intent asked to show; PaletteView consumes it.
    @Published var pendingOpenPaletteID: UUID?
```

Add a new section before `// MARK: - Favorites`:

```swift
    // MARK: - Intent API

    /// Appends a palette; the debounced sink persists it.
    @discardableResult
    func addPalette(name: String, paletteColors: [PaletteColor]) -> PaletteViewModel {
        let palette = PaletteViewModel(name: name, paletteColors: paletteColors)
        palettes.append(palette)
        return palette
    }

    /// Appends a standalone color; the debounced sink persists it.
    @discardableResult
    func addColor(name: String, hex: String) -> ColorViewModel {
        let color = ColorViewModel(
            name: name,
            color: Color(hex: hex) ?? .gray,
            HEX: hex,
            usedInPalette: false
        )
        colors.append(color)
        return color
    }
```

In `Palettes/Views/Main/PaletteTabView.swift` replace line 12:

```swift
    @StateObject private var appData = AppData()
```

with:

```swift
    @ObservedObject private var appData = AppData.shared
```

- [ ] **Step 4: Run tests** — same command; expected PASS. `(deferred: needs Xcode)` — self-review instead.

- [ ] **Step 5: Commit**

```bash
git add Palettes/App/AppData.swift Palettes/Views/Main/PaletteTabView.swift PalettesTests/AppDataIntentAPITests.swift
git commit -m "feat: expose shared AppData with intent-facing add APIs"
```

---

### Task 2: App Entities and queries

**Files:**
- Create: `Palettes/Intents/PaletteEntity.swift`
- Create: `Palettes/Intents/ColorEntity.swift`

**Interfaces:**
- Consumes: `AppData.shared.palettes/.colors` (Task 1), `PaletteViewModel`, `ColorViewModel`.
- Produces: `PaletteEntity(id: UUID, name: String, hexCodes: [String])` with `init(_ palette: PaletteViewModel)`; `ColorEntity(id: UUID, name: String, hex: String)` with `init(_ color: ColorViewModel)`; `PaletteEntityQuery`, `ColorEntityQuery` (both `EntityStringQuery`).

- [ ] **Step 1: Create `Palettes/Intents/PaletteEntity.swift`**

```swift
//
//  PaletteEntity.swift
//  Palettes
//
//  App Intents representation of a saved palette, resolvable by Siri,
//  Shortcuts, and Spotlight.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct PaletteEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Palette")
    static let defaultQuery = PaletteEntityQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Colors")
    var hexCodes: [String]

    init(id: UUID, name: String, hexCodes: [String]) {
        self.id = id
        self.name = name
        self.hexCodes = hexCodes
    }

    @MainActor
    init(_ palette: PaletteViewModel) {
        self.init(id: palette.id, name: palette.name, hexCodes: palette.hexCodes)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(hexCodes.count) colors",
            image: .init(systemName: "swatchpalette.fill")
        )
    }
}

@available(iOS 26.0, *)
struct PaletteEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PaletteEntity] {
        AppData.shared.palettes
            .filter { identifiers.contains($0.id) }
            .map(PaletteEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PaletteEntity] {
        AppData.shared.palettes
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(PaletteEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PaletteEntity] {
        AppData.shared.palettes.prefix(10).map(PaletteEntity.init)
    }
}
```

- [ ] **Step 2: Create `Palettes/Intents/ColorEntity.swift`**

```swift
//
//  ColorEntity.swift
//  Palettes
//
//  App Intents representation of a saved color.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct ColorEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Color")
    static let defaultQuery = ColorEntityQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Hex Code")
    var hex: String

    init(id: UUID, name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = hex
    }

    @MainActor
    init(_ color: ColorViewModel) {
        self.init(id: color.id, name: color.name, hex: color.HEX)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(hex)",
            image: .init(systemName: "circle.fill")
        )
    }
}

@available(iOS 26.0, *)
struct ColorEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ColorEntity] {
        AppData.shared.colors
            .filter { identifiers.contains($0.id) }
            .map(ColorEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ColorEntity] {
        AppData.shared.colors
            .filter {
                $0.name.localizedCaseInsensitiveContains(string)
                    || $0.HEX.localizedCaseInsensitiveContains(string)
            }
            .map(ColorEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ColorEntity] {
        AppData.shared.colors.prefix(10).map(ColorEntity.init)
    }
}
```

- [ ] **Step 3: Self-review** (no Xcode): check both files compile by inspection — imports, availability, protocol requirements (`typeDisplayRepresentation`, `defaultQuery`, `displayRepresentation`, three query methods each).

- [ ] **Step 4: Commit**

```bash
git add Palettes/Intents/PaletteEntity.swift Palettes/Intents/ColorEntity.swift
git commit -m "feat: add Palette and Color app entities with queries"
```

---

### Task 3: Snippet views

**Files:**
- Create: `Palettes/Intents/IntentSnippets.swift`

**Interfaces:**
- Produces: `PaletteSnippetView(name: String, hexCodes: [String])`, `ColorSnippetView(name: String, hex: String)` — SwiftUI views used by Tasks 4–5.
- Consumes: existing `Color(hex:)` failable initializer.

- [ ] **Step 1: Create `Palettes/Intents/IntentSnippets.swift`**

```swift
//
//  IntentSnippets.swift
//  Palettes
//
//  Compact SwiftUI views shown inside Siri / Shortcuts result snippets.
//

import SwiftUI

@available(iOS 26.0, *)
struct PaletteSnippetView: View {
    let name: String
    let hexCodes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.headline)
            HStack(spacing: 6) {
                ForEach(Array(hexCodes.enumerated()), id: \.offset) { _, hex in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(height: 44)
                }
            }
        }
        .padding()
    }
}

@available(iOS 26.0, *)
struct ColorSnippetView: View {
    let name: String
    let hex: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(hex).font(.subheadline.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}
```

- [ ] **Step 2: Self-review** — pure SwiftUI, no store access; verify `Color(hex:)` exists in `Palettes/Extensions/Color+Extensions.swift`.

- [ ] **Step 3: Commit**

```bash
git add Palettes/Intents/IntentSnippets.swift
git commit -m "feat: add snippet views for intent results"
```

---

### Task 4: Headless intents — Generate, Create, Save Color

**Files:**
- Create: `Palettes/Intents/IntentErrors.swift`
- Create: `Palettes/Intents/GeneratePaletteIntent.swift`
- Create: `Palettes/Intents/CreatePaletteIntent.swift`
- Create: `Palettes/Intents/SaveColorIntent.swift`

**Interfaces:**
- Consumes: `AppData.shared.addPalette/addColor` (Task 1), `PaletteEntity`/`ColorEntity` (Task 2), snippet views (Task 3), `PaletteGenerator.generate(baseColors:size:vibe:onPartialColors:)`, `ColorNamer.name(forHex:)`, `Color(hex:)`.
- Produces: `PalettesIntentError` enum reused by Tasks 5–6.

- [ ] **Step 1: Create `Palettes/Intents/IntentErrors.swift`**

```swift
//
//  IntentErrors.swift
//  Palettes
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
enum PalettesIntentError: Error, CustomLocalizedStringResourceConvertible {
    case aiUnavailable
    case invalidHex(String)
    case paletteNotFound
    case colorNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .aiUnavailable:
            return "Apple Intelligence isn't available on this device, so palettes can't be generated."
        case .invalidHex(let value):
            return "'\(value)' isn't a valid hex color. Try something like #4A90D9."
        case .paletteNotFound:
            return "That palette couldn't be found in your library."
        case .colorNotFound:
            return "That color couldn't be found in your library."
        }
    }
}
```

- [ ] **Step 2: Create `Palettes/Intents/GeneratePaletteIntent.swift`**

```swift
//
//  GeneratePaletteIntent.swift
//  Palettes
//
//  Headless Siri/Shortcuts entry point into on-device palette generation.
//

import AppIntents
import FoundationModels

@available(iOS 26.0, *)
struct GeneratePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Palette"
    static let description = IntentDescription(
        "Generates a new color palette with Apple Intelligence and saves it to your library."
    )

    @Parameter(title: "Vibe", description: "The mood or theme, like 'warm sunset' or 'calm ocean'.")
    var vibe: String

    @Parameter(title: "Number of Colors", default: 5, controlStyle: .stepper, inclusiveRange: (2, 10))
    var size: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$vibe) palette with \(\.$size) colors")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog & ShowsSnippetView {
        guard case .available = SystemLanguageModel.default.availability else {
            throw PalettesIntentError.aiUnavailable
        }

        let generated = try await PaletteGenerator.generate(
            baseColors: [],
            size: min(max(size, 2), 10),
            vibe: vibe
        )
        let saved = AppData.shared.addPalette(name: generated.name, paletteColors: generated.paletteColors)

        return .result(
            value: PaletteEntity(saved),
            dialog: "Saved '\(saved.name)' to your library.",
            view: PaletteSnippetView(name: saved.name, hexCodes: saved.hexCodes)
        )
    }
}
```

- [ ] **Step 3: Create `Palettes/Intents/CreatePaletteIntent.swift`**

```swift
//
//  CreatePaletteIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct CreatePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Palette"
    static let description = IntentDescription("Creates a new empty palette in your library.")

    @Parameter(title: "Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create a palette named \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog {
        let saved = AppData.shared.addPalette(name: name, paletteColors: [])
        return .result(
            value: PaletteEntity(saved),
            dialog: "Created '\(saved.name)'."
        )
    }
}
```

- [ ] **Step 4: Create `Palettes/Intents/SaveColorIntent.swift`**

```swift
//
//  SaveColorIntent.swift
//  Palettes
//

import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct SaveColorIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Color"
    static let description = IntentDescription("Saves a hex color to your library.")

    @Parameter(title: "Hex Code", description: "A hex color like #4A90D9.")
    var hex: String

    @Parameter(title: "Name", description: "Leave empty to name it automatically.")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$hex) as \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ColorEntity> & ProvidesDialog & ShowsSnippetView {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("#") ? trimmed.uppercased() : "#" + trimmed.uppercased()
        guard Color(hex: normalized) != nil else {
            throw PalettesIntentError.invalidHex(hex)
        }

        let resolvedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = (resolvedName?.isEmpty == false) ? resolvedName! : ColorNamer.name(forHex: normalized)
        let saved = AppData.shared.addColor(name: finalName, hex: normalized)

        return .result(
            value: ColorEntity(saved),
            dialog: "Saved '\(saved.name)' (\(saved.HEX)).",
            view: ColorSnippetView(name: saved.name, hex: saved.HEX)
        )
    }
}
```

Note: `ColorNamer.name(forHex:)` lives at `Palettes/Utilities/HEXParser.swift:445` — verify the enclosing type is really named `ColorNamer` before using; adjust the call to the actual type name if different.

- [ ] **Step 5: Self-review** — availability guards, error paths, no second container, `PaletteGenerator.generate` signature matches `Palettes/Managers/PaletteGenerator.swift:46` (omitting the trailing `onPartialColors` closure is valid since it defaults to `nil`).

- [ ] **Step 6: Commit**

```bash
git add Palettes/Intents/IntentErrors.swift Palettes/Intents/GeneratePaletteIntent.swift Palettes/Intents/CreatePaletteIntent.swift Palettes/Intents/SaveColorIntent.swift
git commit -m "feat: add generate, create, and save-color app intents"
```

---

### Task 5: Find and Get Hex intents

**Files:**
- Create: `Palettes/Intents/FindPalettesIntent.swift`
- Create: `Palettes/Intents/GetColorHexIntent.swift`

**Interfaces:**
- Consumes: `PaletteEntity`, `ColorEntity`, `ColorSnippetView`, `PalettesIntentError`.

- [ ] **Step 1: Create `Palettes/Intents/FindPalettesIntent.swift`**

```swift
//
//  FindPalettesIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct FindPalettesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Palettes"
    static let description = IntentDescription("Finds palettes in your library, optionally filtered by name.")

    @Parameter(title: "Search Term")
    var searchTerm: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Find palettes matching \(\.$searchTerm)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PaletteEntity]> {
        let all = AppData.shared.palettes
        let matches: [PaletteViewModel]
        if let term = searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines), !term.isEmpty {
            matches = all.filter { $0.name.localizedCaseInsensitiveContains(term) }
        } else {
            matches = all
        }
        return .result(value: matches.map(PaletteEntity.init))
    }
}
```

- [ ] **Step 2: Create `Palettes/Intents/GetColorHexIntent.swift`**

```swift
//
//  GetColorHexIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct GetColorHexIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Color Hex"
    static let description = IntentDescription("Returns the hex code of a saved color.")

    @Parameter(title: "Color")
    var color: ColorEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the hex code of \(\.$color)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        guard let stored = AppData.shared.colors.first(where: { $0.id == color.id }) else {
            throw PalettesIntentError.colorNotFound
        }
        return .result(
            value: stored.HEX,
            dialog: "\(stored.name) is \(stored.HEX).",
            view: ColorSnippetView(name: stored.name, hex: stored.HEX)
        )
    }
}
```

- [ ] **Step 3: Self-review + commit**

```bash
git add Palettes/Intents/FindPalettesIntent.swift Palettes/Intents/GetColorHexIntent.swift
git commit -m "feat: add find-palettes and get-color-hex intents"
```

---

### Task 6: Open intent + deep link

**Files:**
- Create: `Palettes/Intents/OpenPaletteIntent.swift`
- Modify: `Palettes/Views/Palette/PaletteView.swift` (inside the `NavigationStack` at line 52)

**Interfaces:**
- Consumes: `AppData.shared.pendingOpenPaletteID` (Task 1), `PaletteEntity`, `PalettesIntentError`, `TabValue.palettes`.

- [ ] **Step 1: Create `Palettes/Intents/OpenPaletteIntent.swift`**

```swift
//
//  OpenPaletteIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct OpenPaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Palette"
    static let description = IntentDescription("Opens a palette in Palettes.")
    static let openAppWhenRun = true

    @Parameter(title: "Palette")
    var palette: PaletteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$palette)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard AppData.shared.palettes.contains(where: { $0.id == palette.id }) else {
            throw PalettesIntentError.paletteNotFound
        }
        AppData.shared.activeTab = .palettes
        AppData.shared.pendingOpenPaletteID = palette.id
        return .result()
    }
}
```

- [ ] **Step 2: Handle the pending id in `PaletteView`**

In `Palettes/Views/Palette/PaletteView.swift`, attach to the `NavigationStack(path: $path)` (after its existing modifiers, alongside `.navigationDestination`):

```swift
            .onReceive(appData.$pendingOpenPaletteID) { id in
                guard let id, let palette = appData.palettes.first(where: { $0.id == id }) else { return }
                appData.pendingOpenPaletteID = nil
                path = NavigationPath([palette])
            }
```

(`path` is the view's existing `NavigationPath` state; destinations for `PaletteViewModel` already exist at line 55.)

- [ ] **Step 3: Self-review + commit**

```bash
git add Palettes/Intents/OpenPaletteIntent.swift Palettes/Views/Palette/PaletteView.swift
git commit -m "feat: add open-palette intent with deep link into PaletteView"
```

---

### Task 7: Spotlight indexing

**Files:**
- Create: `Palettes/Intents/EntityIndexer.swift`
- Modify: `Palettes/App/AppData.swift` (`init`, `load()`)

**Interfaces:**
- Consumes: `PaletteEntity`, `ColorEntity` (Task 2), `AppData` published arrays.
- Produces: `EntityIndexer.reindex(palettes:colors:)` (static, fire-and-forget).

- [ ] **Step 1: Create `Palettes/Intents/EntityIndexer.swift`**

```swift
//
//  EntityIndexer.swift
//  Palettes
//
//  Donates the library to Spotlight so Siri / Apple Intelligence can
//  semantically resolve palettes and colors by name.
//

import CoreSpotlight
import Foundation

@available(iOS 26.0, *)
enum EntityIndexer {
    /// Replaces the app's Spotlight entities with the current library.
    /// Fire-and-forget: indexing failures are non-fatal and silent.
    static func reindex(palettes: [PaletteEntity], colors: [ColorEntity]) {
        Task.detached(priority: .background) {
            let index = CSSearchableIndex.default()
            try? await index.deleteAppEntities(ofType: PaletteEntity.self)
            try? await index.deleteAppEntities(ofType: ColorEntity.self)
            try? await index.indexAppEntities(palettes)
            try? await index.indexAppEntities(colors)
        }
    }
}
```

- [ ] **Step 2: Trigger reindexing from `AppData`**

In `Palettes/App/AppData.swift` `init`, after the two persistence sinks (`.store(in: &cancellables)` for `$palettes` around line 77), add a debounced index sink:

```swift
        // Keep Spotlight's copy of the library current so Siri can find it.
        $palettes.combineLatest($colors)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { palettes, colors in
                if #available(iOS 26.0, *) {
                    EntityIndexer.reindex(
                        palettes: palettes.map(PaletteEntity.init),
                        colors: colors.map(ColorEntity.init)
                    )
                }
            }
            .store(in: &cancellables)
```

(No `dropFirst()` — the initial load should also be indexed. `PaletteEntity.init`/`ColorEntity.init` are `@MainActor`; the sink runs on `RunLoop.main`, so this is fine.)

- [ ] **Step 3: Self-review + commit**

```bash
git add Palettes/Intents/EntityIndexer.swift Palettes/App/AppData.swift
git commit -m "feat: donate palettes and colors to Spotlight for Siri"
```

---

### Task 8: App Shortcuts phrases

**Files:**
- Create: `Palettes/Intents/PalettesShortcuts.swift`

**Interfaces:**
- Consumes: all six intents.

- [ ] **Step 1: Create `Palettes/Intents/PalettesShortcuts.swift`**

```swift
//
//  PalettesShortcuts.swift
//  Palettes
//
//  Siri phrases. Every phrase must contain \(.applicationName).
//

import AppIntents

@available(iOS 26.0, *)
struct PalettesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GeneratePaletteIntent(),
            phrases: [
                "Generate a palette in \(.applicationName)",
                "Make a palette with \(.applicationName)",
                "Create a color palette in \(.applicationName)"
            ],
            shortTitle: "Generate Palette",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: SaveColorIntent(),
            phrases: [
                "Save a color in \(.applicationName)",
                "Add a color to \(.applicationName)"
            ],
            shortTitle: "Save Color",
            systemImageName: "eyedropper"
        )
        AppShortcut(
            intent: OpenPaletteIntent(),
            phrases: [
                "Open \(\.$palette) in \(.applicationName)",
                "Show my \(\.$palette) palette in \(.applicationName)"
            ],
            shortTitle: "Open Palette",
            systemImageName: "swatchpalette"
        )
        AppShortcut(
            intent: GetColorHexIntent(),
            phrases: [
                "Get the hex of \(\.$color) in \(.applicationName)",
                "What's the hex code of \(\.$color) in \(.applicationName)"
            ],
            shortTitle: "Get Hex",
            systemImageName: "number"
        )
    }
}
```

- [ ] **Step 2: Self-review + commit**

```bash
git add Palettes/Intents/PalettesShortcuts.swift
git commit -m "feat: add Siri app shortcut phrases"
```

---

### Task 9: On-device verification checklist + docs

**Files:**
- Modify: `README.md` (feature list section)
- Modify: `docs/specs/2026-07-17-app-intents-siri-design.md` (status line only)

- [ ] **Step 1:** Add a "Siri & Shortcuts" bullet list to README's feature section naming the six intents and example phrases.
- [ ] **Step 2:** Update the spec's Status line to "Implemented on feature/app-intents; awaiting on-device verification."
- [ ] **Step 3:** Report this checklist to the user for on-device testing (cannot be automated here):
  1. Build & run on device (iOS 26+, Apple Intelligence enabled).
  2. Shortcuts app → Palettes shows all six actions; each runs.
  3. "Generate a palette in Palettes" via Siri prompts for vibe, shows swatch snippet, palette appears in library and syncs to a second device.
  4. "Open <name> in Palettes" lands on that palette's detail screen.
  5. Invalid hex in Save Color produces the friendly error.
  6. Spotlight search finds palettes/colors by name after a couple of minutes.
- [ ] **Step 4: Commit**

```bash
git add README.md docs/specs/2026-07-17-app-intents-siri-design.md
git commit -m "docs: document Siri & Shortcuts support"
```
