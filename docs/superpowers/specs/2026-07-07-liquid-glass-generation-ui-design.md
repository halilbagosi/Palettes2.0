# Liquid Glass Generation Experience — Design

**Date:** 2026-07-07
**Status:** Approved

## Goal

Restyle the palette-generation flow (Generate tab, waiting screen, result screen) to
match the iOS 27 Siri / Apple Intelligence aesthetic: Liquid Glass materials, a
shader-driven animated waiting screen with a glass orb and iridescent glow, and a
single full-screen generation experience.

Scope: Generate flow only. Other tabs unchanged.

## Components

### 1. `Palettes/Utilities/PaletteShaders.metal` (new)

- One `[[stitchable]]` color-effect shader `liquidGradient(position, color, size,
  time, intensity)`: domain-warped layered sine field mapped through a cosine
  pastel palette; premultiplied-alpha output whose strength scales with
  `intensity`.
- Compiled into the app's default shader library (synchronized folder picks up
  `.metal` sources automatically; verified by build).

### 2. `Palettes/Views/Components/Generation/LiquidGradientView.swift` (new)

- SwiftUI wrapper: `TimelineView(.animation)` + `GeometryReader` feeding
  `ShaderLibrary.liquidGradient` via `.colorEffect` on a filled rectangle.
- Parameters: `speed` (default 1), `intensity` (default 1). Reusable anywhere.

### 3. `Palettes/Views/Components/Generation/GenerationOrbView.swift` (new)

Full-screen waiting stage matching the Image Playground / Siri look:
- Backdrop: system background with `LiquidGradientView` heavily blurred and at low
  intensity bleeding through (dark-mode aware by construction — shader output is
  translucent over the system background).
- Center: large circle with `glassEffect(.regular, in: .circle)`, a rotating
  chromatic rim (angular rainbow gradient stroke, blurred, masked to two arc
  segments so it reads as prism edges, driven by `TimelineView` time), soft inner
  radial highlight, and a slow breathing scale (~1.0–1.04).
- Inside the orb: the status text (the vibe, or "Generating palette…"), and below
  it a small shimmer progress capsule (animated gradient sweep, indeterminate).

### 4. `Palettes/Views/Components/Generation/GenerationExperienceView.swift` (new)

Single `fullScreenCover` hosting the whole generation session:
- Inputs: `statusText: String`, `generate: () async throws -> PaletteViewModel`.
- Stage 1 (palette == nil): `GenerationOrbView`. `.task` runs `generate()`.
- Stage 2 (palette set): result screen — ✕ glass circle button top-left,
  palette name, glass swatch strip card, color rows (name + hex), bottom
  `GlassEffectContainer` with **Regenerate** (`.buttonStyle(.glass)`) and **Save**
  (`.buttonStyle(.glassProminent)`).
- Regenerate: animates palette back to nil (orb returns) and reruns `generate()`.
- Save: appends to `appData.palettes`, shows "Palette saved" toast, dismisses.
- Failure: toast with error description, cover dismisses.
- Stage transition: `.blurReplace` / smooth fade morph.
- `GeneratedPaletteSheet.swift` is deleted; its behavior lives here.

### 5. `GenerateView` restyle (modify)

- Presentation: `.sheet(item:)` replaced by `.fullScreenCover(isPresented:)`
  presenting `GenerationExperienceView` with `performGeneration` as the closure;
  local `isGenerating` spinner state removed (the cover is the loading state).
- Vibe capsule: `.glassEffect(.regular.interactive(), in: .capsule)` instead of
  `.thinMaterial`; image button loses its `#available(iOS 26)` branch (target is
  27); both wrapped in `GlassEffectContainer` so nearby glass shapes blend.
- Palette-size section and color rows presented as glass cards
  (`.glassEffect(.regular, in: .rect(cornerRadius:))`).
- Image chip gets glass treatment. Blob background kept but softened
  (lower opacity) so glass carries the look.

## Error handling

Unchanged semantics: generation errors → toast + return to Generate controls;
model unavailable → existing ContentUnavailableView gate.

## Verification

- Build must succeed with the `.metal` file compiling.
- Simulator run with temporary AUTOGEN hook: screenshot the orb mid-generation
  and the result stage; verify glass materials, shader animation present, and
  save flow appends the palette.
