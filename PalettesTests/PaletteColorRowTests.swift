import Testing
import CoreGraphics
@testable import Palettes

struct PaletteColorRowTests {
    private let step: CGFloat = 64

    @Test func targetIndexSnapsToNearestSlot() {
        #expect(PaletteColorRow.targetIndex(from: 0, translation: 0, step: step, count: 5) == 0)
        #expect(PaletteColorRow.targetIndex(from: 0, translation: 31, step: step, count: 5) == 0)
        #expect(PaletteColorRow.targetIndex(from: 0, translation: 33, step: step, count: 5) == 1)
        #expect(PaletteColorRow.targetIndex(from: 3, translation: -130, step: step, count: 5) == 1)
    }

    @Test func targetIndexStaysInsideTheRow() {
        #expect(PaletteColorRow.targetIndex(from: 1, translation: -500, step: step, count: 5) == 0)
        #expect(PaletteColorRow.targetIndex(from: 3, translation: 500, step: step, count: 5) == 4)
    }

    @Test func neighborsShiftTowardTheGapWhenMovingRight() {
        // Tile 1 hovers over slot 3: tiles 2 and 3 slide left, the rest stay.
        let shifts = (0..<5).map { PaletteColorRow.shift(forIndex: $0, start: 1, target: 3) }
        #expect(shifts == [0, 0, -1, -1, 0])
    }

    @Test func neighborsShiftTowardTheGapWhenMovingLeft() {
        // Tile 3 hovers over slot 1: tiles 1 and 2 slide right.
        let shifts = (0..<5).map { PaletteColorRow.shift(forIndex: $0, start: 3, target: 1) }
        #expect(shifts == [0, 1, 1, 0, 0])
    }

    @Test func nothingShiftsWhileOverItsOwnSlot() {
        let shifts = (0..<5).map { PaletteColorRow.shift(forIndex: $0, start: 2, target: 2) }
        #expect(shifts == [0, 0, 0, 0, 0])
    }
}
