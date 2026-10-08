# Palettes App Store Launch Readiness

## Purpose

This document is the implementation and verification checklist for preparing Palettes for public App Store distribution. It is written for an execution agent with no prior conversation context.

The work covers:

- Apple App Store Review requirements.
- Privacy, legal, data collection, and transparency requirements.
- Security and data-lifecycle hardening.
- Apple Human Interface Guidelines and accessibility readiness.
- App Store Connect metadata and review preparation.
- Release, TestFlight, device, and regression verification.

This document is based on the repository state observed at commit `c2d8700` plus the existing uncommitted working tree. The working tree was already dirty before this document was created; do not discard or overwrite unrelated changes.

The application is a native SwiftUI/SwiftData iOS app targeting iOS 17+, with iOS 26-only Foundation Models generation, camera/photo color extraction, local palette storage, exports, App Intents, and Spotlight indexing.

## Execution rules

1. Read this entire document before changing source.
2. Preserve existing user changes. Do not use destructive Git commands.
3. Do not add analytics, crash-reporting, advertising, cloud APIs, or AI providers without updating the privacy, App Privacy, security, and App Review sections.
4. Do not claim that data is local-only or that nothing leaves the device until the signed Release build has been verified.
5. Legal text must be reviewed by the product owner and, where required, qualified counsel. The implementation agent must not invent jurisdiction-specific legal promises.
6. If CloudKit is not intended for this launch, choose the local-only path below and remove contradictory iCloud behavior and marketing.
7. If a verification step cannot run because the machine lacks Xcode components, a physical device, a simulator runtime, or Apple Developer access, report it as `BLOCKED` with the exact missing prerequisite.
8. Do not mark the launch complete until every P0 item is closed and every P1 item has either been completed or explicitly accepted by the product owner.

## Status legend

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked or requires a product/legal decision
- `P0` submission blocker or material privacy/security risk
- `P1` required before a responsible launch; may not be an automatic rejection
- `P2` quality, maintainability, or HIG polish item

## Current baseline and known facts

### Product and runtime

- SwiftUI/UIKit application.
- SwiftData persistence with `StoredColor`, `StoredPalette`, and `StoredTag`.
- iOS 17 deployment target.
- iOS 26-only generation and App Intents/Spotlight surfaces.
- Apple Foundation Models are used through `LanguageModelSession`.
- Camera capture uses `UIImagePickerController`.
- Library selection uses `PhotosPicker`.
- Exports include CSS, SCSS, SwiftUI, Tailwind, JSON, plain HEX, SVG, Coolors URL, ASE, and PDF.
- No account/sign-in UI was found.
- No public social feed or user-to-user service was found.

### Current privacy/security positives

- No hardcoded credentials or obvious secrets were found.
- No analytics, advertising, tracking, Firebase, Sentry, Crashlytics, or third-party AI SDK was found.
- No `URLSession`-based application backend was found.
- Image extraction appears to happen locally.
- The generation flow sends colors, names, and vibe text to the Apple Foundation Models API; it does not pass the source photo to the model.
- User-triggered copying and sharing are explicit actions rather than silent background transfers.

### Current launch risks

1. The app icon set contains metadata but no actual icon image.
2. Code attempts automatic CloudKit storage, but iCloud entitlements are commented out.
3. README and badges promise private iCloud sync despite the entitlement mismatch.
4. `remote-notification` is present in `Info.plist` while the CloudKit/APNs entitlements are disabled.
5. No privacy policy, privacy screen, terms page, or legal/support resources were found.
6. Recent search terms are stored locally but are not included in an obvious data-management flow.
7. Spotlight indexing is detached, destructive, fire-and-forget, and silently ignores errors.
8. Generation errors are logged as public strings.
9. JSON export manually escapes strings but does not escape all JSON control characters.
10. Several image-only controls, custom sliders, and gesture-driven photo controls need accessibility validation or improvement.
11. Some control hit regions are below the HIG-recommended 44x44 pt size.
12. The Release build was not fully verified in the audit environment because the Metal Toolchain and simulator services were unavailable.

## Decision 0: choose the launch data model

This decision must be made before implementing privacy text, App Privacy answers, or App Review notes.

### Option A — local-only launch

Choose this if private iCloud sync is not essential to the first release.

- [ ] Remove or disable the automatic CloudKit configuration path in `Palettes/App/AppData.swift`.
- [ ] Keep only the local SwiftData configuration, with a clear failure state if local persistence cannot be created.
- [ ] Remove `UIBackgroundModes` → `remote-notification` from `Palettes/AppInfo.plist` unless another verified feature requires it.
- [ ] Keep iCloud and sync out of the README, App Store description, screenshots, keywords, and review notes.
- [ ] State that library data is stored locally on the device.
- [ ] Recalculate App Store Privacy answers from the signed local-only binary.
- [ ] Verify that no photo, palette, search, or model input is transmitted by the application.

### Option B — CloudKit launch

Choose this only if the product owner is ready to support iCloud sync operationally.

- [ ] Add the CloudKit capability to the App ID and target.
- [ ] Add the production iCloud container entitlement to the shipping target.
- [ ] Configure the correct APS environment for Release distribution.
- [ ] Ensure the container is deployed to the production environment.
- [ ] Confirm the SwiftData/CloudKit model is CloudKit-compatible and migration-safe.
- [ ] Keep the remote-notification background mode only if the CloudKit integration actually requires it.
- [ ] Test with two physical devices signed into the same iCloud account.
- [ ] Test with no iCloud account.
- [ ] Test iCloud disabled, network unavailable, offline edits, delayed imports, duplicate edits, and merge behavior.
- [ ] Test iCloud storage full and CloudKit errors.
- [ ] Test account sign-out, account change, device restore, and app reinstall behavior.
- [ ] Implement an in-app way to view/export user library data.
- [ ] Implement an in-app way to delete local and cloud-backed library data, or document an equivalent supported deletion flow.
- [ ] Update the privacy policy to describe Apple CloudKit storage, private database behavior, retention, deletion, and user control.
- [ ] Update App Privacy answers to reflect data transmitted/stored through CloudKit.
- [ ] Update App Review notes with exact iCloud testing instructions.

Do not leave the project in a state where README, entitlements, runtime behavior, privacy policy, and App Store metadata describe different data flows.

## P0 — submission blockers

### P0-01: provide a real App Store icon

**Evidence:** `Palettes/Utilities/Assets.xcassets/AppIcon.appiconset/Contents.json` contains an App Store-sized entry but no referenced image file.

**Implementation:**

- [ ] Add the final 1024x1024 App Store icon to the asset catalog.
- [ ] Confirm the asset catalog references the actual file.
- [ ] Check that the icon has no transparency or prohibited borders if Apple’s current validation rejects them.
- [ ] Generate a Release archive and confirm the icon appears in the archive and installed app.
- [ ] Verify the icon on the Home Screen, Settings, Spotlight, share sheet, and TestFlight.

**Acceptance criteria:**

- `actool` reports a real AppIcon asset.
- The installed Release/TestFlight build displays the correct icon.
- App Store Connect accepts the uploaded build without missing-icon validation errors.

Apple reference: [Add an app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon).

### P0-02: resolve iCloud implementation versus marketing mismatch

**Evidence:**

- `Palettes/App/AppData.swift:64-72` prefers CloudKit and falls back locally.
- `Palettes/Palettes.entitlements:5-18` has the iCloud/APNs entitlements commented out.
- `Palettes/AppInfo.plist:7-10` declares `remote-notification`.
- `README.md:5`, `README.md:11`, and `README.md:125-129` promise iCloud sync.

**Implementation:** complete either Option A or Option B above. Do not make a partial fix.

**Acceptance criteria:**

- The signed Release build has exactly the intended storage behavior.
- README, privacy policy, App Store metadata, entitlements, and runtime behavior agree.
- No unnecessary background capability remains.
- A reviewer can understand whether an iCloud account is required, optional, or irrelevant.

### P0-03: publish and expose the privacy policy

**Implementation:**

- [ ] Obtain a stable HTTPS privacy-policy URL.
- [ ] Add a visible in-app Privacy/Legal entry point, preferably in Settings or an About screen.
- [ ] Link the same policy from App Store Connect.
- [ ] Include a contact address for privacy requests.
- [ ] Include effective date and version/change history.
- [ ] Ensure the URL works without requiring an account or an app install.
- [ ] Verify the policy matches the final binary, not an earlier development configuration.

**Acceptance criteria:**

- A reviewer can reach the policy from inside the app.
- The URL is reachable on a fresh device.
- The policy describes every data flow listed in the data inventory below.

Apple reference: [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).

### P0-04: make a valid Release archive

**Implementation:**

- [ ] Install/enable the required Metal Toolchain.
- [ ] Install a supported iOS simulator runtime or use physical devices.
- [ ] Build the exact Release configuration used for App Store Connect.
- [ ] Run unit tests.
- [ ] Run UI/accessibility checks on physical devices.
- [ ] Archive with the correct team, bundle identifier, provisioning, entitlements, and distribution signing.
- [ ] Validate the archive in Xcode Organizer and App Store Connect.

**Current blocker:** the audit environment reported a missing Metal Toolchain and unavailable simulator service. This is an environment blocker, not evidence that the app compiles or fails to compile.

**Acceptance criteria:**

- Release archive succeeds.
- Archive validation succeeds.
- TestFlight install succeeds on each supported device class.
- No runtime crash occurs during the smoke-test matrix.

## P1 — privacy, legal, and transparency

### P1-01: create the data inventory

Document each item in the final privacy policy and App Store Privacy questionnaire.

| Data or capability | Current location/flow | Local or transmitted | Required disclosure/action |
|---|---|---|---|
| Saved colors | SwiftData `StoredColor` | Local; CloudKit if Option B | Explain storage, retention, export, deletion |
| Saved palettes | SwiftData `StoredPalette` | Local; CloudKit if Option B | Explain storage, retention, export, deletion |
| Custom tags | SwiftData `StoredTag` | Local; CloudKit if Option B | Include in data deletion/export |
| Palette/color names | SwiftData, Spotlight/App Intents | Local OS indexes; CloudKit if Option B | Explain indexing and deletion behavior |
| Recent searches | `@AppStorage("recentSearches")` | Local | Disclose and clear during complete data deletion |
| Camera images | `UIImagePickerController` | In-memory processing unless implementation changes | Explain camera purpose and that images are not retained/transmitted if true |
| Selected photos | `PhotosPicker` | In-memory processing unless implementation changes | Explain local extraction and no retention if true |
| AI vibe text | Foundation Models prompt | Apple model path; verify OS behavior | Disclose on-device/default model behavior and limitations |
| Base color names/hexes | Foundation Models prompt | Apple model path; verify OS behavior | Include in AI processing disclosure |
| Clipboard contents | Explicit copy action | System pasteboard | Explain only if relevant to policy; never copy silently |
| Exported files | User-selected share destination | Destination chosen by user | Explain user-controlled sharing |
| Sample data | First-launch seed | Local; CloudKit if Option B | Confirm whether it syncs and whether users can delete it |

### P1-02: implement a complete data deletion flow

The product needs a clear meaning for “delete my data.”

- [ ] Delete all saved colors.
- [ ] Delete all saved palettes.
- [ ] Delete all custom tags.
- [ ] Clear recent searches.
- [ ] Remove Spotlight/App Intent entities.
- [ ] Clear any generated temporary exports that are still controlled by the app.
- [ ] Reset sample-data flags if appropriate.
- [ ] If CloudKit is enabled, delete or tombstone the corresponding cloud records and handle failures visibly.
- [ ] Confirm deletion survives relaunch and reindexing.
- [ ] Document whether iCloud backups or Apple-managed system caches are outside the app’s direct control.

Apple reference: [Responding to requests to delete data](https://developer.apple.com/documentation/cloudkit/responding-to-requests-to-delete-data).

### P1-03: implement data export/access support

If CloudKit is enabled, provide a simple way for users to access or export their library data. Even for local-only mode, an “Export library data” function is useful for user trust and migration.

- [ ] Define an export format for all user-created records, not only one selected palette.
- [ ] Include colors, palettes, roles, tags, favorites, and relevant identifiers.
- [ ] Do not include internal credentials, device identifiers, or unrelated metadata.
- [ ] Make export user-initiated.
- [ ] Test importability or document that export is archival only.

### P1-04: create Terms of Use if product scope requires them

A custom Terms of Use page is not automatically required for every simple utility, but it is recommended if the launch includes iCloud sync, monetization, AI generation, public sharing, or meaningful user-content processing.

Possible sections:

- License to use the app.
- Ownership of user-created names, palettes, and exports.
- User responsibility for photos and imported content.
- AI-generated names/output may be inaccurate or unsuitable.
- No guarantee of color accessibility or brand suitability.
- Third-party Apple services and system share destinations.
- Acceptable use and prohibited misuse.
- Export/share responsibility.
- Limitation of liability and warranty language.
- Termination and data deletion.
- Governing law and support contact.
- Terms-change process.

Do not write jurisdiction-specific legal language without review.

### P1-05: fix camera permission transparency

Current string: `Palettes/AppInfo.plist:5-6`.

- [ ] Replace it with a clear camera rationale.
- [ ] Test denied permission and explain how to re-enable it.
- [ ] Never retain or upload a camera image unless explicitly documented and user-authorized.
- [ ] Confirm the camera screen closes cleanly after cancellation.
- [ ] Confirm the app does not imply that camera access is required for the core library.

### P1-06: disclose Apple Foundation Models behavior accurately

Current generation setup is in `Palettes/Managers/PaletteGenerator.swift:62-64` and `:164-168`.

- [ ] State that AI generation is available only on supported iOS 26/Apple Intelligence configurations.
- [ ] State what user inputs are sent to the model API: vibe text, color names, and colors.
- [ ] State whether photos are excluded from model input.
- [ ] Verify the final operating-system behavior of the default model before claiming fully on-device processing.
- [ ] If the model path ever changes to Private Cloud Compute or an external provider, update the privacy policy, App Privacy answers, App Review notes, and in-app disclosure before shipping.
- [ ] Add a user-visible failure state for unavailable model hardware/region/OS conditions.
- [ ] Review generated names for inappropriate or misleading output.
- [ ] Keep deterministic hex validation and bounds checking around generated output.

Apple references: [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init%28model%3Atools%3Ainstructions%3A%29), and [Improving the safety of generative model output](https://developer.apple.com/documentation/FoundationModels/improving-the-safety-of-generative-model-output).

## P1 — security and data handling

### P1-07: make Spotlight indexing serialized and deletion-safe

**Evidence:** `Palettes/Intents/EntityIndexer.swift:15-24` deletes all entities, reindexes asynchronously, and ignores all failures.

**Implementation:**

- [ ] Serialize reindex jobs so only the newest snapshot is applied.
- [ ] Coalesce rapid edits.
- [ ] Prefer targeted deletion/update APIs where practical.
- [ ] Track or log failures privately without exposing user names or prompt content.
- [ ] Ensure deletion is not followed by an older queued snapshot that re-adds the item.
- [ ] Add tests for create, rename, delete, rapid edits, app termination, and stale index recovery.
- [ ] Decide whether Spotlight should expose names on a locked device and document that behavior.

**Acceptance criteria:** after deleting or renaming an item, Spotlight and Siri no longer return the previous entity after a bounded synchronization period.

### P1-08: sanitize generation logging

**Evidence:** `Palettes/Managers/PaletteGenerator.swift:190-193` logs `String(describing: error)` with public privacy.

- [ ] Use private or sanitized logging.
- [ ] Do not log prompts, vibes, palette names, image content, or full model responses.
- [ ] Keep user-facing errors generic and actionable.
- [ ] Add a test or code review check preventing prompt/user-content interpolation in public logs.

### P1-09: replace hand-built JSON serialization

**Evidence:** `Palettes/Managers/PaletteExporter.swift:141-145` and `:198-211` implement partial escaping manually.

- [ ] Define Codable export structs.
- [ ] Encode through `JSONEncoder`.
- [ ] Preserve the existing output schema unless a deliberate version change is approved.
- [ ] Add tests for quotes, backslashes, newline, tab, carriage return, Unicode, emoji, control characters, empty names, and long names.
- [ ] Confirm exported JSON parses with a strict parser.

### P1-10: validate all export boundaries

- [ ] Confirm all user-controlled text is safely encoded for its format.
- [ ] Keep SVG text/attribute escaping correct.
- [ ] Reject or normalize invalid XML control characters.
- [ ] Keep CSS/SCSS/Tailwind/SwiftUI identifiers slugified and collision-safe.
- [ ] Validate color hexes before inserting them into generated files.
- [ ] Ensure palette names used in temporary filenames cannot escape the temporary directory.
- [ ] Test names containing slashes, colons, quotes, newlines, Unicode, and path separators.
- [ ] Test very large palettes and very long names for memory and layout failures.
- [ ] Test exported SVG and PDF in Apple Preview, Safari, Files, and a representative design tool.

### P1-11: clean temporary export files

**Evidence:** `Palettes/Views/Components/ExportPaletteSheet.swift:107-134` writes SVG/ASE/PDF files to `temporaryDirectory`.

- [ ] Track generated file URLs.
- [ ] Delete them after the share controller finishes where feasible.
- [ ] Clean stale files on next launch.
- [ ] Do not delete files that a user explicitly saved outside the app’s temporary directory.
- [ ] Document retention behavior if cleanup cannot be guaranteed.

### P1-12: review clipboard behavior

**Evidence:** `Palettes/Managers/ToastManager.swift:91-95` writes copied values to `UIPasteboard.general`.

- [ ] Confirm every clipboard write is directly user initiated.
- [ ] Do not read clipboard contents without an explicit feature requiring it.
- [ ] Use a clear “Copied HEX” confirmation.
- [ ] Document clipboard behavior if required by the final privacy policy.

### P1-13: review data lifecycle on app backgrounding and termination

- [ ] Confirm unsaved palette/color changes are flushed safely.
- [ ] Confirm app termination during a debounced save does not drop edits.
- [ ] Confirm CloudKit imports cannot overwrite unsaved local changes.
- [ ] Confirm camera/photo images are released when leaving the workflow.
- [ ] Confirm generation cancellation stops model work and does not save partial invalid data.
- [ ] Confirm temporary exports do not survive longer than intended.

## P1 — App Store Connect and App Review

### P1-14: complete required metadata

- [ ] App name.
- [ ] Subtitle.
- [ ] Keywords.
- [ ] Description.
- [ ] Category and secondary category if appropriate.
- [ ] Age rating.
- [ ] Copyright.
- [ ] Privacy policy URL.
- [ ] Support URL.
- [ ] Optional privacy choices/data-request URL.
- [ ] iPhone screenshots.
- [ ] iPad screenshots.
- [ ] Optional app preview.
- [ ] Export compliance answers if requested.
- [ ] Content rights/trademark answers where applicable.
- [ ] App Review contact information.

All metadata must describe the submitted binary accurately. Do not advertise iCloud sync, AI generation, or export formats unless they work in the submitted build.

Apple references: [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties) and [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

### P1-15: write App Review notes

Include concise instructions covering:

- No login/account is required, if still true.
- How to create a palette.
- How to test camera/photo color extraction.
- How to test export/share.
- How to test App Intents and Spotlight on iOS 26.
- How to test AI generation and supported hardware/OS requirements.
- Whether iCloud is enabled, optional, or absent.
- Any features unavailable on the reviewer’s device.
- Contact information for review questions.

Apple asks for detailed explanations of non-obvious features and full access before submission. Reference: [App Review Guidelines — Before You Submit](https://developer.apple.com/app-store/review/guidelines/).

### P1-16: review trademark and third-party references

- [ ] Verify whether “Coolors” may be used in product metadata, screenshots, descriptions, or keywords.
- [ ] Keep third-party service names out of App Store metadata unless necessary and permitted.
- [ ] Do not imply Apple endorsement through wording, badges, or screenshots.
- [ ] Verify Apple Intelligence/Foundation Models branding language against current Apple guidance.
- [ ] Keep third-party URLs user initiated and clearly labeled.

## P2 — Human Interface Guidelines and accessibility

### P2-01: label all controls

**Evidence:** image-only controls in `Palettes/Views/Components/Selection/SelectionBottomBar.swift:22-41` do not provide explicit accessibility labels.

- [ ] Label Delete, Share, Favorite/Unfavorite, Close, Copy, Add, Remove, and Edit controls.
- [ ] Include state in labels, for example “Favorite palette” versus “Remove palette from favorites.”
- [ ] Include selection count when relevant.
- [ ] Confirm disabled controls explain why they are disabled where needed.

### P2-02: make custom sliders accessible

**Evidence:** `Palettes/Views/Components/AdjustmentSlider.swift:16-35` uses a bare `Slider` with visible labels but no explicit accessibility value/adjustment description.

- [ ] Add an accessibility label for Temperature, Saturation, and Brightness.
- [ ] Add a localized accessibility value such as “Warm,” “Neutral,” or “Cool.”
- [ ] Ensure increment/decrement actions update the visible value.
- [ ] Test with VoiceOver and Switch Control.

### P2-03: provide an accessible photo color-picking path

**Evidence:** `Palettes/Views/Components/PhotoColorPickerView.swift:58-69` relies on a zero-distance drag gesture.

- [ ] Add an accessibility label and hint for the image.
- [ ] Add an accessible alternate action to use the dominant/extracted color.
- [ ] Expose the sampled HEX/RGB value to VoiceOver.
- [ ] Ensure “Use” and “Cancel” are discoverable and correctly enabled.
- [ ] Test when no sample exists and when a sample is preselected.

### P2-04: fix hit regions

**Evidence:** copy controls use 38–40 pt visual frames in cells such as `ColorCellBig.swift:96-107` and `PaletteCell.swift:73-82`.

- [ ] Preserve the visual design if desired, but expand the tappable content shape to at least 44x44 pt.
- [ ] Test on iPhone with one-handed use and Dynamic Type.

Apple reference: [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).

### P2-05: Dynamic Type and layout resilience

- [ ] Replace nonessential hard-coded text sizes with system text styles.
- [ ] Test the largest accessibility text sizes.
- [ ] Test long localized names and user-entered names.
- [ ] Remove truncation where it hides important values.
- [ ] Test iPhone portrait/landscape and iPad split view.
- [ ] Test keyboard presentation and hardware keyboard navigation.
- [ ] Test empty, one-item, and maximum-size libraries.

Apple reference: [Typography](https://developer.apple.com/design/human-interface-guidelines/typography).

### P2-06: Light Mode, Dark Mode, contrast, and color-only meaning

- [ ] Test Light Mode, Dark Mode, Increase Contrast, Reduce Transparency, and Color Filters.
- [ ] Do not communicate selection, favorite, error, or status by color alone.
- [ ] Verify text contrast over arbitrary swatches and glass/material surfaces.
- [ ] Ensure custom colors have sensible light/dark variants where they are UI colors.
- [ ] Add accessibility labels that include semantic roles, not only color names.

Apple references: [Color](https://developer.apple.com/design/human-interface-guidelines/color), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), and [Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion).

### P2-07: Reduce Motion

- [ ] Test the photo loupe spring animation.
- [ ] Test generation transitions and shader effects.
- [ ] Test toasts, card transitions, and palette reveal animations.
- [ ] Respect `accessibilityReduceMotion` consistently.
- [ ] Ensure the app remains understandable when animations are disabled.

### P2-08: review Liquid Glass placement

The app uses Liquid Glass on content cards, text fields, and content surfaces. Review uses such as:

- `Palettes/Views/Components/ColorInputView.swift:241-283`
- `Palettes/Views/Components/Cells/PaletteCell.swift`
- `Palettes/Views/Components/Cells/ColorCellBig.swift`

Use Liquid Glass primarily for functional controls, navigation, and transient UI. Keep content backgrounds and essential text legible without depending on translucency.

Apple reference: [Materials](https://developer.apple.com/design/human-interface-guidelines/materials).

## P1 — testing and verification plan

### Build and static checks

- [ ] `xcodebuild -list -project Palettes.xcodeproj` succeeds.
- [ ] `plutil -lint Palettes/AppInfo.plist` succeeds.
- [ ] `plutil -lint Palettes/Palettes.entitlements` succeeds.
- [ ] Debug build succeeds.
- [ ] Release build succeeds.
- [ ] Unit tests succeed.
- [ ] Archive succeeds with distribution signing.
- [ ] Archive validation succeeds.
- [ ] App Store Connect accepts the build.
- [ ] No secrets or private credentials are present in the archive or repository.

### Unit and integration coverage

- [ ] Persistence save/reload and dropped-edit cases.
- [ ] CloudKit import/export/merge cases if Option B.
- [ ] Complete data deletion.
- [ ] Spotlight indexing, stale deletion, and reindex failure behavior.
- [ ] Camera cancellation and permission failure.
- [ ] PhotosPicker cancellation and malformed image data.
- [ ] JSON export strict parsing.
- [ ] SVG XML parsing with hostile/invalid text input.
- [ ] ASE parsing round trip.
- [ ] PDF generation with long and unusual names.
- [ ] Filename sanitization for every binary export.
- [ ] Generation unavailable/error/cancellation paths.
- [ ] App Intent validation and error output.

### Physical-device matrix

- [ ] iOS 17 iPhone.
- [ ] iOS 17 iPad.
- [ ] iOS 26 Apple Intelligence-compatible iPhone.
- [ ] iOS 26 Apple Intelligence-compatible iPad.
- [ ] Light Mode.
- [ ] Dark Mode.
- [ ] VoiceOver.
- [ ] Dynamic Type maximum sizes.
- [ ] Increase Contrast.
- [ ] Reduce Motion.
- [ ] Reduce Transparency.
- [ ] Camera permission allowed/denied/revoked.
- [ ] Photos permission/cancellation behavior.
- [ ] Airplane mode.
- [ ] Low storage.
- [ ] App killed during save, export, photo extraction, and generation.
- [ ] External keyboard and iPad multitasking.

### CloudKit matrix, only for Option B

- [ ] First launch with an empty private database.
- [ ] Existing library imported from another device.
- [ ] Simultaneous edits on two devices.
- [ ] Delete on device A and import on device B.
- [ ] Rename while offline.
- [ ] Network failure during save.
- [ ] iCloud account unavailable.
- [ ] iCloud storage full.
- [ ] App reinstall and restore.
- [ ] iCloud account change.
- [ ] Data export and deletion.
- [ ] Spotlight does not reveal deleted records after sync.

## Implementation order

1. Make the local-only versus CloudKit decision.
2. Establish a working Release build environment.
3. Add the real App Store icon.
4. Correct entitlements, background modes, and persistence behavior.
5. Implement privacy/legal/support surfaces.
6. Implement complete local/cloud data deletion and export.
7. Harden Spotlight, logging, JSON export, filenames, and temporary-file cleanup.
8. Add accessibility labels, slider semantics, hit-region fixes, and photo-picker alternatives.
9. Complete Dynamic Type, contrast, Dark Mode, Reduce Motion, and Liquid Glass review.
10. Add missing unit/integration/UI coverage.
11. Run the physical-device matrix.
12. Complete App Store Connect metadata, App Privacy answers, screenshots, and review notes.
13. Submit the exact TestFlight/Release build for final owner review.

## Definition of done

The launch preparation is complete only when all of the following are true:

- [ ] P0 items are complete.
- [ ] The final binary’s storage behavior matches its privacy policy and App Store metadata.
- [ ] The app icon is present and validated.
- [ ] Privacy policy and support URL work from a fresh device/browser.
- [ ] App Privacy answers have been reviewed against the final binary.
- [ ] Users can understand camera, photo, AI, iCloud, Spotlight, clipboard, and export behavior.
- [ ] User data can be deleted completely within the promised scope.
- [ ] CloudKit behavior is tested if enabled.
- [ ] No public logs contain user prompts, names, or sensitive model errors.
- [ ] Exported files are valid and safely encoded.
- [ ] VoiceOver, Dynamic Type, contrast, Dark Mode, and Reduce Motion have been tested.
- [ ] The Release archive installs and runs on supported physical devices.
- [ ] App Store Connect accepts the archive and metadata.
- [ ] App Review notes provide complete access and explain non-obvious features.
- [ ] The product owner has approved the final privacy policy, terms, claims, screenshots, and data model.

## Apple source checklist

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [App Privacy reference](https://developer.apple.com/help/app-store-connect/reference/app-privacy/)
- [Required, localizable, and editable App Store properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Add an app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon)
- [CloudKit private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)
- [Core Data with CloudKit setup](https://developer.apple.com/documentation/coredata/setting-up-core-data-with-cloudkit)
- [CloudKit user access](https://developer.apple.com/documentation/cloudkit/providing-user-access-to-cloudkit-data)
- [CloudKit deletion requests](https://developer.apple.com/documentation/cloudkit/responding-to-requests-to-delete-data)
- [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init%28model%3Atools%3Ainstructions%3A%29)
- [Improving the safety of generative model output](https://developer.apple.com/documentation/FoundationModels/improving-the-safety-of-generative-model-output)
- [HIG Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [HIG VoiceOver](https://developer.apple.com/design/human-interface-guidelines/voiceover)
- [HIG Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [HIG Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [HIG Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [HIG Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion)

