import Testing
import SwiftUI
import SwiftData
@testable import Palettes

@MainActor
struct AppDataIntentAPITests {
    @Test func addPaletteAppendsAndReturnsModel() {
        let data = AppData(inMemory: true)
        let before = data.palettes.count
        let colors = [PaletteColor(color: .red, hex: "#FF0000", name: "Red")]
        let created = data.addPalette(name: "Test Reds", paletteColors: colors)
        #expect(data.palettes.count == before + 1)
        #expect(data.palettes.last?.id == created.id)
        #expect(created.name == "Test Reds")
        #expect(created.hexCodes == ["#FF0000"])
    }

    @Test func addColorAppendsAndReturnsModel() {
        let data = AppData(inMemory: true)
        let before = data.colors.count
        let created = data.addColor(name: "Crimson", hex: "#DC143C")
        #expect(data.colors.count == before + 1)
        #expect(data.colors.last?.id == created.id)
        #expect(created.HEX == "#DC143C")
        #expect(created.usedInPalette == false)
    }

    /// Headless Siri/Shortcuts invocations can have the process suspended
    /// right after `perform()` returns, before the 300 ms debounced sink
    /// would fire. `addPalette`/`addColor` must persist synchronously so the
    /// record exists in the store immediately, with no debounce wait.
    @Test func addPalettePersistsSynchronously() throws {
        let data = AppData(inMemory: true)
        let colors = [PaletteColor(color: .blue, hex: "#0000FF", name: "Blue")]
        let created = data.addPalette(name: "Instant Blues", paletteColors: colors)

        let context = try #require(data.testContext)
        let createdID = created.id
        let descriptor = FetchDescriptor<StoredPalette>(
            predicate: #Predicate { $0.id == createdID }
        )
        let stored = try context.fetch(descriptor)
        #expect(stored.count == 1)
        #expect(stored.first?.name == "Instant Blues")
    }

    @Test func addColorPersistsSynchronously() throws {
        let data = AppData(inMemory: true)
        let created = data.addColor(name: "Instant Crimson", hex: "#DC143C")

        let context = try #require(data.testContext)
        let createdID = created.id
        let descriptor = FetchDescriptor<StoredColor>(
            predicate: #Predicate { $0.id == createdID }
        )
        let stored = try context.fetch(descriptor)
        #expect(stored.count == 1)
        #expect(stored.first?.hex == "#DC143C")
    }
}

@MainActor
struct IntentReadinessTests {
    @available(iOS 26.0, *)
    @Test func availabilityMapsToDistinctErrors() {
        #expect(PalettesIntentError.error(for: .available) == nil)
        #expect(PalettesIntentError.error(for: .unavailable(.appleIntelligenceNotEnabled)) == .aiDisabled)
        #expect(PalettesIntentError.error(for: .unavailable(.modelNotReady)) == .aiModelDownloading)
        #expect(PalettesIntentError.error(for: .unavailable(.deviceNotEligible)) == .aiDeviceIneligible)
    }

    @available(iOS 26.0, *)
    @Test func errorMessagesAreDistinct() {
        let texts = [PalettesIntentError.aiDisabled, .aiModelDownloading, .aiDeviceIneligible]
            .map { String(localized: $0.localizedStringResource) }
        #expect(Set(texts).count == 3)
    }

    @Test func waitUntilLoadedReturnsImmediatelyWhenNonEmpty() async {
        let data = AppData(inMemory: true)
        _ = data.addColor(name: "Seed", hex: "#112233")
        let start = ContinuousClock.now
        await data.waitUntilLoaded(timeout: .seconds(2))
        #expect(ContinuousClock.now - start < .milliseconds(200))
    }

    @Test func waitUntilLoadedWaitsForReloadWhenEmpty() async {
        let data = AppData(inMemory: true)
        data.colors = []
        data.palettes = []
        let start = ContinuousClock.now
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            data.reloadFromStore()
        }
        await data.waitUntilLoaded(timeout: .seconds(10))
        let elapsed = ContinuousClock.now - start
        #expect(elapsed >= .milliseconds(100))
        #expect(elapsed < .seconds(8)) // returned on the reload signal, not the timeout
    }

    @Test func waitUntilLoadedIsBoundedWhenNothingArrives() async {
        let data = AppData(inMemory: true)
        data.colors = []
        data.palettes = []
        let start = ContinuousClock.now
        await data.waitUntilLoaded(timeout: .milliseconds(200))
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    @available(iOS 26.0, *)
    @Test func suggestedEntitiesCapAtHundredMostRecentFirst() {
        let colors = (0..<150).map {
            ColorViewModel(name: "C\($0)", color: .red, HEX: String(format: "#%06X", $0), usedInPalette: false)
        }
        let suggested = ColorEntityQuery.suggested(from: colors)
        #expect(suggested.count == 100)
        #expect(suggested.first?.hex == String(format: "#%06X", 149))
    }
}
