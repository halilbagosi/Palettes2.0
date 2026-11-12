//
//  OpenLinkIntentTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class OpenLinkIntentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WidgetLinkInbox.shared.pending = nil
    }

    func testPerformQueuesTheLinkOnce() async throws {
        _ = try await OpenLinkIntent(.scanPalette).perform()
        XCTAssertEqual(WidgetLinkInbox.shared.take(), .scanPalette)
        XCTAssertNil(WidgetLinkInbox.shared.take())
    }

    func testMalformedLinkQueuesNothing() async throws {
        let intent = OpenLinkIntent()
        intent.urlString = "palettes://nowhere"
        _ = try await intent.perform()
        XCTAssertNil(WidgetLinkInbox.shared.take())
    }

    func testOpensTheApp() {
        XCTAssertTrue(OpenLinkIntent.openAppWhenRun)
    }
}
