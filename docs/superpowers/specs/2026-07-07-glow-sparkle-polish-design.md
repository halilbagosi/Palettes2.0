# Glow & Sparkle Polish — Design

**Date:** 2026-07-07
**Status:** Approved (Generate glow-up approved verbatim; app-wide items chosen at
user's discretion grant: "update UI elements across the app where seen fit")

## Goal

Make the Generate screen more pleasant, interactive, glowy and sparkly with more
Liquid Glass; apply a tasteful glass/polish pass to shared UI elements across the
app.

**Constraint:** a parallel session is editing `AddColorToPaletteSheet.swift`,
`NewPaletteView.swift`, `NewColorView.swift`, `ColorsView.swift`,
`PaletteView.swift` — this work must not touch those five files.

## Part A — Generate screen

### 1. `Palettes/Views/Components/Generation/SparkleFieldView.swift` (new)

Canvas + `TimelineView(.animation)` drawing `count` (default 28) `sparkle` SF
Symbol glyphs. Per-index seeded pseudo-randomness gives each sparkle a fixed x,
base y, size, hue (from the app's rainbow set), twinkle frequency, and upward
drift speed; y wraps around the frame. No stored particle state.
`allowsHitTesting(false)`.

### 2. GenerateView additions (modify)

- Background stack becomes: `LiquidGradientView(speed: 0.4, intensity: 0.18)`
  heavily blurred → existing (softened) blobs → `SparkleFieldView()` across the
  whole screen.
- Vibe capsule: animated glow halo — a blurred capsule filled with the existing
  `glowGradient` behind the field, breathing via a repeat-forever animation and
  brightening while the text field is focused (`@FocusState`).
- Send arrow: pulsing blurred glow circle behind it.
- Palette-size live preview: below the slider, a `GlassEffectContainer` row of
  `Int(paletteSize)` glass circles tinted from the rainbow set; dots spring
  in/out as the slider moves.
- Color rows: `.glassEffect(.regular.interactive(), ...)`, springy
  `scaleEffect(1.02)` when selected, and a colored glow shadow around the
  swatch in the row's own hue when selected.
- Haptics: `.sensoryFeedback(.selection, trigger: selectedColorIDs)`,
  `.sensoryFeedback(.selection, trigger: Int(paletteSize))`,
  `.sensoryFeedback(.impact, trigger: showGenerationExperience)`.

## Part B — App-wide polish (files not owned by the parallel session)

- `Views/Components/Buttons/viewButtonCell.swift`: delete the dead
  `#available(iOS 26)` else-branch (deployment target is 27); keep the glass
  variant only.
- `Managers/ToastManager.swift` (ToastOverlay): the toast pill becomes Liquid
  Glass — `.glassEffect(.regular, in: .capsule)` replacing the
  `.ultraThinMaterial` capsule and forced dark color scheme; text/icon use
  `.primary`.
- `Views/Components/Cells/PaletteCellSearch.swift`: bottom info bar
  `.ultraThinMaterial` → `.glassEffect(.regular, in: .rect(cornerRadius: 0))`.
- `Views/Components/Cells/ColorCellSearch.swift`: same material → glass swap on
  its info section.
- `Views/Components/EmptyStates/PaletteEmpty.swift`: delete dead
  `#available(iOS 17)` branch; add a soft blurred indigo/purple glow circle
  behind the icon; message text sits in a glass rounded-rect card.

## Error handling

None affected — purely presentational.

## Verification

Build succeeds; simulator screenshots of the Generate tab (sparkles, glow,
size dots) and Search tab cells; toast checked via save flow if reachable,
otherwise visual code review of the pill styling.
