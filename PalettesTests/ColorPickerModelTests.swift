import Testing
import SwiftUI
@testable import Palettes

@MainActor
struct ColorPickerModelTests {
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
}
