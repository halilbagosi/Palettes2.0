import Testing
import SwiftUI
import AppIntents
@testable import Palettes

@MainActor
struct LibrarySearchTests {
    static let blue = ColorViewModel(name: "Sky", color: Color(hex: "#57BBFF")!, HEX: "#57BBFF", usedInPalette: false)
    static let red = ColorViewModel(name: "Brick", color: Color(hex: "#CC2200")!, HEX: "#CC2200", usedInPalette: false)
    static let green = ColorViewModel(name: "Moss", color: Color(hex: "#3A7D2C")!, HEX: "#3A7D2C", usedInPalette: false)
    static let all = [blue, red, green]

    static let ocean = PaletteViewModel(name: "Ocean Breeze", paletteColors: [
        PaletteColor(color: Color(hex: "#57BBFF")!, hex: "#57BBFF", name: "Sky", role: "Primary")
    ])
    static let forest = PaletteViewModel(name: "Forest", paletteColors: [
        PaletteColor(color: Color(hex: "#3A7D2C")!, hex: "#3A7D2C", name: "Moss")
    ])

    @Test func colorsMatchHexWithAndWithoutHash() {
        #expect(LibrarySearch.colors(matching: "#57bbff", in: Self.all).map(\.name) == ["Sky"])
        #expect(LibrarySearch.colors(matching: "57BBFF", in: Self.all).map(\.name) == ["Sky"])
    }

    @Test func colorsMatchNameAndHueWords() {
        #expect(LibrarySearch.colors(matching: "moss", in: Self.all).map(\.name) == ["Moss"])
        #expect(LibrarySearch.colors(matching: "blue", in: Self.all).map(\.name) == ["Sky"])
        #expect(LibrarySearch.colors(matching: "warm", in: Self.all).map(\.name) == ["Brick"])
        #expect(LibrarySearch.colors(matching: "cool", in: Self.all).map(\.name) == ["Sky", "Moss"])
    }

    @Test func emptyTermReturnsAll() {
        #expect(LibrarySearch.colors(matching: nil, in: Self.all).count == 3)
        #expect(LibrarySearch.palettes(matching: "  ", in: [Self.ocean, Self.forest]).count == 2)
    }

    @Test func palettesMatchNameTagsColorNamesAndHex() {
        let ps = [Self.ocean, Self.forest]
        #expect(LibrarySearch.palettes(matching: "ocean", in: ps).map(\.name) == ["Ocean Breeze"])
        #expect(LibrarySearch.palettes(matching: "primary", in: ps).map(\.name) == ["Ocean Breeze"])
        #expect(LibrarySearch.palettes(matching: "moss", in: ps).map(\.name) == ["Forest"])
        #expect(LibrarySearch.palettes(matching: "#57bbff", in: ps).map(\.name) == ["Ocean Breeze"])
        #expect(LibrarySearch.palettes(matching: "57BBFF", in: ps).map(\.name) == ["Ocean Breeze"])
    }

    @available(iOS 26.0, *)
    @Test func findIntentsFilterSharedLibrary() async throws {
        let data = AppData.shared
        let savedP = data.palettes, savedC = data.colors
        defer { data.palettes = savedP; data.colors = savedC }
        data.palettes = [Self.ocean, Self.forest]
        data.colors = Self.all

        let ocean = try await FindPalettesIntent(searchTerm: "ocean").perform().value ?? []
        #expect(ocean.map(\.name) == ["Ocean Breeze"])
        let allP = try await FindPalettesIntent(searchTerm: "").perform().value ?? []
        #expect(allP.count == 2)
        let blues = try await FindColorsIntent(searchTerm: "blue").perform().value ?? []
        #expect(blues.map(\.name) == ["Sky"])
        let allC = try await FindColorsIntent(searchTerm: nil).perform().value ?? []
        #expect(allC.count == 3)
    }

    @available(iOS 26.0, *)
    @Test func searchLibraryIntentSetsPendingTermAndTab() async throws {
        let data = AppData.shared
        defer { data.pendingSearchTerm = nil; data.activeTab = .palettes }
        _ = try await SearchLibraryIntent(criteria: StringSearchCriteria(term: "ocean")).perform()
        #expect(data.pendingSearchTerm == "ocean")
        #expect(data.activeTab == .search)
    }
}
