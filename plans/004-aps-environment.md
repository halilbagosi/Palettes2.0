# Plan 004: Ensure release builds get production APNs so CloudKit sync works outside development

> **Executor instructions**: Follow step by step; verify each step; STOP
> conditions are binding. Update `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat 9726b96..HEAD -- Palettes/Palettes.entitlements Palettes.xcodeproj/project.pbxproj`
> Written against commit `9726b96` + uncommitted `icloud-sync` tree.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security/config
- **Planned at**: commit `9726b96`, 2026-07-15

## Why this matters

CloudKit cross-device sync is triggered by silent APNs pushes (the app registers `remote-notification` background mode and reloads on `NSPersistentCloudKitContainer.eventChangedNotification`). The committed entitlements pin `aps-environment` to `development`; a TestFlight/App Store build signed with that value receives no production pushes, so sync silently degrades to foreground-only reconciliation. Users would see stale data until they background/foreground the app.

## Current state

`Palettes/Palettes.entitlements` (entire relevant section):

```xml
<key>aps-environment</key>
<string>development</string>
```

Consumers: `Palettes/App/AppData.swift:69-77` (CloudKit import notification reload), `:79-82` (foreground fallback reload); `Palettes/AppInfo.plist` has `UIBackgroundModes: [remote-notification]`.

Context: with **automatically managed signing**, Xcode swaps `aps-environment` to `production` for distribution builds — the committed `development` value is then correct for the source entitlements file. This plan's job is to *verify* which signing mode the project uses and make the release path explicit, not to blindly flip the value.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Check signing mode | `grep -n "CODE_SIGN_STYLE" Palettes.xcodeproj/project.pbxproj` | `Automatic` or `Manual` per config |
| Build | `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"` | `** BUILD SUCCEEDED **` |

## Scope

**In scope**: `Palettes/Palettes.entitlements`, possibly a `Palettes-Release.entitlements` + `CODE_SIGN_ENTITLEMENTS` per-config setting in `project.pbxproj`, and a short note in `README.md`'s (new, from plan 008) sync section.

**Out of scope**: all Swift source; provisioning profiles; anything requiring the Apple Developer portal (report if needed).

## Git workflow

Branch `advisor/004-aps-environment`; conventional commit (`fix:`); no push/PR unless instructed.

## Steps

### Step 1: Determine signing mode

Run the grep above. If `CODE_SIGN_STYLE = Automatic` for the Release configuration: automatic signing rewrites `aps-environment` at distribution time — **no entitlement change needed**. Add a comment-equivalent instead: document in the plan-008 README section (or a `docs/` note if 008 hasn't run) that release APS environment is handled by automatic signing, and mark this plan DONE with that note.

### Step 2 (only if Manual signing): Split entitlements per configuration

Create `Palettes/Palettes-Release.entitlements` (copy of the current file with `aps-environment` = `production`); set `CODE_SIGN_ENTITLEMENTS` to the release file for the Release configuration only in `project.pbxproj`. Debug keeps `development`.

**Verify**: `xcodebuild build` succeeds for both `-configuration Debug` and `-configuration Release` (Release may fail on signing without a device profile — a signing failure at the *provisioning* stage with the entitlement accepted is OK; an "entitlement not allowed" error is a STOP).

### Step 3: Real-device verification note

Automated checks can't prove push delivery. Add to the final report: "verify by installing a TestFlight build on two devices and confirming an edit on one appears on the other while both are foregrounded, within ~1 min."

## Done criteria

- [ ] Signing mode determined and recorded in the completion note
- [ ] If manual: Release builds sign with `aps-environment` = `production`; Debug unchanged
- [ ] `xcodebuild build` succeeds
- [ ] `plans/README.md` row updated with which branch of step 1 applied

## STOP conditions

- "Entitlement not allowed" / capability errors (App ID lacks push capability — needs the developer portal, which the executor must not touch).
- `CODE_SIGN_STYLE` differs between configs in a way not covered above.

## Maintenance notes

- If push notifications (user-facing) are ever added, this entitlement handling is the same mechanism — revisit then.
- TestFlight sync test is the only true verification; flag it in the PR description.
