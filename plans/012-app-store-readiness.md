# App Store Readiness (iCloud v1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every code-side item in `advisor-plans/app-store-launch-readiness.md` for an iCloud (Option B) v1 launch that doesn't require a paid Apple Developer account.

**Architecture:** Small, independent changes layered on the existing MVVM design. `AppData` stays the only owner of persistence and gains `flushPendingChanges()`, `deleteAllLibraryData()` and `libraryExport()`. Two new helper enums own share-sheet files and presentation (`ExportFiles`, `ShareSheetPresenter`). `EntityIndexer` becomes a serialized, coalescing queue. A new `SettingsView` exposes iCloud status, export, deletion, the bundled privacy policy and support.

**Tech Stack:** Swift 6, SwiftUI, SwiftData + CloudKit, CoreSpotlight/AppIntents (iOS 26), XCTest.

## Global Constraints

- Deployment target stays **iOS 17.0**. Gate iOS 26-only APIs with `@available(iOS 26.0, *)` / `#available`. Never raise the target.
- Never read or write palettes/colors around `AppData`. Never hand-edit `project.pbxproj`; new files under `Palettes/` and `PalettesTests/` are auto-included (synchronized groups).
- **Keep** the CloudKit code path, `UIBackgroundModes → remote-notification`, and the commented-out entitlements in `Palettes/Palettes.entitlements` exactly as they are. Do not uncomment them (the free team can't sign them).
- Do **not** modify `Palettes/Views/Color/ColorsView.swift`, `Palettes/Views/Color/GenerateView.swift`, or `Palettes/Views/Components/Selection/MorphingCardGrid.swift` (they have unrelated uncommitted work on `dev`).
- No analytics, crash reporting, networking, or third-party SDKs.
- Logs must never contain user content (names, hexes, vibe text, prompts, model output). Log only error *type* names with `privacy: .public`.
- Support/privacy contact is the literal `support@example.com` (owner replaces it before submission). It appears only in `AppLinks.swift` and `PrivacyPolicy.md`.
- Build: `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination 'platform=iOS Simulator,id=208E09D6-6BE6-420F-87C7-C164BFE8F178'`
- Test: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination 'platform=iOS Simulator,id=208E09D6-6BE6-420F-87C7-C164BFE8F178' [-only-testing:PalettesTests/<Suite>]`
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Release configuration (privacy manifest, export compliance, camera string, warning)

**Files:**
- Create: `Palettes/PrivacyInfo.xcprivacy`
- Modify: `Palettes/AppInfo.plist`
- Modify: `Palettes/Views/Components/Generation/GenerationExperienceView.swift:186-191`

**Interfaces:** Consumes nothing. Produces nothing code-level.

- [ ] **Step 1: Confirm required-reason API usage.** Run `grep -rn "UserDefaults\|@AppStorage\|creationDate\|modificationDate\|systemUptime\|volumeAvailableCapacity\|activeInputModes" Palettes --include='*.swift'`. Expected: only UserDefaults/@AppStorage hits. If any file-timestamp, uptime or disk-space API appears, STOP and report it, because it needs its own manifest entry.

- [ ] **Step 2: Confirm camera images aren't saved.** Run `grep -rn "UIImageWriteToSavedPhotosAlbum\|PHPhotoLibrary\|PHAssetCreationRequest\|\.write(to" Palettes --include='*.swift'`. Expected: only the export writes in `ExportPaletteSheet.swift`. If a photo is written anywhere, STOP and report it, because the camera string below would then be false.

- [ ] **Step 3: Create `Palettes/PrivacyInfo.xcprivacy`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Replace `Palettes/AppInfo.plist`.** Keep `remote-notification`, reword the camera string, and add export compliance:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>NSCameraUsageDescription</key>
    <string>Palettes uses the camera to take a photo you can pick colors from. The photo is processed on your device and isn't saved or uploaded.</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 5: Fix the unused-result warning** in `GenerationExperienceView.swift` (the undo closure around line 189). Change the undo closure to:

```swift
        ToastManager.shared.show("Color removed", icon: "trash.fill") {
            _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                paletteColors.insert(removed, at: min(index, paletteColors.count))
            }
        }
```

If the compiler then warns differently, use whatever form yields zero warnings for this file, without changing behavior.

- [ ] **Step 6: Verify.** Run `plutil -lint Palettes/AppInfo.plist Palettes/PrivacyInfo.xcprivacy Palettes/Palettes.entitlements` and expect all three files to report OK. Then run the build command and expect `BUILD SUCCEEDED` with no warning from `GenerationExperienceView.swift`. Then confirm the manifest ships: `find ~/Library/Developer/Xcode/DerivedData -path '*Debug-iphonesimulator/Palettes.app/PrivacyInfo.xcprivacy' -newer Palettes/PrivacyInfo.xcprivacy` should print a path. Also check that `/usr/libexec/PlistBuddy -c 'Print ITSAppUsesNonExemptEncryption' <that .app>/Info.plist` prints `false`.

- [ ] **Step 7: Commit**

```bash
git add Palettes/PrivacyInfo.xcprivacy Palettes/AppInfo.plist Palettes/Views/Components/Generation/GenerationExperienceView.swift
git commit -m "chore: add privacy manifest, export compliance key, clearer camera rationale"
```

---

### Task 2: Export hardening (JSON/SVG escaping, safe temp files, shared share-sheet presenter, private logs)

**Files:**
- Create: `Palettes/Managers/ExportFiles.swift`
- Create: `Palettes/Managers/ShareSheetPresenter.swift`
- Modify: `Palettes/Managers/PaletteExporter.swift` (`xmlEscape`, `jsonEscape`, `jsonString`)
- Modify: `Palettes/Views/Components/ExportPaletteSheet.swift` (`shareCurrentFormat`, delete `presentShare`)
- Modify: `Palettes/Managers/PaletteGenerator.swift:190-193`
- Modify: `Palettes/App/MyApp.swift`
- Test: `PalettesTests/PaletteExporterTests.swift`, create `PalettesTests/ExportFilesTests.swift`

**Interfaces:**
- Produces: `enum ExportFiles { static var directory: URL; static func write(_ data: Data, baseName: String, ext: String) throws -> URL; static func remove(_ url: URL); static func removeAll() }`
- Produces: `@MainActor enum ShareSheetPresenter { static func present(items: [Any], cleanup: URL? = nil) }`

- [ ] **Step 1: Write the failing exporter tests.** Append to `PaletteExporterTests`:

```swift
    // MARK: - Escaping hardening

    func testJSONEscapesControlCharactersAndParsesStrictly() throws {
        let hostile = "Line\nBreak\t\"q\" \\ \r\u{01}"
        let palette = PaletteViewModel(
            name: "Hostile",
            colors: [.red, .blue],
            hexCodes: ["#FF0000", "#0000FF"],
            colorNames: [hostile, "Émoji 🎨"]
        )
        let output = PaletteExporter.export(palette, as: .json)
        let parsed = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: String]]
        )
        XCTAssertEqual(parsed[0]["name"], hostile)
        XCTAssertEqual(parsed[1]["name"], "Émoji 🎨")
        XCTAssertEqual(parsed[1]["hex"], "#0000FF")
    }

    func testSVGStripsInvalidXMLControlCharactersAndParses() {
        let palette = PaletteViewModel(
            name: "Hostile",
            colors: [.red],
            hexCodes: ["#FF0000"],
            colorNames: ["A<b>&\"c\"\u{01}\u{0B}"]
        )
        let output = PaletteExporter.export(palette, as: .svg)
        XCTAssertFalse(output.contains("\u{01}"))
        XCTAssertFalse(output.contains("\u{0B}"))
        let parser = XMLParser(data: Data(output.utf8))
        XCTAssertTrue(parser.parse(), "SVG must be well-formed XML: \(String(describing: parser.parserError))")
    }
```

- [ ] **Step 2: Run them to make sure they fail.** Run `... test -only-testing:PalettesTests/PaletteExporterTests`. Expect `testJSONEscapesControlCharactersAndParsesStrictly` to fail with a JSONSerialization error, and the SVG test to fail on the `\u{01}` assertion.

- [ ] **Step 3: Implement escaping** in `PaletteExporter.swift`. Replace `xmlEscape` and `jsonEscape` with:

```swift
    /// XML 1.0 forbids most C0 control characters even when escaped, so drop
    /// them (keeping tab/newline/CR) before entity-escaping markup characters.
    private static func xmlEscape(_ text: String) -> String {
        let allowed = String(String.UnicodeScalarView(text.unicodeScalars.filter {
            $0.value >= 0x20 || $0 == "\t" || $0 == "\n" || $0 == "\r"
        }))
        var result = allowed
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }

    /// Escapes through JSONEncoder so quotes, backslashes and every control
    /// character follow RFC 8259; the surrounding quotes are stripped because
    /// callers lay out the JSON themselves (keeping the one-object-per-line
    /// format the tests pin).
    private static func jsonEscape(_ text: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(text),
              let quoted = String(data: data, encoding: .utf8),
              quoted.count >= 2 else { return "" }
        return String(quoted.dropFirst().dropLast())
    }
```

In `jsonString`, also route the hex through the escaper. Change the line building each object to:

```swift
            lines.append("  { \"name\": \"\(jsonEscape(pair.displayName))\",\(roleField) \"hex\": \"\(jsonEscape(pair.hex))\" }\(comma)")
```

- [ ] **Step 4: Run the exporter suite.** Run the same `-only-testing:PalettesTests/PaletteExporterTests` command and expect every test to pass. The existing exact-string JSON tests must still pass, which shows the format is unchanged.

- [ ] **Step 5: Write the failing `ExportFilesTests`** (create `PalettesTests/ExportFilesTests.swift`):

```swift
//
//  ExportFilesTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ExportFilesTests: XCTestCase {

    override func tearDown() {
        ExportFiles.removeAll()
        super.tearDown()
    }

    func testWriteStaysInsideExportDirectory() throws {
        let url = try ExportFiles.write(Data("x".utf8), baseName: "../../etc/passwd", ext: "svg")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL,
                       ExportFiles.directory.standardizedFileURL)
        XCTAssertEqual(url.pathExtension, "svg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testUnsafeOrEmptyNameFallsBackToPalette() throws {
        let url = try ExportFiles.write(Data(), baseName: "/:..", ext: "pdf")
        XCTAssertEqual(url.lastPathComponent, "palette.pdf")
    }

    func testUnicodeNameIsKept() throws {
        let url = try ExportFiles.write(Data(), baseName: "café-noir", ext: "ase")
        XCTAssertEqual(url.lastPathComponent, "café-noir.ase")
    }

    func testRemoveAllDeletesEverything() throws {
        let url = try ExportFiles.write(Data("x".utf8), baseName: "a", ext: "json")
        ExportFiles.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
```

- [ ] **Step 6: Run it to make sure it fails.** Expect a compile failure: `cannot find 'ExportFiles' in scope`.

- [ ] **Step 7: Create `Palettes/Managers/ExportFiles.swift`:**

```swift
//
//  ExportFiles.swift
//  Palettes
//
//  Scratch space for files handed to the share sheet. Everything lives in one
//  app-owned temp subfolder so it can be swept after sharing and on launch
//  without touching anything else in tmp/.
//

import Foundation

enum ExportFiles {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    /// Writes `data` to `<directory>/<baseName>.<ext>`. `baseName` is reduced
    /// to letters, numbers, `-` and `_`, so a palette name can never escape
    /// `directory`; an empty result falls back to "palette".
    static func write(_ data: Data, baseName: String, ext: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safe = String(baseName.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        let url = directory
            .appendingPathComponent(safe.isEmpty ? "palette" : safe)
            .appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
```

- [ ] **Step 8: Run `ExportFilesTests`** (`-only-testing:PalettesTests/ExportFilesTests`) and expect all four tests to pass.

- [ ] **Step 9: Create `Palettes/Managers/ShareSheetPresenter.swift`.** It is moved out of `ExportPaletteSheet` so Settings can reuse it, and it gains cleanup:

```swift
//
//  ShareSheetPresenter.swift
//  Palettes
//
//  Presents UIActivityViewController from the top-most view controller (so it
//  works from inside sheets) and deletes a temp export once sharing finishes.
//

import UIKit

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any], cleanup: URL? = nil) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            if let cleanup { ExportFiles.remove(cleanup) }
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            if let cleanup { ExportFiles.remove(cleanup) }
            return
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        activityVC.popoverPresentationController?.sourceView = topVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.maxX - 50, y: 0, width: 1, height: 1)
        topVC.present(activityVC, animated: true)
    }
}
```

- [ ] **Step 10: Rewire `ExportPaletteSheet.shareCurrentFormat()`** and delete its private `presentShare(items:)`:

```swift
    private func shareCurrentFormat() {
        switch selectedFormat {
        case .svg:
            if let url = try? ExportFiles.write(Data(output.utf8), baseName: slugifiedPaletteName, ext: "svg") {
                ShareSheetPresenter.present(items: [url], cleanup: url)
            } else {
                ShareSheetPresenter.present(items: [output])
            }
        case .ase:
            // No text fallback for binary formats; nothing to share on failure.
            if let url = try? ExportFiles.write(PaletteExporter.aseData(palette), baseName: slugifiedPaletteName, ext: "ase") {
                ShareSheetPresenter.present(items: [url], cleanup: url)
            }
        case .pdf:
            if let url = try? ExportFiles.write(PaletteExporter.pdfData(palette), baseName: slugifiedPaletteName, ext: "pdf") {
                ShareSheetPresenter.present(items: [url], cleanup: url)
            }
        default:
            ShareSheetPresenter.present(items: [output])
        }
    }
```

Run `grep -rn "presentShare" Palettes`. Expected: no hits.

- [ ] **Step 11: Sweep stale exports on launch.** In `MyApp.swift`:

```swift
@main
struct MyApp: App {
    init() {
        // Exports are deleted after each share; this catches any left behind
        // by a crash or a kill mid-share.
        ExportFiles.removeAll()
    }

    var body: some Scene {
        WindowGroup {
           PaletteTabView()
                .toastOverlay()
        }
    }
}
```

- [ ] **Step 12: Sanitize the generation log** in `PaletteGenerator.swift` (the `catch` before `throw AppError.generationFailed`):

```swift
        } catch {
            // Type name only: the error's description can echo prompt or
            // model content, which must never reach device logs.
            Logger(subsystem: "com.halilbagosi.Palettes", category: "generation")
                .error("Palette generation failed: \(String(describing: type(of: error)), privacy: .public)")
            throw AppError.generationFailed
        }
```

Then run `grep -rn "privacy: .public" Palettes --include='*.swift'`. Every hit must interpolate only a type name or a constant. Report any hit that doesn't.

- [ ] **Step 13: Run the full test suite** and expect `TEST SUCCEEDED`.

- [ ] **Step 14: Commit**

```bash
git add Palettes/Managers/ExportFiles.swift Palettes/Managers/ShareSheetPresenter.swift Palettes/Managers/PaletteExporter.swift Palettes/Views/Components/ExportPaletteSheet.swift Palettes/Managers/PaletteGenerator.swift Palettes/App/MyApp.swift PalettesTests/PaletteExporterTests.swift PalettesTests/ExportFilesTests.swift
git commit -m "fix: harden export escaping, sandbox and clean temp exports, keep user content out of logs"
```

---

### Task 3: Serialized, coalescing Spotlight indexer

**Files:**
- Modify: `Palettes/Intents/EntityIndexer.swift` (full rewrite)
- Test: create `PalettesTests/EntityIndexerTests.swift`

**Interfaces:**
- Consumes: `PaletteEntity(_ palette: PaletteViewModel)`, `ColorEntity(_ color: ColorViewModel)` (both `@MainActor`, existing).
- Produces: `@available(iOS 26.0, *) enum EntityIndexer { @MainActor static func reindex(palettes: [PaletteEntity], colors: [ColorEntity]); @MainActor static func removeAll(); @MainActor static var isIdle: Bool; @MainActor static var applier: ([PaletteEntity], [ColorEntity]) async -> Void }`. `AppData`'s existing call site is unchanged.

- [ ] **Step 1: Write the failing test** (`PalettesTests/EntityIndexerTests.swift`):

```swift
//
//  EntityIndexerTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

@available(iOS 26.0, *)
@MainActor
final class EntityIndexerTests: XCTestCase {

    private var applied: [Int] = []
    private var originalApplier: (([PaletteEntity], [ColorEntity]) async -> Void)!

    override func setUp() async throws {
        originalApplier = EntityIndexer.applier
        applied = []
        EntityIndexer.applier = { [weak self] palettes, _ in
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run { self?.applied.append(palettes.count) }
        }
    }

    override func tearDown() async throws {
        await waitUntilIdle()
        EntityIndexer.applier = originalApplier
    }

    private func palettes(_ n: Int) -> [PaletteEntity] {
        (0..<n).map { PaletteEntity(id: UUID(), name: "P\($0)", hexCodes: ["#000000"]) }
    }

    private func waitUntilIdle() async {
        for _ in 0..<100 where !EntityIndexer.isIdle {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Rapid snapshots never overlap, intermediate ones are coalesced away,
    /// and the newest one is always applied last.
    func testRapidReindexesCoalesceAndApplyNewestLast() async {
        EntityIndexer.reindex(palettes: palettes(1), colors: [])
        // Let job 1 start (its applier sleeps 100 ms) before queuing more.
        try? await Task.sleep(for: .milliseconds(30))
        EntityIndexer.reindex(palettes: palettes(2), colors: [])
        EntityIndexer.reindex(palettes: palettes(3), colors: [])
        await waitUntilIdle()
        XCTAssertEqual(applied, [1, 3])
    }

    /// A delete-everything request queued behind an in-flight job wins: no
    /// older snapshot can re-add entities after it.
    func testRemoveAllAfterPendingSnapshotWins() async {
        EntityIndexer.reindex(palettes: palettes(5), colors: [])
        EntityIndexer.reindex(palettes: palettes(4), colors: [])
        EntityIndexer.removeAll()
        await waitUntilIdle()
        XCTAssertEqual(applied.last, 0)
    }
}
```

- [ ] **Step 2: Run it to make sure it fails** (`-only-testing:PalettesTests/EntityIndexerTests`). Expect a compile failure: no `applier` or `isIdle` on `EntityIndexer`.

- [ ] **Step 3: Rewrite `Palettes/Intents/EntityIndexer.swift`:**

```swift
//
//  EntityIndexer.swift
//  Palettes
//
//  Donates the library to Spotlight so Siri / Apple Intelligence can
//  semantically resolve palettes and colors by name.
//

import AppIntents
import CoreSpotlight
import Foundation
import os

@available(iOS 26.0, *)
enum EntityIndexer {
    /// Newest snapshot waiting to be applied; replaced (coalesced) by each
    /// `reindex` call while a job is running.
    @MainActor private static var pending: (palettes: [PaletteEntity], colors: [ColorEntity])?
    @MainActor private static var worker: Task<Void, Never>?

    /// Performs one replace-all pass. A seam so tests can observe ordering
    /// without touching the real Spotlight index.
    @MainActor static var applier: ([PaletteEntity], [ColorEntity]) async -> Void = applyToSpotlight

    @MainActor static var isIdle: Bool { worker == nil }

    /// Replaces the app's Spotlight entities with this snapshot. Jobs run one
    /// at a time and only the newest pending snapshot is applied next, so an
    /// older snapshot can never land after a newer one (e.g. re-adding a
    /// palette the user just deleted).
    @MainActor
    static func reindex(palettes: [PaletteEntity], colors: [ColorEntity]) {
        pending = (palettes, colors)
        guard worker == nil else { return }
        worker = Task { @MainActor in
            while let next = pending {
                pending = nil
                await applier(next.palettes, next.colors)
            }
            worker = nil
        }
    }

    /// Removes every palette and color entity (used by "Delete All Data").
    @MainActor
    static func removeAll() {
        reindex(palettes: [], colors: [])
    }

    private static func applyToSpotlight(_ palettes: [PaletteEntity], _ colors: [ColorEntity]) async {
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAppEntities(ofType: PaletteEntity.self)
            try await index.deleteAppEntities(ofType: ColorEntity.self)
            if !palettes.isEmpty { try await index.indexAppEntities(palettes) }
            if !colors.isEmpty { try await index.indexAppEntities(colors) }
        } catch {
            // Non-fatal: the next library change retries. Type name only, so
            // no palette or color names reach the log.
            Logger(subsystem: "com.halilbagosi.Palettes", category: "spotlight")
                .error("Spotlight reindex failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
```

If strict concurrency rejects `applier` holding `applyToSpotlight` (a nonisolated function), annotate `applyToSpotlight` with `@MainActor`. Its awaits suspend, so it doesn't block the main thread.

- [ ] **Step 4: Run `EntityIndexerTests`** and expect both tests to pass. Then run the build and confirm the `AppData` call site compiles unchanged.

- [ ] **Step 5: Commit**

```bash
git add Palettes/Intents/EntityIndexer.swift PalettesTests/EntityIndexerTests.swift
git commit -m "fix: serialize and coalesce Spotlight reindexing so deletes can't be undone by stale snapshots"
```

---

### Task 4: AppData data lifecycle (no sample data, background flush, delete-all, library export)

> Product decision (2026-10-07): the app ships with **no sample data**. First launch starts with an empty library, and a future onboarding flow will create the user's first palette. This task removes seeding.

**Files:**
- Create: `Palettes/Managers/LibraryExport.swift`
- Modify: `Palettes/App/AppData.swift` (init observers, `load()` untouched, new methods after the Intent API section, sample-data section)
- Test: create `PalettesTests/AppDataLifecycleTests.swift`

**Interfaces:**
- Consumes: `ExportFiles.removeAll()` (Task 2), `EntityIndexer.removeAll()` (Task 3).
- Produces:
  - `AppData.flushPendingChanges()`
  - `@discardableResult AppData.deleteAllLibraryData() -> Bool`
  - `AppData.libraryExport(now: Date = .now) -> LibraryExport`
  - `struct LibraryExport: Codable, Equatable { formatVersion: Int; exportedAt: Date; colors: [LibraryExport.Color]; palettes: [LibraryExport.Palette]; customTags: [String]; func jsonData() throws -> Data; static func decode(_ data: Data) throws -> LibraryExport }`
  - `AppData.recentSearchesKey = "recentSearches"` (static let)

- [ ] **Step 1: Write the failing tests** (`PalettesTests/AppDataLifecycleTests.swift`):

```swift
//
//  AppDataLifecycleTests.swift
//  PalettesTests
//

import XCTest
import SwiftData
@testable import Palettes

@MainActor
final class AppDataLifecycleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "didSeedSampleData")
        UserDefaults.standard.removeObject(forKey: AppData.recentSearchesKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "didSeedSampleData")
        UserDefaults.standard.removeObject(forKey: AppData.recentSearchesKey)
        super.tearDown()
    }

    /// No sample data: a fresh install starts empty (onboarding creates the
    /// first palette later), and nothing is written to the store.
    func testFirstLaunchStartsEmpty() throws {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.colors.isEmpty)
        XCTAssertTrue(appData.palettes.isEmpty)
        XCTAssertTrue(appData.customTags.isEmpty)
        let context = try XCTUnwrap(appData.testContext)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredPalette>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredColor>()), 0)
    }

    func testFlushPersistsEditBeforeDebounce() throws {
        let appData = AppData(inMemory: true)
        let added = ColorViewModel(name: "Flush Me", color: .red, HEX: "#FF0002", usedInPalette: false)
        appData.colors.append(added)
        appData.flushPendingChanges()
        let stored = try XCTUnwrap(appData.testContext).fetch(FetchDescriptor<StoredColor>())
        XCTAssertTrue(stored.contains { $0.id == added.id })
    }

    func testDeleteAllRemovesEverythingIncludingUnknownRemoteRecords() throws {
        let appData = AppData(inMemory: true)
        _ = appData.addCustomTag("Brand")
        appData.flushPendingChanges()
        // Simulate a record imported from another device that AppData hasn't loaded yet.
        let context = try XCTUnwrap(appData.testContext)
        context.insert(StoredPalette(id: UUID(), name: "Remote", hexCodes: ["#123456"], colorNames: ["X"], sortIndex: 99))
        try context.save()
        UserDefaults.standard.set("[\"blue\"]", forKey: AppData.recentSearchesKey)

        XCTAssertTrue(appData.deleteAllLibraryData())

        XCTAssertTrue(appData.colors.isEmpty)
        XCTAssertTrue(appData.palettes.isEmpty)
        XCTAssertTrue(appData.customTags.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredColor>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredPalette>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredTag>()), 0)
        XCTAssertNil(UserDefaults.standard.string(forKey: AppData.recentSearchesKey))
    }

    func testDeleteAllStaysEmptyAfterDebounceWindow() async throws {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.deleteAllLibraryData())
        try await Task.sleep(for: .seconds(1))
        let context = try XCTUnwrap(appData.testContext)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredPalette>()), 0)
        XCTAssertTrue(appData.palettes.isEmpty)
    }

    func testLibraryExportRoundTripsAllUserData() throws {
        let appData = AppData(inMemory: true)
        appData.addColor(name: "Ocean", hex: "#0077BE")
        appData.addPalette(name: "Coast", paletteColors: [
            PaletteColor(color: .blue, hex: "#0077BE", name: "Ocean"),
            PaletteColor(color: .yellow, hex: "#C2B280", name: "Sand"),
        ])
        _ = appData.addCustomTag("Brand")
        appData.palettes[0].paletteColors[0].role = "Brand"
        appData.palettes[0].isFavorite = true
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let export = appData.libraryExport(now: date)
        let decoded = try LibraryExport.decode(export.jsonData())

        XCTAssertEqual(decoded, export)
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.colors.count, appData.colors.count)
        XCTAssertEqual(decoded.palettes.count, appData.palettes.count)
        XCTAssertEqual(decoded.customTags, ["Brand"])
        XCTAssertEqual(decoded.palettes[0].colors[0].role, "Brand")
        XCTAssertTrue(decoded.palettes[0].isFavorite)
        XCTAssertEqual(decoded.palettes[0].id, appData.palettes[0].id)
    }
}
```

- [ ] **Step 2: Run it to make sure it fails** (`-only-testing:PalettesTests/AppDataLifecycleTests`). Expect a compile failure on the missing members.

- [ ] **Step 3: Create `Palettes/Managers/LibraryExport.swift`:**

```swift
//
//  LibraryExport.swift
//  Palettes
//
//  Whole-library export ("Export Library" in Settings): every user-created
//  color, palette (with names, roles, favorites) and custom tag. Archival
//  JSON — there is no importer yet; `formatVersion` leaves room for one.
//

import Foundation

struct LibraryExport: Codable, Equatable {
    struct Color: Codable, Equatable {
        var id: UUID
        var name: String
        var hex: String
        var isFavorite: Bool
        var isGenerated: Bool
    }

    struct Swatch: Codable, Equatable {
        var name: String
        var hex: String
        var role: String?
    }

    struct Palette: Codable, Equatable {
        var id: UUID
        var name: String
        var isFavorite: Bool
        var isGenerated: Bool
        var colors: [Swatch]
    }

    var formatVersion = 1
    var exportedAt: Date
    var colors: [Color]
    var palettes: [Palette]
    var customTags: [String]

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> LibraryExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LibraryExport.self, from: data)
    }
}
```

`exportedAt` round-trips exactly because the test uses a whole-second date.

- [ ] **Step 4: Remove sample data.** In `AppData.swift`:
  1. Delete the whole `// MARK: - Sample Data (first launch only)` section (`sampleColors`, `samplePalettes`).
  2. In `load()`'s `guard let context = container?.mainContext else { ... }` branch, replace the sample assignment with `colors = []` and `palettes = []`.
  3. Replace the `let didSeed = ...` / `if storedColors.isEmpty && storedPalettes.isEmpty && !didSeed { ... } else { ... }` block with only the body of its `else` branch (the dedupe-and-map code), un-nested. An empty store now simply loads as an empty library.
  4. Add a one-time cleanup of the obsolete flag in `init` before `load()`: `UserDefaults.standard.removeObject(forKey: "didSeedSampleData")`.
  5. Run `grep -rn "sample\|didSeed" Palettes --include='*.swift'`. Expected: only the cleanup line from item 4 (plus unrelated pixel-"sample" hits in the photo picker or extractor).

- [ ] **Step 4b: Fix tests that relied on seeded data.** In `PalettesTests/AppDataPersistenceTests.swift`:
  - Replace `testFirstLaunchSeedsSampleColorsAndPalettes` with nothing. It's superseded by `AppDataLifecycleTests.testFirstLaunchStartsEmpty`.
  - Remove the `didSeedSampleData` lines from `setUp`/`tearDown`.
  - Any test that reads `appData.palettes[i]`/`appData.colors[i]` or assumes a non-empty library must first add what it needs through `appData.addColor(name:hex:)` / `appData.addPalette(name:paletteColors:)`. Do the same in `AppDataIntentAPITests` and any other suite that fails after removing the seed. Run the full suite to find them all, and don't weaken assertions to make tests pass.

- [ ] **Step 5: Flush on background.** In `init`, directly after the existing `willEnterForegroundNotification` subscription, add:

```swift
        // Write edits still inside the 300 ms debounce before the app can be
        // suspended or killed.
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.flushPendingChanges() }
            .store(in: &cancellables)
```

- [ ] **Step 6: Add the lifecycle API** as a new section after `addColor(name:hex:)`:

```swift
    // MARK: - Data lifecycle

    static let recentSearchesKey = "recentSearches"

    /// Persists any edits still waiting on the debounce. Safe to call any
    /// time: each persist is an idempotent upsert.
    func flushPendingChanges() {
        if isDirtyColors { persistColors(colors) }
        if isDirtyPalettes { persistPalettes(palettes) }
        if isDirtyTags { persistTags(customTags) }
    }

    /// Deletes every color, palette and custom tag (with CloudKit on, the
    /// deletions sync to the user's other devices), plus recent searches,
    /// Spotlight/Siri entities, and leftover temp exports. Objects are
    /// deleted one by one rather than batch-deleted so
    /// CloudKit mirroring sees each deletion. Returns false (library left as
    /// it was) if the store can't be saved.
    @discardableResult
    func deleteAllLibraryData() -> Bool {
        if let context = container?.mainContext {
            do {
                for item in try context.fetch(FetchDescriptor<StoredColor>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<StoredPalette>()) { context.delete(item) }
                for item in try context.fetch(FetchDescriptor<StoredTag>()) { context.delete(item) }
                try context.save()
            } catch {
                context.rollback()
                ToastManager.shared.show("Couldn't delete your data.", icon: "exclamationmark.triangle.fill")
                return false
            }
        }

        lastPersistedColorIDs = []
        lastPersistedPaletteIDs = []
        lastPersistedTagNames = []
        colors = []
        palettes = []
        customTags = []
        isDirtyColors = false
        isDirtyPalettes = false
        isDirtyTags = false

        UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
        ExportFiles.removeAll()
        if #available(iOS 26.0, *) {
            EntityIndexer.removeAll()
        }
        return true
    }

    /// Snapshot of the whole library for "Export Library".
    func libraryExport(now: Date = .now) -> LibraryExport {
        LibraryExport(
            exportedAt: now,
            colors: colors.map {
                LibraryExport.Color(id: $0.id, name: $0.name, hex: $0.HEX,
                                    isFavorite: $0.isFavorite, isGenerated: $0.isGenerated)
            },
            palettes: palettes.map { palette in
                LibraryExport.Palette(
                    id: palette.id,
                    name: palette.name,
                    isFavorite: palette.isFavorite,
                    isGenerated: palette.isGenerated,
                    colors: palette.paletteColors.map {
                        LibraryExport.Swatch(name: $0.name, hex: $0.hex, role: $0.role)
                    }
                )
            },
            customTags: customTags
        )
    }
```

The arrays are set to `[]` *after* the flags are cleared, and the sinks then mark them dirty again. That is intended: the debounced persist of `[]` finds an empty store and returns at the `hasChanges` guard.

- [ ] **Step 7: Use the shared key in `SearchView`.** Change line 16 to `@AppStorage(AppData.recentSearchesKey) private var recentSearchesJSON: String = "[]"`.

- [ ] **Step 8: Run `AppDataLifecycleTests`, then the full suite.** Expect everything to pass, with `testFirstLaunchSeedsSampleColorsAndPalettes` removed per Step 4b.

- [ ] **Step 9: Commit**

```bash
git add Palettes/Managers/LibraryExport.swift Palettes/App/AppData.swift Palettes/Views/Main/SearchView.swift PalettesTests/AppDataLifecycleTests.swift
git commit -m "feat: drop sample data, add delete-all and library export, flush on background"
```

---

### Task 5: Settings screen with privacy policy, support, iCloud status, export and delete-all

**Files:**
- Create: `Palettes/App/AppLinks.swift`
- Create: `Palettes/Resources/PrivacyPolicy.md`
- Create: `Palettes/Views/Settings/SettingsView.swift`
- Create: `Palettes/Views/Settings/PrivacyPolicyView.swift`
- Modify: `Palettes/Views/Palette/PaletteView.swift` (state, sheet, toolbar)
- Test: create `PalettesTests/PrivacyPolicyTests.swift`

**Interfaces:**
- Consumes: `AppData.libraryExport()`, `AppData.deleteAllLibraryData()`, `LibraryExport.jsonData()` (Task 4); `ExportFiles.write`, `ShareSheetPresenter.present` (Task 2).
- Produces: `enum AppLinks { static let supportEmail: String; static var supportEmailURL: URL; static let termsOfUse: URL }`. A future subscription paywall reuses `PrivacyPolicyView` and `AppLinks.termsOfUse` for its required legal links, and adds a "Subscription" section (Manage / Restore Purchases) to `SettingsView`., `enum PrivacyPolicy { static func load(bundle: Bundle = .main) -> String?; static func blocks(from markdown: String) -> [PrivacyPolicy.Block] }`, `SettingsView`, `PrivacyPolicyView`.

- [ ] **Step 1: Write the failing test** (`PalettesTests/PrivacyPolicyTests.swift`):

```swift
//
//  PrivacyPolicyTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class PrivacyPolicyTests: XCTestCase {

    func testPolicyShipsInAppBundle() throws {
        let text = try XCTUnwrap(PrivacyPolicy.load(), "PrivacyPolicy.md must be a bundle resource")
        XCTAssertTrue(text.contains("iCloud"))
        XCTAssertTrue(text.contains(AppLinks.supportEmail), "policy and Settings must show the same contact")
    }

    func testBlocksSplitHeadingsAndParagraphs() {
        let blocks = PrivacyPolicy.blocks(from: "# Title\n\nIntro line.\n\n## Section\n\nBody **bold**.\n- item")
        XCTAssertEqual(blocks, [
            .heading("Title", level: 1),
            .paragraph("Intro line."),
            .heading("Section", level: 2),
            .paragraph("Body **bold**.\n- item"),
        ])
    }
}
```

- [ ] **Step 2: Run it to make sure it fails** (`-only-testing:PalettesTests/PrivacyPolicyTests`). Expect a compile failure.

- [ ] **Step 3: Create `Palettes/App/AppLinks.swift`:**

```swift
//
//  AppLinks.swift
//  Palettes
//
//  Public contact details. `supportEmail` must match PrivacyPolicy.md and the
//  App Store Connect support/privacy contact.
//

import Foundation

enum AppLinks {
    // TODO(owner): replace with the dedicated support address before submission
    // (also in Palettes/Resources/PrivacyPolicy.md).
    static let supportEmail = "support@example.com"

    static var supportEmailURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    /// Apple's standard EULA. Subscriptions (planned) must link Terms of Use
    /// in-app; swap for a custom EULA URL if one is published.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
```

- [ ] **Step 4: Create `Palettes/Resources/PrivacyPolicy.md`.** This is the factual draft and needs owner/legal review. The same text gets hosted at the App Store Connect privacy URL.

```markdown
# Privacy Policy

Effective October 6, 2026 · Version 1.0

Palettes is made by Halil Bagosi. This policy explains what happens to your information when you use the Palettes app. The short version: the developer doesn't collect, see, sell, or share any of your data.

## What we collect

Nothing. Palettes has no accounts, no analytics, no advertising, and no tracking, and it doesn't send your data to the developer or to any third party.

## Your library and iCloud

Your colors, palettes, color names, roles, favorites, and custom tags are stored on your device. If you're signed in to iCloud, Palettes uses Apple's CloudKit to keep your library in sync in your **private iCloud database**, so it appears on your other devices signed in to the same Apple Account. That data is stored by Apple under your iCloud account and Apple's privacy policy, and the developer can't access it. If you aren't signed in to iCloud, your library stays only on this device.

## Camera and photos

When you pick colors from a photo, the camera image or the photo you choose is processed on your device to find colors. It isn't saved by Palettes, and it isn't uploaded anywhere. Palettes only asks for camera access when you choose to take a photo, and you can turn it off at any time in Settings › Privacy & Security › Camera.

## Palette generation with Apple Intelligence

On devices that support Apple Intelligence, Palettes can generate palettes with Apple's on-device Foundation Models. The text you type to describe a palette, along with any colors and color names you choose as a starting point, is given to that model to create the palette. Photos are never given to the model. Palettes doesn't send this information to the developer or any other service.

## Siri, Spotlight, and Shortcuts

So you can find them with Siri, Spotlight, and Shortcuts, the names and colors of your palettes and colors are added to your device's on-device search index. They're removed when you delete those items or delete all data.

## Other information on your device

Palettes remembers your last few searches on this device to show them as suggestions. When you tap a copy button, the color value is placed on the system clipboard. Palettes never reads your clipboard. When you export or share, the file goes only where you choose to send it.

## Deleting your data

You can delete an item at any time. To delete everything, go to Settings in Palettes (the gear on the Palettes tab) and tap **Delete All Data**. This removes every color, palette, and tag, your recent searches, and the Siri and Spotlight entries. If iCloud sync is on, the deletion also syncs to your private iCloud database and your other devices. Deleting the app removes the data stored on that device. Copies inside device or iCloud backups are managed by Apple and expire according to those backups.

You can download a copy of your whole library at any time with **Export Library** in Settings.

## Children

Palettes doesn't collect personal information from anyone, including children.

## Changes to this policy

If this policy changes, the new version will be published at the same address with a new effective date, and the in-app copy will be updated.

## Contact

Questions or requests: support@example.com
```

- [ ] **Step 5: Create `Palettes/Views/Settings/PrivacyPolicyView.swift`:**

```swift
//
//  PrivacyPolicyView.swift
//  Palettes
//
//  Renders the bundled PrivacyPolicy.md so the policy is reachable in-app
//  even offline. Block-level parsing is limited to what the policy uses:
//  `#`/`##` headings and blank-line-separated paragraphs (inline markdown
//  such as **bold** is rendered by Text).
//

import SwiftUI

enum PrivacyPolicy {
    enum Block: Equatable, Hashable {
        case heading(String, level: Int)
        case paragraph(String)
    }

    static func load(bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: "PrivacyPolicy", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func blocks(from markdown: String) -> [Block] {
        markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { chunk in
                if chunk.hasPrefix("## ") { return .heading(String(chunk.dropFirst(3)), level: 2) }
                if chunk.hasPrefix("# ") { return .heading(String(chunk.dropFirst(2)), level: 1) }
                return .paragraph(chunk)
            }
    }
}

struct PrivacyPolicyView: View {
    private let blocks = PrivacyPolicy.blocks(from: PrivacyPolicy.load() ?? "")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if blocks.isEmpty {
                    Text("The privacy policy couldn't be loaded. Contact \(AppLinks.supportEmail).")
                }
                ForEach(blocks, id: \.self) { block in
                    switch block {
                    case .heading(let text, let level):
                        Text(text)
                            .font(level == 1 ? .title2.bold() : .headline)
                            .padding(.top, level == 1 ? 0 : 6)
                            .accessibilityAddTraits(.isHeader)
                    case .paragraph(let text):
                        Text((try? AttributedString(
                            markdown: text,
                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                        )) ?? AttributedString(text))
                        .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 6: Run `PrivacyPolicyTests`.** Expect both tests to pass. If `testPolicyShipsInAppBundle` fails because the `.md` file wasn't copied into the app bundle, check `find ~/Library/Developer/Xcode/DerivedData -name PrivacyPolicy.md -path '*Palettes.app*'`. If nothing is found, STOP and report it rather than editing the pbxproj.

- [ ] **Step 7: Create `Palettes/Views/Settings/SettingsView.swift`:**

```swift
//
//  SettingsView.swift
//  Palettes
//
//  iCloud status, library export/deletion, privacy policy, and support.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appData: AppData
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showExportError = false

    private var isSignedInToICloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("iCloud", value: isSignedInToICloud ? "Signed In" : "Not Signed In")
                } header: {
                    Text("Sync")
                } footer: {
                    Text(isSignedInToICloud
                         ? "Your library syncs privately through your iCloud account to your other devices."
                         : "Sign in to iCloud in the Settings app to sync your library across devices. Until then, it's stored only on this device.")
                }

                Section {
                    Button {
                        exportLibrary()
                    } label: {
                        Label("Export Library", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("Export saves every color, palette, and tag as a JSON file.")
                }

                Section("About") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.termsOfUse) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    Link(destination: AppLinks.supportEmailURL) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    LabeledContent("Version", value: versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) { deleteAll() }
            } message: {
                Text("This permanently deletes every color, palette, and tag, your recent searches, and Siri and Spotlight suggestions. If iCloud sync is on, they're also removed from your other devices. This can't be undone.")
            }
            .alert("Couldn't export your library.", isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func exportLibrary() {
        do {
            let data = try appData.libraryExport().jsonData()
            let url = try ExportFiles.write(data, baseName: "palettes-library", ext: "json")
            ShareSheetPresenter.present(items: [url], cleanup: url)
        } catch {
            showExportError = true
        }
    }

    private func deleteAll() {
        if appData.deleteAllLibraryData() {
            dismiss()
            ToastManager.shared.show("All data deleted", icon: "trash.fill")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData(inMemory: true))
}
```

- [ ] **Step 8: Add the entry point in `PaletteView.swift`.**
  1. Next to the other `@State`s add `@State private var showSettings = false`.
  2. After the `.sheet(item: $paletteToExport) { ... }` modifier chain entry, add:

```swift
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environmentObject(appData)
                }
```

  3. In `toolbarContent`, make the gear available even when the library is empty, because after "Delete All Data" the `!appData.palettes.isEmpty` branch hides everything else. Wrap the existing body and add a leading gear when not selecting:

```swift
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        if !appData.palettes.isEmpty {
            // ... existing content unchanged ...
        }
    }
```

  Leave the existing `if isSelecting { ... } else { ... }` block inside `if !appData.palettes.isEmpty` exactly as it is.

- [ ] **Step 9: Build and run the full suite.** Expect `BUILD SUCCEEDED` and `TEST SUCCEEDED`.

- [ ] **Step 10: Simulator smoke check.** Launch the app on the simulator id above and open Palettes tab → gear. Verify that Settings shows the Sync, Your Data and About sections, that Privacy Policy renders headings and paragraphs, and that Export Library shows a share sheet with `palettes-library.json`. Then Delete All Data → confirm: the library should be empty, the gear still visible, and after relaunch the library should still be empty with no sample reseed. Report what you observed.

- [ ] **Step 11: Commit**

```bash
git add Palettes/App/AppLinks.swift Palettes/Resources/PrivacyPolicy.md Palettes/Views/Settings Palettes/Views/Palette/PaletteView.swift PalettesTests/PrivacyPolicyTests.swift
git commit -m "feat: add Settings with in-app privacy policy, support, iCloud status, export and delete-all"
```

---

### Task 6: Accessibility pass (labels, sliders, photo picker, hit regions, Reduce Motion)

**Files:**
- Modify: `Palettes/Views/Components/Selection/SelectionBottomBar.swift`
- Modify: `Palettes/Views/Palette/PaletteView.swift` (selection-mode `xmark` button)
- Modify: `Palettes/Views/Components/AdjustmentSlider.swift`
- Modify: `Palettes/Views/Components/PhotoColorPickerView.swift`
- Modify: `Palettes/Views/Components/Cells/ColorCellBig.swift` (`copyButton`)
- Modify: `Palettes/Views/Components/Cells/PaletteCell.swift` (`copyButton`)
- Modify: `Palettes/Managers/ToastManager.swift`

**Interfaces:** Consumes and produces nothing new. `SelectionBottomBar`'s public init is unchanged.

- [ ] **Step 1: Selection bar labels.** In `SelectionBottomBar.body`, add after each button's `.disabled(count == 0)`:
  - trash: `.accessibilityLabel(count == 1 ? "Delete 1 item" : "Delete \(count) items")`
  - share: `.accessibilityLabel(count == 1 ? "Share 1 item" : "Share \(count) items")`
  - star: `.accessibilityLabel(favoriteFilled ? "Remove from Favorites" : "Add to Favorites")`

- [ ] **Step 2: Close buttons.** In `PaletteView.toolbarContent`, add `.accessibilityLabel("Done Selecting")` to the `Button { exitSelection() } label: { Image(systemName: "xmark") }`. In `PhotoColorPickerView`, add `.accessibilityLabel("Cancel")` to the cancellation `xmark` button. Then run `grep -rn 'Image(systemName: "xmark")' Palettes --include='*.swift'` and list any other unlabeled icon-only buttons you find (outside the three excluded files) in your report. Fix them the same way if the label is obvious.

- [ ] **Step 3: `AdjustmentSlider`.** Replace the `Slider(value: $value).tint(.accentColor)` line with:

```swift
            Slider(value: $value)
                .tint(.accentColor)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel)
                .accessibilityHint("Adjusts from \(leftLabel) to \(rightLabel)")
```

  Also add `.accessibilityHidden(true)` to the `HStack` holding `leftLabel`/`rightLabel` and to the `Text(valueLabel)` so VoiceOver doesn't read them twice.

- [ ] **Step 4: Accessible photo sampling.** In `PhotoColorPickerView`:
  1. On the `Image(uiImage: image)` view add:

```swift
                        .accessibilityLabel("Photo")
                        .accessibilityHint("Drag to pick a color. Or use the actions to pick the center or the suggested color.")
                        .accessibilityAction(named: "Pick Color at Center") {
                            sample(at: CGPoint(x: rect.midX, y: rect.midY), in: rect)
                            currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                        }
```

  2. If `initialRGB` is non-nil, also add a named action "Use Suggested Color" that sets `currentRGB = seed`, `hasSample = true`, `marker = nil` and updates `currentName`. Write it as `.accessibilityActions { if let seed = initialRGB { Button("Use Suggested Color") { ... } } }`, since conditional named actions need that form.
  3. On `previewPanel`, add `.accessibilityElement(children: .combine)` and `.accessibilityLabel(hasSample ? "Selected color \(currentName.isEmpty ? currentHex : currentName), \(currentHex)" : "No color selected")`.

- [ ] **Step 5: 44 pt hit regions.** In both `ColorCellBig.copyButton` and `PaletteCell.copyButton`, keep the 38 pt glass circle but give the button a 44 pt tappable label. In `ColorCellBig`:

```swift
    private var copyButton: some View {
        Button {
            copyToClipboard(hexCode, label: "Copied HEX")
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .frame(width: 38, height: 38)
                .liquidGlass(.interactive, in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy HEX")
    }
```

  In `PaletteCell` the change is identical, but the button calls `Button(action: action)`. Check in the simulator that the cell layout doesn't shift visibly. If the extra 6 pt changes row height, add `.padding(-3)` after `.contentShape(Circle())` to keep the outer layout size at 38 pt while the hit area stays 44 pt.

- [ ] **Step 6: Reduce Motion.**
  1. `ToastManager.show` / `performUndo`: wrap each `withAnimation(...)` animation argument as `UIAccessibility.isReduceMotionEnabled ? .easeInOut(duration: 0.2) : <existing animation>`.
  2. `ToastOverlay`: add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` and use `.transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))`.
  3. `PhotoColorPickerView.colorBubble`: add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to the view. When `reduceMotion` is true, use `x: 1, y: 1` for `scaleEffect` and `nil` for the `.animation(...)`.

- [ ] **Step 7: Build and run the full suite.** Expect `BUILD SUCCEEDED` and `TEST SUCCEEDED`.

- [ ] **Step 8: Accessibility Inspector spot-check** on the simulator (Xcode → Open Developer Tool → Accessibility Inspector, or `read_page`-style inspection if you have it). Check that the selection bar buttons, the Settings gear, the copy buttons and the photo picker all announce labels. Report the results, and record anything you couldn't check as a manual item.

- [ ] **Step 9: Commit**

```bash
git add Palettes/Views/Components/Selection/SelectionBottomBar.swift Palettes/Views/Palette/PaletteView.swift Palettes/Views/Components/AdjustmentSlider.swift Palettes/Views/Components/PhotoColorPickerView.swift Palettes/Views/Components/Cells/ColorCellBig.swift Palettes/Views/Components/Cells/PaletteCell.swift Palettes/Managers/ToastManager.swift
git commit -m "feat: accessibility labels, slider values, accessible photo sampling, 44pt copy targets, Reduce Motion"
```

---

## Out of scope for this plan (owner / later)

- Restoring iCloud + APNs entitlements (`aps-environment` = `production` for Release), CloudKit production schema deploy, archive/validation/TestFlight, and the two-device CloudKit matrix. All of these are **blocked on the paid Apple Developer Program**.
- 1024×1024 app icon artwork.
- Hosting `PrivacyPolicy.md` at a public HTTPS URL, replacing `support@example.com`, and legal review.
- App Store Connect metadata, screenshots, App Privacy answers, age rating, and review notes (drafted separately in `advisor-plans/app-store-submission-notes.md`).
- Dynamic Type sweep, Liquid Glass placement review, and full VoiceOver device pass (P2-05, P2-06, P2-08). These are manual device checks.
- Subscription paywall (StoreKit 2) is separate work. When it lands, it needs the 3.1.2 requirements: price and period on the paywall, Restore Purchases, in-paywall Privacy Policy and Terms links, a Manage/Restore section in Settings, a Purchases paragraph in `PrivacyPolicy.md`, and the Terms of Use link in App Store metadata.
- Settings gear on the Colors tab (blocked by uncommitted `ColorsView` work; add it after that lands).
- Accessibility fixes in `ColorsView`, `GenerateView` and `MorphingCardGrid` (blocked by uncommitted work on `dev`).
