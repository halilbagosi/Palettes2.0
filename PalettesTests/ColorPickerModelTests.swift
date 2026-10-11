import Testing
import SwiftUI
@testable import Palettes

@MainActor
struct ColorPickerModelTests {
    @Test func gridHasFixedShapeAndValidHexes() {
        let grid = ColorPickerModel.gridHexes()
        #expect(grid.count == ColorPickerModel.gridRows)
        #expect(grid.allSatisfy { $0.count == ColorPickerModel.gridColumns })
        #expect(grid.joined().allSatisfy { Color(hex: $0) != nil && $0.hasPrefix("#") && $0.count == 7 })
    }

    @Test func gridLastRowIsGrayscale() {
        for hex in ColorPickerModel.gridHexes().last! {
            let c = Color(hex: hex)!.rgbComponents
            #expect(abs(c.r - c.g) < 2 && abs(c.g - c.b) < 2)
        }
    }

    @Test func randomStarterIsDeterministicForSeed() {
        var a = SplitMix64(seed: 7), b = SplitMix64(seed: 7)
        #expect(ColorPickerModel.randomStarter(using: &a) == ColorPickerModel.randomStarter(using: &b))
        #expect(ColorPickerModel.vividStarters.contains(ColorPickerModel.randomStarter(using: &a)))
    }

    @Test func harmoniesStartWithTheBaseAndCoverEveryScheme() {
        let result = ColorPickerModel.harmonies(for: "#FF5D00")
        #expect(result.map(\.scheme) == ColorPickerModel.previewSchemes)
        for item in result {
            #expect(item.hexes.first == "#FF5D00")
            #expect(item.hexes.count == 5)
        }
    }

    @Test func harmoniesAreStable() {
        #expect(ColorPickerModel.harmonies(for: "#3366CC").map(\.hexes)
                == ColorPickerModel.harmonies(for: "#3366CC").map(\.hexes))
    }

    @Test func recentColorsAreNewestFirstAndCapped() {
        let lib = (0..<20).map { ColorViewModel(name: "\($0)", color: .red, HEX: String(format: "#%06X", $0), usedInPalette: false) }
        let recent = ColorPickerModel.recentColors(lib, limit: 12)
        #expect(recent.count == 12)
        #expect(recent.first?.name == "19")
    }
}
