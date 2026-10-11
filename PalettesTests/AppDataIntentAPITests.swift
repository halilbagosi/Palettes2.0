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
