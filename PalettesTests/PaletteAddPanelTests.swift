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

    @Test func panelKeepsItsMinimumWhenThereIsRoom() {
        // Just enough for the minimum plus the strip and name field.
        let available = PaletteEditorLayout.minPanelHeight + PaletteEditorLayout.minimumAbovePanel
        #expect(PaletteEditorLayout.panelHeight(available: available) == PaletteEditorLayout.minPanelHeight)
        #expect(PaletteEditorLayout.panelHeight(available: 600) == PaletteEditorLayout.minPanelHeight)
    }

    @Test func panelShrinksBelowTheMinimumInAShortContainer() {
        // Shorter than the minimum plus the header: the panel gives way, not the strip.
        let h = PaletteEditorLayout.panelHeight(available: 450)
        #expect(h < PaletteEditorLayout.minPanelHeight)
        #expect(abs(450 - h - PaletteEditorLayout.minimumAbovePanel) < 0.001)
    }

    @Test func panelIsCappedBelowTheMinimumEvenWhenTheContainerIsShorterThanIt() {
        // available < minimum (iPhone landscape).
        let h = PaletteEditorLayout.panelHeight(available: 330)
        #expect(h < 330)
        #expect(h >= PaletteEditorLayout.floorPanelHeight)
        #expect(330 - h >= PaletteEditorLayout.minimumAbovePanel - 0.001)
    }

    @Test func panelNeverShrinksBelowTheFloor() {
        #expect(PaletteEditorLayout.panelHeight(available: 250) == PaletteEditorLayout.floorPanelHeight)
        #expect(PaletteEditorLayout.panelHeight(available: 100) == PaletteEditorLayout.floorPanelHeight)
        #expect(PaletteEditorLayout.panelHeight(available: 0) == PaletteEditorLayout.floorPanelHeight)
    }

    @Test func aScaledMinimumAlsoGivesWayInAShortContainer() {
        let minimum = PaletteEditorLayout.minimum(typeScale: 1.35)
        let h = PaletteEditorLayout.panelHeight(available: 580, minimum: minimum)
        #expect(h < minimum)
        #expect(580 - h >= PaletteEditorLayout.minimumAbovePanel - 0.001)
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
        #expect(PaletteEditorLayout.panelHeight(available: 800, minimum: minimum) == minimum)
    }

    @Test func panelOnASmallPhoneKeepsItsMinimumAndRoomAbove() {
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

@MainActor
struct PaletteScanSessionTests {
    private func stripes(_ colors: [UIColor]) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { ctx in
            let h = 300 / CGFloat(colors.count)
            for (i, c) in colors.enumerated() {
                c.setFill()
                ctx.fill(CGRect(x: 0, y: CGFloat(i) * h, width: 300, height: h))
            }
        }
    }

    @Test func aReplacementPhotoReplacesThePreviousPhotosColors() async throws {
        let session = PaletteScanSession()
        session.load(photo: stripes([.systemRed, .systemGreen, .systemBlue, .systemOrange]))
        await session.waitForLoad()
        let first = try #require(session.delivery)
        session.takeDelivery()
        #expect(!first.colors.isEmpty)
        #expect(first.replacing.isEmpty)

        session.load(photo: stripes([.systemPurple, .systemYellow, .systemTeal, .black]))
        await session.waitForLoad()
        let second = try #require(session.delivery)
        #expect(second.replacing == Set(first.colors.map(\.id)))
        #expect(second.colors.map(\.hex) != first.colors.map(\.hex))
        #expect(!session.isLoading)
    }

    @Test func removeDropsThePhotoAndUndoBringsItBack() async throws {
        let session = PaletteScanSession()
        session.load(photo: stripes([.systemRed, .systemBlue]))
        await session.waitForLoad()
        let found = try #require(session.delivery).colors
        session.takeDelivery()

        let removed = try #require(session.removePhoto())
        #expect(removed.colorIDs == Set(found.map(\.id)))
        #expect(session.image == nil)

        session.restore(removed)
        #expect(session.image != nil)
        // The restored photo still knows its colors: a new photo replaces them.
        session.load(photo: stripes([.systemGreen, .systemYellow]))
        await session.waitForLoad()
        #expect(session.delivery?.replacing == removed.colorIDs)
    }

    @Test func thePickerGetsOnlyThePhotosColors() async {
        let session = PaletteScanSession()
        session.load(photo: stripes([.systemRed, .systemBlue]))
        await session.waitForLoad()
        let found = session.delivery?.colors ?? []
        let other = PaletteColor(color: .green, hex: "#00FF00", name: "Green")
        let photo = session.photoColors(in: [other] + found)
        #expect(photo.colors.map(\.id) == found.map(\.id))
        #expect(photo.points.count == found.count)
        #expect(photo.points.values.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }
}
