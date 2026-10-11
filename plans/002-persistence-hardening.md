# Plan 002: Stop silent data loss in the CloudKit persistence pipeline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/App/AppData.swift`
> Written against commit `9726b96` plus the uncommitted `icloud-sync` working
> tree. Compare every "Current state" excerpt against the live file before
> proceeding; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-test-baseline.md
- **Category**: bug
- **Planned at**: commit `9726b96`, 2026-07-15 (dirty `icloud-sync` working tree)

## Why this matters

Three defects in `AppData`'s save path can silently lose user data:

1. **Dropped edits during reload** — edits whose debounced persist fires while a CloudKit-import reload is in flight are discarded with no retry; they exist only in memory and die if the app is killed.
2. **Orphan deletion of freshly-synced records** — persist diffs the store against a stale in-memory snapshot and deletes anything absent from it, so a record that just synced in from another device can be hard-deleted and that deletion propagates back through CloudKit.
3. **Swallowed save errors** — `try? context.save()` hides every failure (quota, account, validation), letting memory and store diverge invisibly.

## Current state

`Palettes/App/AppData.swift` (318 lines) — `@MainActor class AppData: ObservableObject`, single source of truth. Key excerpts as they exist today:

Debounced sinks (`:49-65`) — the guard that drops edits:

```swift
$colors
    .dropFirst()
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .sink { [weak self] updated in
        guard let self, !self.isReloading else { return }   // ← edit dropped here, no retry
        Task { @MainActor in self.persistColors(updated) }
    }
    .store(in: &cancellables)
```

Reload guard (`:90-100`): `reloadFromStore()` sets `isReloading = true`, calls `load()`, and a cancel-and-replace `reloadResetTask` clears the flag after 600 ms.

Persist with orphan deletion (`:162-192`, palettes analogous at `:194-224`):

```swift
private func persistColors(_ list: [ColorViewModel]) {
    guard let context = container?.mainContext else { return }
    let existing = (try? context.fetch(FetchDescriptor<StoredColor>())) ?? []
    // ... build byID map, upsert each item in `list`, collect duplicates ...
    for duplicate in duplicates { context.delete(duplicate) }
    for orphan in byID.values { context.delete(orphan) }   // ← deletes records not in the (stale) snapshot
    if context.hasChanges { try? context.save() }          // ← swallowed error
}
```

**Documented, intentional behavior — do not change**: no unique constraints on the SwiftData models (CloudKit requirement, see `Palettes/App/PersistentStore.swift` header comment); duplicate-id cleanup; UserDefaults-flag sample seeding.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| List simulators | `xcrun simctl list devices available` | pick `<SIM>` |
| Test | `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** TEST SUCCEEDED **` |

## Scope

**In scope**:
- `Palettes/App/AppData.swift`
- `PalettesTests/AppDataPersistenceTests.swift` (extend, created in plan 001)

**Out of scope**:
- `Palettes/App/PersistentStore.swift` — model shape is CloudKit-constrained; do not add constraints or fields.
- Any view file. The whole-array `@Published` pattern stays (a rearchitecture was considered and deferred).
- The debounce interval / RunLoop scheduler (recorded separately as a low-priority perf note).

## Git workflow

- Branch: `advisor/002-persistence-hardening` from `icloud-sync` (or from `dev` after the branch merges — ask the operator only if `icloud-sync` no longer exists)
- Conventional commits, e.g. `fix: retry persists dropped during CloudKit reloads`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Re-arm dropped persists instead of discarding them

In `AppData`, add two private flags: `pendingColorPersist = false`, `pendingPalettePersist = false`. In each sink's guard, when `isReloading` is true, set the corresponding pending flag before returning. In `reloadResetTask` (inside `reloadFromStore()`), after setting `isReloading = false`, check the pending flags and, for each set one, clear it and call `persistColors(self.colors)` / `persistPalettes(self.palettes)` with the **current** arrays (not a captured snapshot — the reload may have merged remote changes into them).

Caveat this correctly: the reload *replaces* the arrays from the store, so a pending local edit made before the reload is already gone from `self.colors`. To not lose it, reorder inside `reloadFromStore()`: if a pending flag is set **at reload time** (i.e., an edit debounce was outstanding), persist the current in-memory arrays *before* calling `load()`. Implement as: at the top of `reloadFromStore()`, if `pendingColorPersist` or a debounce is outstanding you cannot know — so instead persist unconditionally-if-dirty: add a `isDirty` flag set in each sink *immediately* via a separate non-debounced sink (`$colors.dropFirst().sink { ... isDirtyColors = true }` guarded by `!isReloading`), cleared inside `persistColors`. At the top of `reloadFromStore()`: `if isDirtyColors { persistColors(colors) }; if isDirtyPalettes { persistPalettes(palettes) }` before `load()`.

**Verify**: build succeeds; existing plan-001 tests pass.

### Step 2: Delete only explicitly-removed ids, not inferred orphans

Replace absence-inference with explicit deletion tracking:

- Add `private var deletedColorIDs: Set<UUID> = []` and `deletedPaletteIDs`.
- In `load()`, when mapping stored → view models, nothing changes.
- Introduce a small seam: the sinks currently can't tell a delete from an edit. Compute deletions in the sink: keep `private var lastPersistedColorIDs: Set<UUID>` (initialized in `load()` from the fetched store, updated at the end of each persist). In `persistColors`, replace `for orphan in byID.values { context.delete(orphan) }` with: delete a leftover `byID` entry **only if** its id is in `lastPersistedColorIDs` (i.e., we knew about it and the user removed it) — a leftover id we've never seen locally is a fresh remote record: keep it, and trigger `reloadFromStore()` after the save so it appears in the UI.
- Mirror for palettes.

**Verify**: build + tests pass.

### Step 3: Surface save failures

Replace both `try? context.save()` sites with:

```swift
do { try context.save() } catch {
    ToastManager.shared.show("Couldn't save your changes.", icon: "exclamationmark.triangle.fill")
    // keep dirty flag set so the next edit or reload retries
}
```

`ToastManager` is at `Palettes/Managers/ToastManager.swift` (`ToastManager.shared.show(_:icon:)` — see call site pattern at `Palettes/Views/Color/GenerateView.swift:537`). Keep the `isDirty` flag set on failure (don't clear it in the catch path) so step 1's reload-time flush retries.

**Verify**: build + tests pass; `grep -n "try? context.save()" Palettes/App/AppData.swift` → no matches.

### Step 4: Tests

Extend `PalettesTests/AppDataPersistenceTests.swift` (all `@MainActor`, in-memory container, remember the 300 ms debounce → sleep ~1 s after mutations):

1. **Edit survives reload window**: append a color; immediately invoke a reload (the method is private — make `reloadFromStore()` `internal` with a `/// internal for testing` comment, or test via `NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, ...)` which triggers it publicly — prefer the notification); wait 1.5 s; assert the color is still present in `appData.colors` after a second posted foreground notification (which reloads from the store — proving it was persisted, not just in memory).
2. **Remote record not deleted as orphan**: insert a `StoredColor` directly into the container behind AppData's back (requires access to the context — if no seam exists, add an `internal var testContext: ModelContext? { container?.mainContext }` guarded by `#if DEBUG`); then trigger an edit-persist and assert the direct-inserted record still exists.
3. **Explicit delete still works**: remove a color from `appData.colors`, wait, post foreground notification, assert it does not reappear.

## Done criteria

- [ ] `xcodebuild test ...` → `** TEST SUCCEEDED **`, including the 3 new tests above
- [ ] `grep -c "try? context.save()" Palettes/App/AppData.swift` → 0
- [ ] Only `Palettes/App/AppData.swift` and the test file modified (`git status`)
- [ ] `plans/README.md` row updated

## STOP conditions

- The excerpts don't match the live `AppData.swift` (file is under active development on this branch).
- Test 2 (remote-record survival) cannot be written without exposing more than the `#if DEBUG` context seam.
- Step 2's `lastPersistedColorIDs` approach conflicts with how `load()` replaces arrays in a way that makes deletes indistinguishable from reload-replacements — report the conflict with details rather than guessing semantics.
- Any step's verification fails twice.

## Maintenance notes

- This locks in "explicit deletion tracking" semantics; any future bulk-delete UI must go through the same arrays (it will) or update `lastPersistedColorIDs` deliberately.
- Reviewer: scrutinize the dirty-flag lifecycle (set on edit, cleared on successful persist only) and the reload-time flush ordering (flush *before* `load()` replaces the arrays).
- Deferred: replacing whole-array republish + debounce with per-entity mutations (PERF; not worth it at current library sizes), `DispatchQueue.main` debounce scheduler.
