# Plan 008: DX & hygiene — CI, lint, CLAUDE.md, untrack xcuserdata, fix the README

> **Executor instructions**: Follow step by step; verify each step; STOP
> conditions binding. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- .gitignore README.md`
> Written against `9726b96` + uncommitted `icloud-sync` tree.

## Status

- **Priority**: P2
- **Effort**: M (S per item)
- **Risk**: LOW
- **Depends on**: plans/001-test-baseline.md for the CI `test` job (CI `build` job has no dependency)
- **Category**: dx / docs
- **Planned at**: commit `9726b96`, 2026-07-15

## Why this matters

There is no automated gate of any kind: no CI, no lint/format config, no agent-facing conventions doc. The developer builds on a separate Xcode machine, so regressions currently surface only on manual build. Separately, per-user Xcode state is committed (leaks the local username, causes churn) and the README both omits the app's most privacy-relevant behavior (iCloud sync of all user data) and contradicts the code on OS versions.

## Current state

- No `.github/` directory, no `*.yml` workflows, no `.swiftlint.yml`/`.swiftformat`, no `CLAUDE.md`/`AGENTS.md` at repo root.
- Tracked per-user file: `Palettes.xcodeproj/xcuserdata/halilbagosi.xcuserdatad/xcschemes/xcschememanagement.plist`. `.gitignore` currently covers `graphify-out/`, `.claude/`, `docs/superpowers/`, `build/`, `.DS_Store` — not `xcuserdata`.
- `README.md` describes "local data persistence" only; the code syncs via CloudKit (`Palettes/App/AppData.swift:36-42` — cloud container with local fallback; `Palettes/Palettes.entitlements` — container `iCloud.com.halilbagosi.Palettes`). README claims "iOS 27+"; the deployment target is iOS 17.0 and AI features gate on `@available(iOS 26.0, *)` (`Palettes/Managers/PaletteGenerator.swift:13,23,36`).
- Repo conventions to document: MVVM; `AppData` (`Palettes/App/AppData.swift`) is the single source of truth publishing value-type view models; persistence is debounced write-back to SwiftData/CloudKit; branch flow is feature → `dev` → `staging` → `main`; graphify knowledge graph at `graphify-out/` with a query-first rule (already stated in `/Users/halilbagosi/CLAUDE.md` — the *project-root* CLAUDE.md this plan creates is for this repo checked in).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Untrack check | `git ls-files \| grep xcuserdata` | empty after step 2 |
| Build (CI parity) | `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |

## Scope

**In scope**: `.gitignore`, `git rm --cached` of the xcuserdata plist, `README.md`, new `CLAUDE.md` (repo root), new `.github/workflows/ci.yml`, new `.swiftformat` (or `.swiftlint.yml` — pick SwiftFormat, lighter).

**Out of scope**: any Swift source; the pbxproj; rewriting README marketing copy beyond the two factual fixes + sync section.

## Git workflow

Branch `advisor/008-dx-hygiene`; conventional commits per item (`chore:`, `docs:`, `ci:`); no push/PR unless instructed.

## Steps

### Step 1: gitignore + untrack xcuserdata

Append to `.gitignore`:

```
xcuserdata/
*.xcuserstate
```

Then `git rm -r --cached Palettes.xcodeproj/xcuserdata` and commit.

**Verify**: `git ls-files | grep xcuserdata` → empty; the file still exists on disk (`ls Palettes.xcodeproj/xcuserdata`).

### Step 2: README fixes

- Change OS claims: minimum iOS 17; Apple Intelligence generation requires iOS 26+ and a supported device; "iOS 27" branding only where it refers to current-OS visual features (keep tone, fix facts).
- Add a "## ☁️ Sync & Privacy" section: palettes/colors sync via the user's private CloudKit database (container `iCloud.com.halilbagosi.Palettes`); falls back to a purely local store when iCloud is unavailable, and to a session-only in-memory library as a last resort; no data is sent to any third party; AI generation runs entirely on-device.

**Verify**: `grep -n "Sync & Privacy" README.md` → one match; `grep -cn "iOS 27+" README.md` → 0.

### Step 3: CLAUDE.md (repo root, checked in)

Create `CLAUDE.md` (~30 lines) containing exactly these facts: build/test commands (from plan 001's table, including the simulator-listing step); target and scheme are both `Palettes`; new Swift files are auto-included via synchronized groups (no pbxproj edit needed); architecture one-liner (MVVM, `AppData` single source of truth, debounced SwiftData/CloudKit write-back — do not bypass it); the palette parallel-arrays caveat (or, if plan 003 has landed, "mutate `paletteColors` only"); iOS 17 deployment target with iOS 26 APIs behind `Palettes/Compatibility/` shims — extend the shims rather than raising the target; branch flow feature → `dev` → `staging` → `main`; graphify-first rule (`graphify query` before raw exploration, `graphify update .` after changes).

**Verify**: file exists; every command in it copy-paste matches plan 001's verified commands.

### Step 4: SwiftFormat config + CI

Create `.swiftformat` with a minimal, current-style-matching config (`--swiftversion 5`, `--indent 4`, disable rules that would mass-rewrite: run `swiftformat --lint Palettes` locally if available; if >50 violations, add `--disable` for the noisiest rules until lint passes with zero changes — the goal is ratcheting, not a big-bang reformat. If swiftformat is not installed on this machine, still write the config, note it in the report, and let CI be the first enforcement).

Create `.github/workflows/ci.yml`: on push/PR to `dev`, `staging`, `main`; `runs-on: macos-15`; steps: checkout, select latest Xcode (`sudo xcode-select -s /Applications/Xcode_*.app` or `maxim-lobanov/setup-xcode`), `xcodebuild build ... CODE_SIGNING_ALLOWED=NO`, and — gated on plan 001 being landed (check for `xcshareddata/xcschemes/Palettes.xcscheme`) — `xcodebuild test ...`. If plan 001 has not landed, ship build-only and note it.

**Verify**: `yamllint`-level sanity (`python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` → no error). Actual CI runs only after push — out of executor scope; note in report.

## Done criteria

- [ ] `git ls-files | grep -c xcuserdata` → 0
- [ ] README has the Sync & Privacy section and no false OS claims
- [ ] `CLAUDE.md` exists with build commands, conventions, branch flow
- [ ] `.github/workflows/ci.yml` parses as YAML; `.swiftformat` exists
- [ ] `plans/README.md` row updated

## STOP conditions

- `git rm --cached` would remove anything beyond the single xcuserdata plist (check first with `git ls-files | grep xcuserdata`).
- The repo has no GitHub remote (`git remote -v` empty) — write the workflow anyway but flag that CI needs a remote.

## Maintenance notes

- CI simulator/Xcode versions rot; pin them and expect to bump quarterly.
- When plan 001 lands after this, un-gate the CI test job.
- Deferred: SwiftLint (heavier), pre-commit hooks, DangerFile.
