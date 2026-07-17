import Testing
import SwiftUI
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
}
