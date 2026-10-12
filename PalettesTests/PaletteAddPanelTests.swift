import Testing
import SwiftUI
@testable import Palettes

@MainActor
struct PaletteEditorLayoutTests {
    @Test func panelTakesItsShareOfATallEditor() {
        let h = PaletteEditorLayout.panelHeight(available: 700)
        #expect(abs(h - 700 * PaletteEditorLayout.panelRatio) < 0.001)
        #expect(h >= PaletteEditorLayout.minPanelHeight)
    }

    @Test func panelNeverShrinksBelowTheMinimum() {
        #expect(PaletteEditorLayout.panelHeight(available: 450) == PaletteEditorLayout.minPanelHeight)
        #expect(PaletteEditorLayout.panelHeight(available: 100) == PaletteEditorLayout.minPanelHeight)
    }

    @Test func panelLeavesRoomForTheStripAndList() {
        for available in stride(from: 600.0, through: 1100.0, by: 20.0) {
            let h = PaletteEditorLayout.panelHeight(available: available)
            #expect(available - h >= PaletteEditorLayout.reservedAbovePanel - 0.001, "available \(available)")
        }
        // A very tall editor (iPad) keeps the ratio.
        #expect(PaletteEditorLayout.panelHeight(available: 1200) <= 1200 * PaletteEditorLayout.panelRatio)
    }

    @Test func minimumGrowsWithTypeSizeUpToACap() {
        #expect(PaletteEditorLayout.minimum(typeScale: 1) == PaletteEditorLayout.minPanelHeight)
        #expect(PaletteEditorLayout.minimum(typeScale: 0.8) == PaletteEditorLayout.minPanelHeight)
        #expect(PaletteEditorLayout.minimum(typeScale: 1.2) > PaletteEditorLayout.minPanelHeight)
        #expect(PaletteEditorLayout.minimum(typeScale: 3) == PaletteEditorLayout.minPanelHeight * PaletteEditorLayout.maxTypeScale)
    }

    @Test func panelHonorsAScaledMinimum() {
        let minimum = PaletteEditorLayout.minimum(typeScale: 1.3)
        #expect(PaletteEditorLayout.panelHeight(available: 560, minimum: minimum) == minimum)
    }

    @Test func smallPhoneStillFitsPickChrome() {
        // A 667 pt phone leaves roughly 600 pt in the sheet.
        let h = PaletteEditorLayout.panelHeight(available: 600)
        #expect(h >= PaletteEditorLayout.minPanelHeight)
        #expect(600 - h >= 240 - 0.001)
    }
}

@MainActor
struct HarmonyBaseTests {
    private let palette = ["#264653", "#2A9D8F", "#E9C46A"]

    @Test func selectedBandWins() {
        #expect(HarmonyBase.resolve(selectedHex: "#2a9d8f", paletteHexes: palette, pickHex: "#FF0000") == "#2A9D8F")
    }

    @Test func staleSelectionFallsBackToLast() {
        #expect(HarmonyBase.resolve(selectedHex: "#123456", paletteHexes: palette, pickHex: "#FF0000") == "#E9C46A")
        #expect(HarmonyBase.resolve(selectedHex: nil, paletteHexes: palette, pickHex: "#FF0000") == "#E9C46A")
    }

    @Test func emptyPaletteUsesThePickColor() {
        #expect(HarmonyBase.resolve(selectedHex: nil, paletteHexes: [], pickHex: "#FF0000") == "#FF0000")
        #expect(HarmonyBase.resolve(selectedHex: "#264653", paletteHexes: [], pickHex: "#FF0000") == "#FF0000")
    }
}

@MainActor
struct NextStarterTests {
    @Test func skipsTakenStarters() {
        var rng = SystemRandomNumberGenerator()
        let all = ColorPickerModel.vividStarters
        let taken = Set(all.dropLast().map { $0.uppercased() })
        for _ in 0..<20 {
            #expect(ColorPickerModel.nextStarter(excluding: taken, using: &rng) == all.last)
        }
    }

    @Test func fallsBackWhenEverythingIsTaken() {
        var rng = SystemRandomNumberGenerator()
        let taken = Set(ColorPickerModel.vividStarters.map { $0.uppercased() })
        #expect(ColorPickerModel.vividStarters.contains(ColorPickerModel.nextStarter(excluding: taken, using: &rng)))
    }
}
