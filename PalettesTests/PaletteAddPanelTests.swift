import Testing
import SwiftUI
@testable import Palettes

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
struct HarmonyRowStateTests {
    private let hexes = ["#264653", "#2A9D8F", "#E9C46A"]

    @Test func noneWhenNothingIsInTheDraft() {
        #expect(HarmonyRow.state(for: hexes, draftHexes: []) == .none)
        #expect(HarmonyRow.state(for: hexes, draftHexes: ["#FFFFFF"]) == .none)
    }

    @Test func partialWhenSomeAreInTheDraft() {
        #expect(HarmonyRow.state(for: hexes, draftHexes: ["#2A9D8F"]) == .partial)
    }

    @Test func allWhenEveryHexIsInTheDraftComparedUppercased() {
        #expect(HarmonyRow.state(for: hexes, draftHexes: ["#264653", "#2A9D8F", "#E9C46A", "#000000"]) == .all)
        #expect(HarmonyRow.state(for: ["#2a9d8f", "#e9c46a"], draftHexes: ["#2A9D8F", "#E9C46A"]) == .all)
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
