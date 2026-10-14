import Testing
import Foundation
@testable import Palettes

struct HueOrderTests {
    private func sorted(_ hexes: [String]) -> [String] {
        hexes.sorted { HueOrder.key(forHex: $0) < HueOrder.key(forHex: $1) }
    }

    @Test func colorsGoAroundTheWheelWithNeutralsLast() {
        let input = ["#808080", "#0000FF", "#FFFF00", "#FF0000", "#FFFFFF", "#00FF00", "#000000"]
        #expect(sorted(input) == ["#FF0000", "#FFFF00", "#00FF00", "#0000FF", "#FFFFFF", "#808080", "#000000"])
    }

    @Test func hashIsOptionalAndBadHexSortsLast() {
        #expect(sorted(["zzz", "00FF00", "#FF0000"]) == ["#FF0000", "00FF00", "zzz"])
    }

    @Test func equalHuesGoLightToDark() {
        #expect(sorted(["#800000", "#FF0000"]) == ["#FF0000", "#800000"])
    }

    @Test func paletteHueIsTheSaturationWeightedCircularMean() {
        // Red (0) and a slightly purple red (~0.97) average just below 1,
        // not to the green side of the wheel.
        let key = HueOrder.key(forHexes: ["#FF0000", "#FF0033"])
        #expect(!key.isNeutral)
        #expect(key.hue > 0.95)
        // Grays don't pull the average; a palette of only grays is neutral.
        let blue = HueOrder.key(forHexes: ["#0000FF", "#888888"]).hue
        #expect(abs(blue - HueOrder.key(forHex: "#0000FF").hue) < 1e-9)
        #expect(HueOrder.key(forHexes: ["#111111", "#EEEEEE"]).isNeutral)
    }

    @Test func blueGreenPaletteSortsBeforeAPurpleOne() {
        let teal = HueOrder.key(forHexes: ["#00AA88", "#0088AA"])
        let purple = HueOrder.key(forHexes: ["#8800AA", "#AA00CC"])
        #expect(teal < purple)
    }

    @Test func librarySortOrdersItems() {
        let hexes = ["#0000FF", "#FF0000", "#00FF00"]
        let key: (String) -> HueOrder.Key = { HueOrder.key(forHex: $0) }
        #expect(LibrarySort.oldestFirst.ordered(hexes, hueKey: key) == hexes)
        #expect(LibrarySort.newestFirst.ordered(hexes, hueKey: key) == ["#00FF00", "#FF0000", "#0000FF"])
        #expect(LibrarySort.hue.ordered(hexes, hueKey: key) == ["#FF0000", "#00FF00", "#0000FF"])
    }

    @Test func libraryTitleCounts() {
        #expect(LibraryTitle.text("Palette", count: 0) == "Palettes")
        #expect(LibraryTitle.text("Palette", count: 1) == "1 Palette")
        #expect(LibraryTitle.text("Color", count: 12) == "12 Colors")
        #expect(LibraryTitle.plural("Palette") == "Palettes")
    }
}
