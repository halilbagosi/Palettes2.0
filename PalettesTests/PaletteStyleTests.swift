//
//  PaletteStyleTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteStyleTests: XCTestCase {

    func testEachModeHasItsDeck() {
        XCTAssertEqual(PaletteStyle.deck(for: .uiLight).count, 6)
        XCTAssertEqual(PaletteStyle.deck(for: .uiDark).count, 6)
        XCTAssertEqual(PaletteStyle.deck(for: .auto).count, 8)
        XCTAssertTrue(PaletteStyle.deck(for: .triadic).isEmpty)
        let all = PaletteStyle.deck(for: .uiLight) + PaletteStyle.deck(for: .uiDark) + PaletteStyle.deck(for: .auto)
        XCTAssertEqual(Set(all), Set(PaletteStyle.allCases), "every style belongs to exactly one deck")
        XCTAssertEqual(all.count, PaletteStyle.allCases.count)
    }

    func testInterfaceStylesDefineEveryRole() {
        for style in PaletteStyle.deck(for: .uiLight) + PaletteStyle.deck(for: .uiDark) {
            let roles = try! XCTUnwrap(style.interfaceRoles, "\(style)")
            XCTAssertEqual(Set(roles.keys), Set(PaletteStyle.interfaceRoleNames), "\(style)")
            XCTAssertNil(style.treatment, "\(style)")
        }
    }

    func testAutoStylesCarryATreatment() {
        for style in PaletteStyle.deck(for: .auto) {
            let treatment = try! XCTUnwrap(style.treatment, "\(style)")
            XCTAssertFalse(treatment.harmonies.isEmpty, "\(style)")
            XCTAssertFalse(treatment.harmonies.contains { $0 == .auto || $0.isUIMode }, "\(style)")
            XCTAssertNil(style.interfaceRoles, "\(style)")
        }
    }

    func testDisplayNamesAreUnique() {
        let names = PaletteStyle.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains(""))
    }

    func testEachHarmonyHasOneTreatment() {
        XCTAssertEqual(PaletteStyle.treatment(for: .analogous), .analogous603010)
        XCTAssertEqual(PaletteStyle.treatment(for: .complementary), .complementaryPop)
        XCTAssertEqual(PaletteStyle.treatment(for: .monochromatic), .monochromePop)
        XCTAssertEqual(PaletteStyle.treatment(for: .splitComplementary), .splitComplementary)
        XCTAssertEqual(PaletteStyle.treatment(for: .triadic), .triadicPlayful)
        XCTAssertNil(PaletteStyle.treatment(for: .uiLight))
    }
}
