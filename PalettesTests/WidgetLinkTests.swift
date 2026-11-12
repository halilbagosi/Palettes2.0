//
//  WidgetLinkTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class WidgetLinkTests: XCTestCase {

    private let id = UUID()

    private var allLinks: [WidgetLink] {
        [.palette(id), .color(id), .newPalette, .newColor, .scanColor, .scanPalette,
         .copyPalette(id), .copyColor(id), .library]
    }

    func testEveryLinkRoundTrips() {
        for link in allLinks {
            XCTAssertEqual(WidgetLink(url: link.url), link, "\(link.url)")
        }
    }

    func testURLShapes() {
        XCTAssertEqual(WidgetLink.newPalette.url.absoluteString, "palettes://new/palette")
        XCTAssertEqual(WidgetLink.scanPalette.url.absoluteString, "palettes://new/scan-palette")
        XCTAssertEqual(WidgetLink.copyColor(id).url.absoluteString, "palettes://copy/color/\(id.uuidString)")
        XCTAssertEqual(WidgetLink.library.url.absoluteString, "palettes://library")
    }

    func testAcceptsLowercaseUUIDs() {
        let url = URL(string: "palettes://palette/\(id.uuidString.lowercased())")!
        XCTAssertEqual(WidgetLink(url: url), .palette(id))
    }

    func testRejectsMalformedURLs() {
        let bad = [
            "https://palette/\(id.uuidString)",
            "palettes://palette/not-a-uuid",
            "palettes://palette",
            "palettes://new/unknown",
            "palettes://copy/palette",
            "palettes://copy/swatch/\(id.uuidString)",
            "palettes://elsewhere",
        ]
        for string in bad {
            XCTAssertNil(WidgetLink(url: URL(string: string)!), string)
        }
    }

    func testCreationLinksMapToQuickActions() {
        XCTAssertEqual(QuickAction(WidgetLink.newPalette), .newPalette)
        XCTAssertEqual(QuickAction(WidgetLink.newColor), .newColor)
        XCTAssertEqual(QuickAction(WidgetLink.scanColor), .scanColor)
        XCTAssertEqual(QuickAction(WidgetLink.scanPalette), .scanPalette)
        XCTAssertNil(QuickAction(WidgetLink.library))
        XCTAssertNil(QuickAction(WidgetLink.palette(id)))
    }
}
