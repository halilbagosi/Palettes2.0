//
//  PaletteViewModelTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class PaletteViewModelTests: XCTestCase {

    // MARK: - Zipping init: equal-length arrays

    func testZippingInitWithEqualArraysAlignsFields() {
        let colors: [Color] = [.red, .green, .blue]
        let hexCodes = ["#FF0000", "#00FF00", "#0000FF"]
        let colorNames = ["Red", "Green", "Blue"]

        let palette = PaletteViewModel(name: "Test", colors: colors, hexCodes: hexCodes, colorNames: colorNames)

        XCTAssertEqual(palette.paletteColors.count, 3)
        XCTAssertEqual(palette.colors.count, 3)
        XCTAssertEqual(palette.hexCodes, hexCodes)
        XCTAssertEqual(palette.colorNames, colorNames)
    }

    // MARK: - Zipping init: hexCodes shorter than colors (regression test)

    func testZippingInitWithShortHexCodesIsPaddedWithoutCrashing() {
        let colors: [Color] = [.red, .green, .blue]
        let hexCodes = ["#FF0000"] // intentionally shorter than colors

        let palette = PaletteViewModel(name: "Test", colors: colors, hexCodes: hexCodes, colorNames: [])

        XCTAssertEqual(palette.hexCodes.count, palette.colors.count)
        XCTAssertEqual(palette.paletteColors.count, 3)
        XCTAssertEqual(palette.hexCodes[0], "#FF0000")
        // Padded entries should be derived, non-empty hex strings.
        XCTAssertFalse(palette.hexCodes[1].isEmpty)
        XCTAssertFalse(palette.hexCodes[2].isEmpty)
    }

    // MARK: - Zipping init: colorNames shorter than colors

    func testZippingInitWithShortColorNamesIsPaddedViaColorNamer() {
        let colors: [Color] = [.red, .green, .blue]
        let hexCodes = ["#FF0000", "#00FF00", "#0000FF"]
        let colorNames = ["Red"] // intentionally shorter

        let palette = PaletteViewModel(name: "Test", colors: colors, hexCodes: hexCodes, colorNames: colorNames)

        XCTAssertEqual(palette.colorNames.count, palette.colors.count)
        XCTAssertEqual(palette.colorNames[0], "Red")
        XCTAssertEqual(palette.colorNames[1], ColorNamer.name(forHex: "#00FF00"))
        XCTAssertEqual(palette.colorNames[2], ColorNamer.name(forHex: "#0000FF"))
    }

    // MARK: - Mutation alignment

    func testAppendingPaletteColorKeepsAllAccessorsAligned() {
        var palette = PaletteViewModel(
            name: "Test",
            colors: [.red],
            hexCodes: ["#FF0000"],
            colorNames: ["Red"]
        )

        palette.paletteColors.append(PaletteColor(color: .blue, hex: "#0000FF", name: "Blue"))

        XCTAssertEqual(palette.paletteColors.count, 2)
        XCTAssertEqual(palette.colors.count, 2)
        XCTAssertEqual(palette.hexCodes.count, 2)
        XCTAssertEqual(palette.colorNames.count, 2)
        XCTAssertEqual(palette.hexCodes.last, "#0000FF")
        XCTAssertEqual(palette.colorNames.last, "Blue")
    }
}
