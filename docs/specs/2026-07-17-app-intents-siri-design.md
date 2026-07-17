# App Intents + Siri (Apple Intelligence) Integration — Design

**Date:** 2026-07-17
**Branch:** `feature/app-intents` (off `dev`)
**Status:** Approved by user; implementation plan to follow.

## Goal

Expose Palettes' core capabilities to Siri, Apple Intelligence, Spotlight, and the
Shortcuts app via the App Intents framework, so users can generate, create, find,
and open palettes and colors by voice or in Shortcuts chains — without opening the
app unless navigation is the point.

The "new Siri" (Apple Intelligence) consumes App Intents, App Entities, App
Shortcuts phrases, and Spotlight-indexed entities. There is no first-party
Assistant Schema domain for color palettes, so this integration is the correct and
complete way for Palettes to participate.

## Structure

New folder `Palettes/Intents/` (picked up automatically by the project's
synchronized groups — no pbxproj edit needed):

- `PaletteEntity.swift` — `AppEntity` + `IndexedEntity`
- `ColorEntity.swift` — `AppEntity` + `IndexedEntity`
- `EntityQueries.swift` — `PaletteEntityQuery`, `ColorEntityQuery`
- `GeneratePaletteIntent.swift`
- `CreatePaletteIntent.swift`
- `SaveColorIntent.swift`
- `OpenPaletteIntent.swift`
- `FindPalettesIntent.swift`
- `GetColorHexIntent.swift`
- `PalettesShortcuts.swift` — `AppShortcutsProvider`
- `IntentSnippets.swift` — SwiftUI snippet views (swatch row for a palette, single
  swatch for a color)
- `IntentNavigation.swift` — deep-link plumbing for Open intents

## Entities

**`PaletteEntity`**: id (persistent model id / UUID), name, color hexes.
`displayRepresentation` shows the name with a subtitle like "5 colors" and an
image (rendered swatch strip where practical, else a paintpalette symbol).
**`ColorEntity`**: id, name, hex; display representation shows name + hex with a
color swatch image.

Both conform to `IndexedEntity` so they are donated to Spotlight
(`CSSearchableIndex`), which is what lets Apple Intelligence semantically resolve
"my ocean palette". Donation happens on library load and after any
create/rename/delete, via a small `EntityIndexer` helper called from the store
layer.

Queries (`EntityQuery` + `EntityStringQuery`) support lookup by id,
`suggestedEntities` (most recent items), and string matching on name (and hex for
colors). They read from the **same** SwiftData `ModelContainer` the app uses —
exposed through a shared access point in `PersistentStore` — never a second
container, so intent-created data is immediately visible to the app and flows
through the existing CloudKit-safe save paths.

## Intents

| Intent | Parameters | Behavior |
|---|---|---|
| `GeneratePaletteIntent` | `vibe: String`, `size: Int?` (default 5, clamped 2–10) | Headless. Guards `SystemLanguageModel.default.availability`; throws a friendly error if Apple Intelligence is unavailable. Calls `PaletteGenerator.generate`, persists, returns dialog + snippet view of the swatches. |
| `CreatePaletteIntent` | `name: String` | Headless. Creates an empty palette, returns its `PaletteEntity`. |
| `SaveColorIntent` | `hex: String`, `name: String?` | Headless. Validates via `HEXParser`; auto-names when name is nil (existing auto-name path); returns the `ColorEntity` + swatch snippet. |
| `OpenPaletteIntent` | `palette: PaletteEntity` | `openAppWhenRun = true`; deep-links to the palette's detail view. |
| `FindPalettesIntent` | optional search term | Returns `[PaletteEntity]` for Shortcuts chains. |
| `GetColorHexIntent` | `color: ColorEntity` | Returns the hex `String` as the intent result; dialog reads it aloud. |

All intents run on iOS 26+ (matching the app's deployment target usage of
FoundationModels); `GeneratePaletteIntent` additionally requires Apple
Intelligence availability at runtime.

## Siri phrases (`PalettesShortcuts`)

`AppShortcutsProvider` with phrase sets, short titles, and system images, e.g.:

- "Generate a palette in \(.applicationName)" / "Make a \(\.$vibe) palette in …"
- "Save a color in \(.applicationName)"
- "Open \(\.$palette) in \(.applicationName)"

## Deep linking

`IntentNavigation` is a lightweight observable singleton the app's root view
listens to (`onChange`/task). `OpenPaletteIntent` sets a pending destination
(palette id); `PaletteTabView` switches to the library tab and pushes
`PaletteDetailView`. No URL scheme needed.

## Error handling

Every failure throws a localized, user-readable error: AI unavailable, invalid
hex, entity not found, save failure. No silent failures. Persistence reuses the
app's hardened save paths (plan 002), so CloudKit sync behavior is unchanged.

## Testing / verification

This machine cannot build the app (no Xcode). Verification plan:

1. Code review against iOS 26/27 App Intents APIs.
2. Manual checklist for the user on device:
   - All six intents appear in the Shortcuts app and run correctly.
   - Siri phrases resolve ("Generate a palette in Palettes", with vibe prompt).
   - Generated/saved items appear in the library immediately and sync via
     CloudKit.
   - Open intent lands on the correct palette detail screen.
   - Palettes/colors appear in Spotlight search results.

## Out of scope (deferred — approach 3)

Control Center controls and interactive widget buttons reusing these intents.
