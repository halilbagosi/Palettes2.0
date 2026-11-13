//
//  QuickActionTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class QuickActionTests: XCTestCase {

    func testScanPaletteRoundTripsThroughItsShortcutItem() {
        XCTAssertEqual(QuickAction(QuickAction.scanPalette.shortcutItem), .scanPalette)
    }

    /// iOS shows at most four app quick actions; Scan Palette is reached
    /// through its control and deep link instead.
    func testScanPaletteIsNotOnTheHomeScreenMenu() {
        XCTAssertFalse(QuickAction.available.contains(.scanPalette))
        XCTAssertLessThanOrEqual(QuickAction.available.count, 4)
    }

    func testScanRequestIsConsumedOnce() {
        let router = SceneRouter()
        router.isScanRequested = true
        XCTAssertTrue(router.consumeScanRequest())
        XCTAssertFalse(router.consumeScanRequest())
    }
}
