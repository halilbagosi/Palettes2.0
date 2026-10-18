//
//  NameLimitTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class NameLimitTests: XCTestCase {

    private let long = String(repeating: "x", count: NameLimit.maxLength + 50)

    func testClampLeavesShortNamesAlone() {
        XCTAssertEqual(NameLimit.clamp("Sage"), "Sage")
    }

    func testClampCutsAtMaxLength() {
        XCTAssertEqual(NameLimit.clamp(long).count, NameLimit.maxLength)
    }

    func testColorViewModelClampsOnInitAndAssignment() {
        var color = ColorViewModel(name: long, color: .red, HEX: "#FF0000", usedInPalette: false)
        XCTAssertEqual(color.name.count, NameLimit.maxLength)
        color.name = long + long
        XCTAssertEqual(color.name.count, NameLimit.maxLength)
    }

    func testPaletteColorClampsOnInitAndAssignment() {
        var swatch = PaletteColor(color: .red, hex: "#FF0000", name: long)
        XCTAssertEqual(swatch.name.count, NameLimit.maxLength)
        swatch.name = long
        XCTAssertEqual(swatch.name.count, NameLimit.maxLength)
    }

    func testPaletteViewModelClampsPaletteAndColorNames() {
        var palette = PaletteViewModel(name: long, colors: [.red], hexCodes: ["#FF0000"], colorNames: [long])
        XCTAssertEqual(palette.name.count, NameLimit.maxLength)
        XCTAssertEqual(palette.colorNames.first?.count, NameLimit.maxLength)
        palette.name = long
        XCTAssertEqual(palette.name.count, NameLimit.maxLength)
        let other = PaletteViewModel(name: long, paletteColors: [])
        XCTAssertEqual(other.name.count, NameLimit.maxLength)
    }

    @MainActor
    func testCustomTagsAreClamped() {
        let data = AppData(inMemory: true)
        XCTAssertTrue(data.addCustomTag(long))
        XCTAssertEqual(data.customTags.last?.count, NameLimit.maxLength)
    }
}
