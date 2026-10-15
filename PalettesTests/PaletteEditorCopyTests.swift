//
//  PaletteEditorCopyTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class PaletteEditorCopyTests: XCTestCase {
    func testCaptionCounts() {
        XCTAssertEqual(PaletteEditorCopy.caption(colorCount: 1), "1 color \u{00B7} add one more to create")
        XCTAssertEqual(PaletteEditorCopy.caption(colorCount: 4), "4 colors")
        XCTAssertEqual(PaletteEditorCopy.caption(colorCount: 20), "20 colors \u{00B7} full")
    }

    func testMinStackedHeightSumsContent() {
        let got = PaletteEditorCopy.minStackedHeight(strip: 100, name: 50, picker: 30, spacing: 10)
        let expected: CGFloat = 100 + 50 + 30 + 20 + 28
        XCTAssertEqual(got, expected)
    }

    func testNamePlacementInSplit() {
        XCTAssertTrue(PaletteEditorCopy.nameBelongsToVisualColumn(isCreating: true))
        XCTAssertFalse(PaletteEditorCopy.nameBelongsToVisualColumn(isCreating: false))
    }
}
