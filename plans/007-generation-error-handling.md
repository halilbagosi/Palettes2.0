# Plan 007: Distinguish cancellation from failure in palette generation and preserve the underlying error

> **Executor instructions**: Follow step by step; verify each step; STOP
> conditions binding. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/Managers/PaletteGenerator.swift Palettes/Utilities/AppError.swift Palettes/Views/Color/GenerateView.swift`
> Written against `9726b96` + uncommitted `icloud-sync` tree.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (test additions require plan 001)
- **Category**: bug / observability
- **Planned at**: commit `9726b96`, 2026-07-15

## Why this matters

Every error from the on-device model stream — availability, guided-generation parse failures, and (if a cancel path is ever added) `CancellationError` — is collapsed into one opaque `AppError.generationFailed`. The user always sees the same toast, and the real error is lost for debugging. Rethrowing cancellation and logging the underlying error costs a few lines and future-proofs the (currently absent) cancel button.

## Current state

`Palettes/Managers/PaletteGenerator.swift:90-111`:

```swift
let generated: GeneratedPalette
do {
    let stream = session.streamResponse(to: prompt, generating: GeneratedPalette.self)
    for try await snapshot in stream { ... }
    generated = try await stream.collect().content
} catch {
    throw AppError.generationFailed          // ← swallows everything, incl. CancellationError
}
```

Error surface — `Palettes/Views/Color/GenerateView.swift:523-539` (`generationTask = Task { ... catch { ToastManager.shared.show(error.localizedDescription, ...) ; phase = .form } }`). Note `generationTask` is never cancelled anywhere today.

`Palettes/Utilities/AppError.swift:10-27` — `enum AppError: LocalizedError` with four cases; `generationFailed` → "Couldn't generate a palette. Please try again."

Conventions: errors reach the user via `ToastManager.shared.show(message, icon:)`; no logging framework exists (use `os.Logger`).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Build | `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** BUILD SUCCEEDED **` |
| Test | same with `test` | `** TEST SUCCEEDED **` |

## Scope

**In scope**: `Palettes/Managers/PaletteGenerator.swift` (the catch block), `Palettes/Utilities/AppError.swift` (optional associated detail), `Palettes/Views/Color/GenerateView.swift` (catch site handles cancellation quietly).

**Out of scope**: adding a user-facing cancel button (separate feature); the streaming/parsing logic; prompt construction; ToastManager.

## Git workflow

Branch `advisor/007-generation-error-handling`; conventional commit (`fix:`); no push/PR unless instructed.

## Steps

### Step 1: Rethrow cancellation, log the cause

Replace the catch in `PaletteGenerator.generate`:

```swift
} catch is CancellationError {
    throw CancellationError()
} catch {
    Logger(subsystem: "com.halilbagosi.Palettes", category: "generation")
        .error("Palette generation failed: \(error, privacy: .public)")
    throw AppError.generationFailed
}
```

Add `import os` at the top. (Note: this file is `#if targetEnvironment(simulator)`-split; the catch is in the device branch only — the simulator mock path has no equivalent catch, leave it.)

### Step 2: Handle cancellation quietly at the call site

In `GenerateView.startGeneration()`'s catch (`:536-538`), before showing the toast:

```swift
} catch is CancellationError {
    withAnimation(.smooth(duration: 0.5)) { phase = .form }   // no toast
} catch {
    ToastManager.shared.show(...)  // unchanged
```

**Verify**: `xcodebuild build` → succeeded. (Device-only code path can't be executed in simulator tests; compilation is the gate. If plan 001 landed, run the full test suite too.)

## Done criteria

- [ ] `grep -n "catch is CancellationError" Palettes/Managers/PaletteGenerator.swift Palettes/Views/Color/GenerateView.swift` → one match in each
- [ ] Build (and tests, if present) succeed
- [ ] `plans/README.md` row updated

## STOP conditions

- The catch block shape at `PaletteGenerator.swift:109` has changed.
- `Logger` interpolation privacy syntax fails to compile under the project's Swift mode — fall back to `logger.error("Palette generation failed: \(String(describing: error))")`; if that fails too, STOP.

## Maintenance notes

- When a cancel button is added to the generation overlay, it should call `generationTask?.cancel()` — this plan makes that safe (no spurious error toast).
- Reviewer: confirm no user-visible behavior change for genuine failures (same toast).
