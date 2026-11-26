//
//  GenerationModeTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class GenerationModeTests: XCTestCase {

    func testColorStylesAreTheEightAutoStyles() {
        XCTAssertEqual(GenerationMode.colorStyles.map(\.pinnedStyle), PaletteStyle.deck(for: .auto).map { Optional($0) })
        for mode in GenerationMode.colorStyles {
            XCTAssertEqual(mode.scheme, .auto, "a pinned style builds through Auto")
            XCTAssertNotNil(mode.pinnedStyle?.treatment)
        }
    }

    func testAutoAndInterfaceModesPinNothing() {
        XCTAssertEqual(GenerationMode.auto.scheme, .auto)
        XCTAssertNil(GenerationMode.auto.pinnedStyle)
        XCTAssertEqual(GenerationMode.interfaceModes, [.uiLight, .uiDark])
        XCTAssertEqual(GenerationMode.uiLight.scheme, .uiLight)
        XCTAssertEqual(GenerationMode.uiDark.scheme, .uiDark)
        XCTAssertNil(GenerationMode.uiDark.pinnedStyle)
    }

    func testNamesAndIDsAreUnique() {
        let all = [GenerationMode.auto] + GenerationMode.colorStyles + GenerationMode.interfaceModes
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(Set(all.map(\.displayName)).count, all.count)
        XCTAssertEqual(GenerationMode.style(.pastel).displayName, "Pastel")
        XCTAssertEqual(GenerationMode.uiLight.displayName, "UI Light")
    }
}
