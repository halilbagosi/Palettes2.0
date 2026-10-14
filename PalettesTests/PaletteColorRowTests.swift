import Testing
import SwiftUI
@testable import Palettes

@MainActor
struct PaletteStripEditorTests {
    private func colors(_ n: Int) -> [PaletteColor] {
        (0..<n).map { PaletteColor(color: .gray, hex: String(format: "#%06X", $0 + 1), name: "c\($0)") }
    }

    @Test func droppingRightTakesTargetSlot() {
        var list = colors(4)
        let target = list[2].id, moved = list[0].id
        let to = PaletteStripEditor.dropIndex(moving: moved, onto: target, in: list)
        #expect(to == 2)
        var draft = PaletteDraft(colors: list)
        draft.move(id: moved, to: to!)
        list = draft.colors
        #expect(list.map(\.name) == ["c1", "c2", "c0", "c3"])
    }

    @Test func droppingLeftTakesTargetSlot() {
        let list = colors(4)
        let to = PaletteStripEditor.dropIndex(moving: list[3].id, onto: list[1].id, in: list)
        #expect(to == 1)
        var draft = PaletteDraft(colors: list)
        draft.move(id: list[3].id, to: to!)
        #expect(draft.colors.map(\.name) == ["c0", "c3", "c1", "c2"])
    }

    @Test func droppingOnNeighborSwaps() {
        let list = colors(3)
        var draft = PaletteDraft(colors: list)
        draft.move(id: list[0].id, to: PaletteStripEditor.dropIndex(moving: list[0].id, onto: list[1].id, in: list)!)
        #expect(draft.colors.map(\.name) == ["c1", "c0", "c2"])
    }

    @Test func droppingOnItselfOrUnknownDoesNothing() {
        let list = colors(3)
        #expect(PaletteStripEditor.dropIndex(moving: list[1].id, onto: list[1].id, in: list) == nil)
        #expect(PaletteStripEditor.dropIndex(moving: UUID(), onto: list[1].id, in: list) == nil)
        #expect(PaletteStripEditor.dropIndex(moving: list[1].id, onto: UUID(), in: list) == nil)
    }
}
