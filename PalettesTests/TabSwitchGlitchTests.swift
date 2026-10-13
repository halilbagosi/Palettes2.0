//
//  TabSwitchGlitchTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class TabSwitchGlitchTests: XCTestCase {

    func testNoFoldIsNotReportedOnAppear() {
        XCTAssertFalse(FoldReport.shouldReportOnAppear(nil))
    }

    func testFoldIsReportedOnAppear() {
        XCTAssertTrue(FoldReport.shouldReportOnAppear(Fold(frame: CGRect(x: 100, y: 0, width: 10, height: 300))))
    }

    func testViewportSeedFromMeasuredSize() {
        XCTAssertEqual(MorphingViewportCache.seed(from: CGSize(width: 390, height: 700)),
                       CGRect(x: 0, y: 0, width: 390, height: 700))
    }

    func testViewportSeedIsZeroWithoutMeasurement() {
        XCTAssertEqual(MorphingViewportCache.seed(from: .zero), .zero)
    }
}
