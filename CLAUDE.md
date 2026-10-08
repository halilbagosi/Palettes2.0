# CLAUDE.md

Agent-facing conventions for the Palettes iOS app.

## Build & test

1. Pick a simulator: `xcrun simctl list devices available`
2. Build: `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"`
3. Test: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"`
   (test action only works once the `PalettesTests` target and shared scheme land — see plans/001)

Target and scheme are both named `Palettes`. New Swift files are auto-included via Xcode's synchronized file groups — do not hand-edit the `.pbxproj` to add files.

## Architecture

- MVVM. `Palettes/App/AppData.swift` is the single source of truth: it publishes value-type view models and owns all persistence.
- Persistence is a debounced write-back to SwiftData/CloudKit. Do not bypass `AppData` to read/write palettes or colors directly.
- Deployment target is iOS 17.0. iOS 26-only APIs (Apple Intelligence generation, some Liquid Glass UI) are gated behind `@available(iOS 26.0, *)` and live behind shims in `Palettes/Compatibility/`. Extend those shims rather than raising the minimum deployment target.

## Known caveat

`PaletteViewModel` keeps parallel `colors` / `hexCodes` / `colorNames` arrays that must stay length-aligned by index. A `PaletteColor` struct refactor to unify these is planned but not yet done — when touching this code, preserve the alignment invariant.

## Git workflow

Branch flow: feature branch → `dev` → `staging` → `main`. Never commit feature work straight to `main`.

## Graphify

This repo has a knowledge graph at `graphify-out/`. Before broad source exploration, run `graphify query "<question>"` (or `graphify path "<A>" "<B>"` / `graphify explain "<concept>"`) — it returns a scoped subgraph that's usually cheaper than raw grep or reading `GRAPH_REPORT.md`. After modifying code, run `graphify update .` to keep the graph current.
