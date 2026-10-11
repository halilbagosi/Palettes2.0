//
//  ColorRoleTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ColorRoleTests: XCTestCase {
    func testDefaultRolesOrderAndSlugs() {
        XCTAssertEqual(ColorRole.defaults.map(\.name),
            ["Primary", "Secondary", "Accent", "Background", "Surface", "Text", "Error", "Success", "Warning", "Border"])
        XCTAssertEqual(ColorRole(name: "Primary").slug, "primary")
        XCTAssertEqual(ColorRole(name: "Brand Blue 2").slug, "brand-blue-2")
    }

    func testViewModelZipInitPadsRoles() {
        let vm = PaletteViewModel(name: "P",
                                  colors: [.red, .blue, .green],
                                  hexCodes: ["#FF0000", "#0000FF", "#00FF00"],
                                  colorNames: ["R", "B", "G"],
                                  colorRoles: ["Primary", ""])   // shorter than colors
        XCTAssertEqual(vm.paletteColors[0].role, "Primary")
        XCTAssertNil(vm.paletteColors[1].role)   // empty string → nil
        XCTAssertNil(vm.paletteColors[2].role)   // missing → nil
        XCTAssertEqual(vm.colorRoles, ["Primary", "", ""])   // always full length
    }
}
