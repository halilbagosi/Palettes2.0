# `aps-environment` in Palettes.entitlements

`Palettes/Palettes.entitlements` intentionally declares:

```xml
<key>aps-environment</key>
<string>development</string>
```

This is correct as committed. Both the Debug and Release build configurations in
`Palettes.xcodeproj/project.pbxproj` use `CODE_SIGN_STYLE = Automatic` (verified via
`grep -n "CODE_SIGN_STYLE" Palettes.xcodeproj/project.pbxproj`, both configs return
`Automatic`), and there is no per-configuration `CODE_SIGN_ENTITLEMENTS` override — a
single entitlements file is shared across configurations.

Under automatic signing, Xcode substitutes the correct `aps-environment` value at
sign time based on the provisioning profile/distribution method:

- Local Debug builds / development provisioning -> `development`
- TestFlight / App Store distribution builds -> `production`

So the source-controlled `development` value does not need to be (and should not be)
hand-edited to `production`. This only matters for CloudKit sync because the app relies
on silent APNs pushes (`remote-notification` background mode) to trigger
`NSPersistentCloudKitContainer.eventChangedNotification` reloads (see
`Palettes/App/AppData.swift`); a build signed with the wrong `aps-environment` would
receive no pushes and silently degrade to foreground-only sync reconciliation.

## Verify after any signing-mode change

If `CODE_SIGN_STYLE` is ever changed to `Manual` for the Release configuration (or a
per-configuration `CODE_SIGN_ENTITLEMENTS` is introduced), re-check whether
`aps-environment` still gets rewritten to `production` for distribution builds. If not,
split the entitlements file per configuration (Release entitlements pinned to
`production`) and point `CODE_SIGN_ENTITLEMENTS` at the right file per configuration.

## Real-device verification

Install a TestFlight build on two devices and confirm an edit made on one appears on
the other while both are foregrounded, within about 1 minute.
