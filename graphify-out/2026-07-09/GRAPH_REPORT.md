# Graph Report - Palettes  (2026-07-09)

## Corpus Check
- 53 files · ~28,659 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 507 nodes · 802 edges · 69 communities (34 shown, 35 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `dec773e4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Color Data Model
- Toast & UI Components
- AI Palette Generation Plan
- Palette Export & Rendering
- App Entry & Shaders
- Toast Manager & Input Modes
- Share Sheet & Camera Picker
- New Palette Creation Flow
- Color Edit View
- Image Color Extraction
- Generate View (AI Palette UI)
- Interactive Color Picker
- App Error Types
- AdjustmentSlider
- Palette Generator (Foundation Models)
- Editable Values View
- Big Color Cell
- Palette Tab Navigation
- AI Palette Generation Docs
- New Color Redesign Spec
- ColorInputView
- GenerationOrbView
- AI Palette Generation (Generate Tab) — Design
- Components
- GenerationResultView
- Global Constraints
- Glow & Sparkle Polish — Design
- ColorAdjustment
- Global Constraints
- Changes
- PaletteShaders.metal
- ToastOverlay
- PaletteCell
- PaletteCellSearch
- ColorCellSearch
- PaletteEmptyView
- SparkleFieldView
- On-device Model Availability Gate
- Color(hex:) HEXParser
- ColorNamer
- Apple Foundation Models Framework
- GenerateView
- GeneratedColor (@Generable)
- GeneratedPalette (@Generable)
- GeneratedPaletteSheet
- ImageColorExtractor
- LanguageModelSession Guided Generation
- PaletteGenerator
- PaletteTabView
- PaletteViewModel
- ToastManager
- GenerationExperienceView
- GenerationOrbView
- iOS 27 Liquid Glass API (glassEffect)
- LiquidGradientView
- Metal Stitchable colorEffect Shader
- PaletteShaders.metal (liquidGradient shader)
- Liquid Glass Generation Experience Plan
- On-device Palette Generation
- App-wide Liquid Glass Polish
- Sensory Feedback / Haptics
- SparkleFieldView
- Glow & Sparkle Polish Design Spec
- Siri / Apple Intelligence Aesthetic
- Liquid Glass Generation Experience Design Spec
- AdjustmentSlider
- Unified Create Pipeline / Deduplication
- InteractiveColorPicker
- NewColorView (Pick/Scan modes)

## God Nodes (most connected - your core abstractions)
1. `View` - 46 edges
2. `SwiftUI` - 40 edges
3. `AppData` - 28 edges
4. `ColorViewModel` - 27 edges
5. `PaletteViewModel` - 26 edges
6. `GenerateView` - 23 edges
7. `ColorInputView` - 21 edges
8. `NewPaletteView` - 17 edges
9. `ColorEditView` - 16 edges
10. `GenerationOrbView` - 16 edges

## Surprising Connections (you probably didn't know these)
- `PaletteTabView` --calls--> `AppData`  [INFERRED]
  Palettes/Views/Main/PaletteTabView.swift → Palettes/App/AppData.swift
- `AppData` --references--> `TabValue`  [EXTRACTED]
  Palettes/App/AppData.swift → Palettes/Views/Main/PaletteTabView.swift
- `ColorEditView` --references--> `AppData`  [EXTRACTED]
  Palettes/Views/Color/ColorEditView.swift → Palettes/App/AppData.swift
- `GenerateView` --references--> `AppData`  [EXTRACTED]
  Palettes/Views/Color/GenerateView.swift → Palettes/App/AppData.swift
- `NewColorView` --references--> `AppData`  [EXTRACTED]
  Palettes/Views/Color/NewColorView.swift → Palettes/App/AppData.swift

## Import Cycles
- None detected.

## Communities (69 total, 35 thin omitted)

### Community 0 - "Color Data Model"
Cohesion: 0.06
Nodes (46): ColorBindingWrapper, DispatchWorkItem, Hashable, Identifiable, IndexSet, ObservableObject, AppData, PaletteExportView (+38 more)

### Community 1 - "Toast & UI Components"
Cohesion: 0.25
Nodes (13): AttributedString, View, highlightedText(), HueChip, RecentSearchesRow, SearchEmptyLibraryView, SearchEmptyStateView, SearchSectionHeader (+5 more)

### Community 3 - "Palette Export & Rendering"
Cohesion: 0.50
Nodes (3): LiquidGradientView, Color, Double

### Community 4 - "App Entry & Shaders"
Cohesion: 0.17
Nodes (7): App, Combine, MyApp, PaletteTabView, PaletteView, Scene, SwiftUI

### Community 5 - "Toast Manager & Input Modes"
Cohesion: 0.07
Nodes (29): CaseIterable, Color, HueCategory, blues, greens, neutrals, oranges, pinks (+21 more)

### Community 6 - "Share Sheet & Camera Picker"
Cohesion: 0.10
Nodes (16): NSObject, CameraPicker, Coordinator, Any, Bool, Context, UIImage, ShareSheetView (+8 more)

### Community 7 - "New Palette Creation Flow"
Cohesion: 0.43
Nodes (6): device, float2, half4, lensWarp(), liquidGradient(), orbFlow()

### Community 8 - "Color Edit View"
Cohesion: 0.23
Nodes (7): ColorEditView, Binding, Bool, Color, Double, String, Void

### Community 9 - "Image Color Extraction"
Cohesion: 0.36
Nodes (6): ExtractedColor, ImageColorExtractor, Double, Int, String, UIImage

### Community 10 - "Generate View (AI Palette UI)"
Cohesion: 0.40
Nodes (3): Content, ToastOverlay, ViewModifier

### Community 11 - "Interactive Color Picker"
Cohesion: 0.21
Nodes (9): ColorInputMode, combined, hex, rgb, InteractiveColorPicker, Binding, Bool, Color (+1 more)

### Community 12 - "App Error Types"
Cohesion: 0.13
Nodes (17): LocalizedError, AppError, aiUnavailable, colorExtractionFailed, emptyPaletteName, generationFailed, imageProcessingFailed, invalidData (+9 more)

### Community 13 - "AdjustmentSlider"
Cohesion: 0.50
Nodes (3): AdjustmentSlider, Double, String

### Community 14 - "Palette Generator (Foundation Models)"
Cohesion: 0.08
Nodes (32): AnyShapeStyle, FoundationModels, Never, BaseColor, GeneratedColor, GeneratedPalette, LockedColor, PaletteGenerator (+24 more)

### Community 15 - "Editable Values View"
Cohesion: 0.36
Nodes (5): EditableValuesView, Binding, Color, String, Void

### Community 16 - "Big Color Cell"
Cohesion: 0.25
Nodes (7): Color, ColorCellBig, Bool, Color, LocalizedStringKey, String, Void

### Community 17 - "Palette Tab Navigation"
Cohesion: 0.33
Nodes (6): TabValue, account, colors, generate, palettes, search

### Community 20 - "ColorInputView"
Cohesion: 0.13
Nodes (18): ColorInputEntry, ColorInputSource, library, pick, scan, ColorInputView, ScanExtraction, dominant (+10 more)

### Community 21 - "GenerationOrbView"
Cohesion: 0.19
Nodes (13): CGSize, Date, GenerationOrbView, Bool, CGFloat, CGRect, Color, Double (+5 more)

### Community 22 - "AI Palette Generation (Generate Tab) — Design"
Cohesion: 0.17
Nodes (11): 1. PaletteTabView (modify), 2. Managers/PaletteGenerator.swift (new), 3. AppError (modify), 4. GenerateView (modify), 5. Views/Components/GeneratedPaletteSheet.swift (new), AI Palette Generation (Generate Tab) — Design, Components, Context (+3 more)

### Community 23 - "Components"
Cohesion: 0.18
Nodes (10): 1. `Palettes/Utilities/PaletteShaders.metal` (new), 2. `Palettes/Views/Components/Generation/LiquidGradientView.swift` (new), 3. `Palettes/Views/Components/Generation/GenerationOrbView.swift` (new), 4. `Palettes/Views/Components/Generation/GenerationExperienceView.swift` (new), 5. `GenerateView` restyle (modify), Components, Error handling, Goal (+2 more)

### Community 24 - "GenerationResultView"
Cohesion: 0.27
Nodes (7): EditTarget, GenerationResultView, Bool, Color, Int, String, Void

### Community 25 - "Global Constraints"
Cohesion: 0.22
Nodes (8): AI Palette Generation Implementation Plan, Global Constraints, Task 1: AppError cases, Task 2: PaletteGenerator backend, Task 3: GeneratedPaletteSheet, Task 4: Wire up GenerateView, Task 5: Enable the Generate tab, Task 6: End-to-end verification

### Community 26 - "Glow & Sparkle Polish — Design"
Cohesion: 0.22
Nodes (8): 1. `Palettes/Views/Components/Generation/SparkleFieldView.swift` (new), 2. GenerateView additions (modify), Error handling, Glow & Sparkle Polish — Design, Goal, Part A — Generate screen, Part B — App-wide polish (files not owned by the parallel session), Verification

### Community 27 - "ColorAdjustment"
Cohesion: 0.33
Nodes (4): ColorAdjustment, Color, Double, String

### Community 28 - "Global Constraints"
Cohesion: 0.25
Nodes (7): Global Constraints, Liquid Glass Generation Experience Implementation Plan, Task 1: Metal shader + LiquidGradientView, Task 2: GenerationOrbView, Task 3: GenerationExperienceView, Task 4: Rewire + restyle GenerateView, delete GeneratedPaletteSheet, Task 5: Visual verification

### Community 29 - "Changes"
Cohesion: 0.25
Nodes (7): 1. `Views/Components/InteractiveColorPicker.swift` (modify), 2. `Views/Components/AdjustmentSlider.swift` (new), 3. `Views/Color/NewColorView.swift` (rewrite), Changes, Goal, New Color Page Redesign — Design, Verification

### Community 30 - "PaletteShaders.metal"
Cohesion: 0.25
Nodes (4): Foundation, Color, LocalizedStringKey, viewButtonCell

### Community 31 - "ToastOverlay"
Cohesion: 0.33
Nodes (5): AddColorToPaletteSheet, Int, Set, String, UUID

### Community 32 - "PaletteCell"
Cohesion: 0.40
Nodes (4): PaletteCell, Color, String, Void

### Community 33 - "PaletteCellSearch"
Cohesion: 0.50
Nodes (3): PaletteCellSearch, Color, String

### Community 34 - "ColorCellSearch"
Cohesion: 0.50
Nodes (3): ColorCellSearch, Color, String

### Community 36 - "PaletteEmptyView"
Cohesion: 0.50
Nodes (3): PaletteEmptyView, String, Void

### Community 37 - "SparkleFieldView"
Cohesion: 0.50
Nodes (3): SparkleFieldView, Color, Int

## Knowledge Gaps
- **108 isolated node(s):** `reds`, `oranges`, `yellows`, `greens`, `blues` (+103 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **35 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `Toast & UI Components` to `Color Data Model`, `Palette Export & Rendering`, `App Entry & Shaders`, `Toast Manager & Input Modes`, `Color Edit View`, `Generate View (AI Palette UI)`, `Interactive Color Picker`, `AdjustmentSlider`, `Palette Generator (Foundation Models)`, `Editable Values View`, `Big Color Cell`, `ColorInputView`, `GenerationOrbView`, `GenerationResultView`, `PaletteShaders.metal`, `ToastOverlay`, `PaletteCell`, `PaletteCellSearch`, `ColorCellSearch`, `PaletteEmptyView`, `SparkleFieldView`?**
  _High betweenness centrality (0.243) - this node is a cross-community bridge._
- **Why does `SwiftUI` connect `App Entry & Shaders` to `Color Data Model`, `Toast & UI Components`, `Palette Export & Rendering`, `Toast Manager & Input Modes`, `Share Sheet & Camera Picker`, `New Palette Creation Flow`, `Color Edit View`, `Interactive Color Picker`, `App Error Types`, `AdjustmentSlider`, `Palette Generator (Foundation Models)`, `Editable Values View`, `Big Color Cell`, `ColorInputView`, `GenerationOrbView`, `GenerationResultView`, `ColorAdjustment`, `PaletteShaders.metal`, `ToastOverlay`, `PaletteCell`, `PaletteCellSearch`, `ColorCellSearch`, `PaletteEmptyView`, `SparkleFieldView`?**
  _High betweenness centrality (0.216) - this node is a cross-community bridge._
- **Why does `AppData` connect `Color Data Model` to `App Entry & Shaders`, `Toast Manager & Input Modes`, `Color Edit View`, `Palette Generator (Foundation Models)`, `Palette Tab Navigation`, `ColorInputView`, `GenerationResultView`, `ToastOverlay`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `AppData` (e.g. with `.saveResult()` and `.createColor()`) actually correct?**
  _`AppData` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `ColorViewModel` (e.g. with `.createColor()` and `.add()`) actually correct?**
  _`ColorViewModel` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `reds`, `oranges`, `yellows` to the rest of the system?**
  _113 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Color Data Model` be split into smaller, more focused modules?**
  _Cohesion score 0.0553116769095698 - nodes in this community are weakly interconnected._