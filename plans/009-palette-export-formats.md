# Plan 009: Coolors-style palette export — code snippets, SVG, ASE, PDF, and share URL

> **Executor instructions**: Follow step by step; verify each step; STOP
> conditions binding. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/Managers Palettes/Views/Palette Palettes/ViewModels`
> Written against `9726b96` + uncommitted `icloud-sync` tree. The palette
> views are under active development — verify excerpts before proceeding.

## Status

- **Priority**: P2 (direction — user-selected feature)
- **Effort**: L (phased; phase 1 alone is M)
- **Risk**: MED (new user-facing surface)
- **Depends on**: plans/001-test-baseline.md; if plans/003 has landed, build on `paletteColors` instead of the parallel arrays
- **Category**: direction
- **Planned at**: commit `9726b96`, 2026-07-15

## Why this matters

The app can export a palette only as a PNG. Coolors.co — the category benchmark — exports palettes as **URL, PDF, Image, CSS code, SVG, and ASE** (Adobe Swatch Exchange, for importing into Adobe apps), with code export covering CSS variables/SCSS/Tailwind-style tokens. The app's data model is literally named hex strings, so most of these are cheap, and they turn the app from a viewer into a tool that plugs into a designer/developer workflow. This plan implements the export set in phases; each phase ships independently.

## Current state

Existing image export — `Palettes/Managers/PaletteImageRenderer.swift:1-13`:

```swift
struct PaletteImageRenderer {
    @MainActor
    static func renderImage(for palette: PaletteViewModel, colors: [ColorViewModel]) -> UIImage? {
        let content = PaletteExportView(palette: palette, colorVMs: colors)
        let renderer = ImageRenderer(content: content.frame(width: 800))
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
```

Share mechanism (repo convention — reuse it): `presentShare(items: [Any])` wraps `UIActivityViewController` (`Palettes/Views/Color/ColorsView.swift:423-429`; a near-identical copy exists in `Palettes/Views/Palette/PaletteView.swift` around `:372`, and share entry points in `Palettes/Views/Palette/PaletteDetailView.swift:193,212`).

Data model — `Palettes/ViewModels/PaletteViewModel.swift:11-17`: `name`, `colors: [Color]`, `hexCodes: [String]` (canonical `#RRGGBB` uppercase), `colorNames: [String]`, `isFavorite`. (After plan 003: one `paletteColors: [PaletteColor]` array with get-only compatibility accessors — prefer `paletteColors`.)

UI conventions: iOS 26 Liquid Glass — use `.glass` button style, NOT `.glassProminent` (always accent-tinted); adjacent toolbar items auto-merge, separate with `ToolbarSpacer`; iOS 26 APIs must go through `Palettes/Compatibility/` shims or `@available` guards (deployment target is iOS 17). Sheets follow the `.presentationDetents([.medium, .large])` pattern (see `PaletteEditSheet` usage).

No URL scheme exists yet (`grep -rn "onOpenURL\|CFBundleURLTypes" Palettes` → empty).

## Coolors reference (what to match)

| Coolors export | This plan | Phase |
|---|---|---|
| Code (CSS/SCSS/Tailwind/tokens) | Text formats incl. SwiftUI (native-app twist) | 1 |
| URL | Coolors-compatible URL + plain hex list | 1 |
| SVG | SVG document with swatch rects + labels | 1 |
| Image | already exists (`PaletteImageRenderer`) | — |
| ASE | Adobe Swatch Exchange binary | 2 |
| PDF | Rendered swatch sheet | 2 |

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Test | `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** TEST SUCCEEDED **` |

## Scope

**In scope**:
- New: `Palettes/Managers/PaletteExporter.swift` (all format generation — pure functions, testable)
- New: `Palettes/Views/Components/ExportPaletteSheet.swift` (format picker UI)
- Edit: `Palettes/Views/Palette/PaletteDetailView.swift` and `Palettes/Views/Palette/PaletteView.swift` (add "Export…" entry next to the existing share actions)
- New: `PalettesTests/PaletteExporterTests.swift`

**Out of scope**:
- Import (the reverse direction) — deliberately deferred; design exports so they round-trip cleanly later.
- A custom URL scheme / universal links for *receiving* palettes.
- `PaletteImageRenderer` changes.
- Any persistence/model change.

## Git workflow

Branch `advisor/009-palette-export-formats`; conventional commits per phase (`feat:`); no push/PR unless instructed.

## Steps — Phase 1 (text/code, URL, SVG)

### Step 1: `PaletteExporter` with pure string generators

New file `Palettes/Managers/PaletteExporter.swift`:

```swift
enum PaletteExportFormat: String, CaseIterable, Identifiable {
    case css, scss, swiftui, tailwind, json, plainHex, coolorsURL, svg
    var id: String { rawValue }
}

enum PaletteExporter {
    static func export(_ palette: PaletteViewModel, as format: PaletteExportFormat) -> String
}
```

Slugify names (lowercased, spaces→`-`, strip non-alphanumerics; deduplicate collisions with `-2` suffixes). Exact output shapes:

- **css**: `:root {\n  --midnight: #1A1A70;\n  ... }`
- **scss**: `$midnight: #1A1A70;` per line
- **swiftui**: `extension Color {\n    static let midnight = Color(red: 0.102, green: 0.102, blue: 0.439) // #1A1A70\n}` (three decimals; compute from the hex, not from `Color`)
- **tailwind**: `colors: {\n  'midnight': '#1A1A70',\n  ...\n}`
- **json**: `[{"name": "Midnight", "hex": "#1A1A70"}, ...]` (original names, stable key order name→hex)
- **plainHex**: one `#RRGGBB` per line
- **coolorsURL**: `https://coolors.co/` + lowercased hexes without `#`, `-`-joined (matches coolors' own palette URLs, e.g. `https://coolors.co/1a1a70-007aff-99fa99`)
- **svg**: `<svg xmlns="http://www.w3.org/2000/svg" width="{100*n}" height="140">` with one `<rect x="{i*100}" width="100" height="100" fill="#…"/>` per color plus `<text>` labels (name at y=118, hex at y=132, `font-family="ui-monospace, monospace"` for hex). XML-escape names (`&`, `<`, `>`, `"`).

### Step 2: Export sheet UI

`ExportPaletteSheet(palette:)`: a `List`/`Picker` of formats with a live monospaced preview (`Text(output).font(.system(.caption, design: .monospaced))` in a `ScrollView`), a Copy button (`UIPasteboard.general.string = output` + `ToastManager.shared.show("Copied", icon: "doc.on.doc")`) and a Share button routing through the existing `presentShare` pattern — for `svg`, share as a file: write to `FileManager.default.temporaryDirectory.appending(path: "\(slug).svg")` and share the `URL`. Presented with `.presentationDetents([.medium, .large])`. Match Liquid Glass conventions above.

### Step 3: Entry points

In `PaletteDetailView` (toolbar/menu near the existing share at `:193,212`) and `PaletteView`'s palette context menu: add "Export…" with icon `square.and.arrow.up.on.square`, presenting the sheet. Keep the existing plain "Share" actions untouched.

**Verify**: build succeeds; manual check deferred to the Xcode machine (note in report).

### Step 4: Tests

`PalettesTests/PaletteExporterTests.swift` — golden-string tests for every format using a fixed 3-color palette (use the "Forest Floor" sample shape: `#1B4D1B/#99FA99/#333333`). Cases: exact output per format; name slug collision (`"Sea"`, `"Sea!"` → `sea`, `sea-2`); XML escaping in svg (`name: "A&B <x>"`); empty palette → empty-but-valid document per format (define: css/scss/tailwind emit the wrapper with no entries; plainHex/coolorsURL empty string; svg valid empty svg; json `[]`).

**Verify**: `xcodebuild test ...` → `** TEST SUCCEEDED **`.

## Steps — Phase 2 (ASE, PDF) — separate commits, optional stop point

### Step 5: ASE encoder

`PaletteExporter.aseData(_ palette:) -> Data`. Adobe Swatch Exchange format (big-endian): magic `ASEF`, version `1,0` (two UInt16), block count UInt32; per color block: type `0x0001`, block length UInt32, name as UTF-16BE with UInt16 length (in characters incl. null terminator) + null terminator, color model `"RGB "` (4 ASCII bytes), three Float32 (0–1), color type UInt16 `0x0002` (normal). Write a golden test asserting the exact bytes for a 1-color palette (compute the expected hex dump by hand in the test comment). Share as `.ase` file via temporary directory + `presentShare`.

### Step 6: PDF export

`PaletteExporter.pdfData(_ palette:) -> Data` using `UIGraphicsPDFRenderer` (US Letter 612×792): palette name as title, one row per color with a swatch rect, name, and hex in monospaced font. Test: `pdfData` is non-empty and begins with `%PDF`.

**Verify**: `xcodebuild test ...` → all pass.

## Done criteria

- [ ] All 8 phase-1 formats produce golden-tested output; ASE/PDF tests pass if phase 2 attempted
- [ ] Export reachable from both `PaletteDetailView` and `PaletteView` context menu
- [ ] Existing share behavior unchanged
- [ ] `xcodebuild test ...` → `** TEST SUCCEEDED **`
- [ ] `plans/README.md` row updated (note explicitly if phase 2 was deferred)

## STOP conditions

- `PaletteViewModel` shape differs from both the pre- and post-plan-003 shapes described above.
- The `presentShare` helper has been consolidated/moved (plan discussions considered extracting it) — use the new location, but STOP if none is findable.
- ASE golden bytes fail twice — report the produced vs. expected hex dump rather than fiddling.

## Maintenance notes

- Import (plan candidate: parse coolors URLs + plain hex lists from the pasteboard, and read back `.ase`) is the natural follow-up; the golden tests here define the round-trip contract.
- If plan 003's `PaletteColor` lands later, migrate `PaletteExporter` to `paletteColors` — the tests won't change.
- Reviewer: check slug collisions and XML escaping made it in; those are the classic misses.
