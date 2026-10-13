//
//  SheetLayoutTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class SheetLayoutTests: XCTestCase {

    private func resolve(_ w: CGFloat, _ h: CGFloat, _ sc: UserInterfaceSizeClass?, min: CGFloat = 300) -> SheetLayout {
        SheetLayout.resolve(size: CGSize(width: w, height: h), horizontal: sc, minStackedHeight: min)
    }

    func testPhoneLandscapeIsSplit() { XCTAssertEqual(resolve(852, 393, .compact), .split) }
    func testPhonePortraitIsStacked() { XCTAssertEqual(resolve(393, 852, .compact), .stacked) }
    func testIPadLandscapeIsSplit() { XCTAssertEqual(resolve(1180, 820, .regular), .split) }
    func testIPadPortraitIsStacked() {
        XCTAssertEqual(resolve(820, 1180, .regular), .stacked)
        XCTAssertEqual(resolve(1024, 1366, .regular), .stacked)
    }
    func testRegularNearSquareIsSplit() { XCTAssertEqual(resolve(900, 1000, .regular), .split) }
    func testDuoOuterPortraitSplitsWhenContentDoesNotFit() {
        XCTAssertEqual(resolve(380, 430, .compact, min: 520), .split)
    }
    func testDuoOuterPortraitStackedWhenContentFits() {
        XCTAssertEqual(resolve(380, 430, .compact, min: 300), .stacked)
    }
    func testSquareIsStacked() { XCTAssertEqual(resolve(500, 500, .compact), .stacked) }
    func testLargerMinStackedHeightFlipsBorderlineToSplit() {
        XCTAssertEqual(resolve(393, 600, .compact, min: 500), .stacked)
        XCTAssertEqual(resolve(393, 600, .compact, min: 700), .split)
    }
}
