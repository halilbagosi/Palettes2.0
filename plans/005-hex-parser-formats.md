# Plan 005: Accept 3/4/8-digit hex input and stop silently storing gray on parse failure

> **Executor instructions**: Follow step by step; verify each step; STOP
> conditions binding. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/Utilities/HEXParser.swift Palettes/App/AppData.swift`
> Written against `9726b96` + uncommitted `icloud-sync` tree.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-test-baseline.md
- **Category**: bug
- **Planned at**: commit `9726b96`, 2026-07-15

## Why this matters

`Color(hex:)` accepts only exactly-6-hex-digit strings. Common user input — `#FFF` shorthand, `#RRGGBBAA` with alpha (what many tools copy) — returns `nil`, and load-time callers coalesce `nil` to `.gray`, so a pasted color silently renders and persists as gray. Supporting the standard shorthand forms removes a whole class of "why is my color gray" confusion.

## Current state

`Palettes/Utilities/HEXParser.swift:11-25`:

```swift
extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6,
              let number = UInt64(cleaned, radix: 16) else {
            return nil
        }
        let r = Double((number >> 16) & 0xFF) / 255.0
        ...
        self.init(red: r, green: g, blue: b)
    }
}
```

Silent-gray call sites: `Palettes/App/AppData.swift:137` (`Color(hex: $0.hex) ?? .gray`) and `:147`. These stay — at *load* time gray is a sane fallback for corrupt stored data. The parser fix addresses the *input* path; input UIs already validate via the failable init (e.g. `ColorInputView` — confirm with `grep -rn "Color(hex" Palettes/Views --include="*.swift"`).

Same 6-only parsing is duplicated in `ColorNamer.name(forHex:)` (`HEXParser.swift:430-436`) and `perceptualDistance`'s local `parse` (`:461-466`) — those operate on app-normalized hexes and may stay 6-only; do not change them in this plan.

App-wide canonical form is 6-digit uppercase with `#` (see normalization in `Palettes/Managers/PaletteGenerator.swift:100-102`). Alpha is not representable in the data model — 8-digit input should parse the RGB and **discard alpha**.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Test | `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** TEST SUCCEEDED **` |

## Scope

**In scope**: `Palettes/Utilities/HEXParser.swift` (the `Color.init?(hex:)` only), `PalettesTests/HEXParserTests.swift`.

**Out of scope**: `ColorNamer` internals; the `?? .gray` load fallbacks in `AppData.swift`; any UI file; storing alpha.

## Git workflow

Branch `advisor/005-hex-parser-formats`; conventional commit (`feat:` or `fix:`); no push/PR unless instructed.

## Steps

### Step 1: Extend the parser

Rewrite the guard to switch on `cleaned.count`:

- 3 (`RGB`): expand each digit (`F` → `FF`) then parse as 6.
- 4 (`RGBA`): expand to 8, then as 8.
- 6 (`RRGGBB`): current behavior.
- 8 (`RRGGBBAA`): parse first 6 as RGB, ignore alpha.
- anything else, or non-hex characters: `return nil` (unchanged).

Keep output identical for existing 6-digit input (r/g/b computed the same way).

### Step 2: Update and extend tests

In `PalettesTests/HEXParserTests.swift` (from plan 001): flip the previously-rejected cases — `"#FFF"` now equals `Color(hex: "#FFFFFF")`, `"#F0AC"` equals `Color(hex: "#FF00AA")`, `"#FF5D00AA"` equals `Color(hex: "#FF5D00")`. Still nil: `"#FFFFF"` (5), `"#FFFFFFF"` (7), `"GGG"`, `""`. Plan 001 flagged these tests as due to change here — update the note.

**Verify**: `xcodebuild test ...` → `** TEST SUCCEEDED **`.

## Done criteria

- [ ] All hex-format tests above pass
- [ ] Only the two in-scope files modified (`git status`)
- [ ] `plans/README.md` row updated

## STOP conditions

- Plan-001 tests don't exist yet (dependency not landed).
- `Color(hex:)` has changed shape in the working tree.

## Maintenance notes

- If alpha support is ever wanted, the data model (`hex` strings everywhere, `StoredColor.hex`) must grow first — that's a design decision, not a parser patch.
- Plan 009 (exports) emits canonical 6-digit hex; unaffected by wider input parsing.
