//
//  PaletteEditorCopyTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class PaletteEditorCopyTests: XCTestCase {
    func testSubtextHiddenWhenPaletteIsEmpty() {
        XCTAssertNil(PaletteEditorCopy.subtext(colorCount: 0))
    }

    func testSubtextShownOnceThereAreColors() {
        XCTAssertEqual(PaletteEditorCopy.subtext(colorCount: 1), "Tap to edit \u{00B7} long press to remove")
        XCTAssertEqual(PaletteEditorCopy.subtext(colorCount: 6), "Tap to edit \u{00B7} long press to remove")
    }

    func testCaptionCounts() {
        XCTAssertEqual(PaletteEditorCopy.caption(colorCount: 1), "1 color \u{00B7} add one more to create")
        XCTAssertEqual(PaletteEditorCopy.caption(colorCount: 4), "4 colors")
    }

    func testMinStackedHeightSumsContent() {
        XCTAssertEqual(PaletteEditorCopy.minStackedHeight(strip: 100, name: 50, picker: 30, panel: 200, spacing: 10), 100 + 50 + 30 + 200 + 30 + 28)
    }
}
