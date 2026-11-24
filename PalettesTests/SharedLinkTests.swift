//
//  SharedLinkTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class SharedLinkTests: XCTestCase {

    private let kyoto = SharedLink.palette(name: "Kyoto Dusk", swatches: [
        .init(hex: "#F2A65A", name: "Lantern Glow", role: "Accent"),
        .init(hex: "#c8553d", name: "Temple Red", role: nil),
        .init(hex: "5B3758", name: "Plum, Shadow / 紫 🌙", role: "Text"),
    ])

    func testPaletteRoundTripsAndNormalizesHex() {
        let read = SharedLink(url: kyoto.url)
        XCTAssertEqual(read?.kind, .palette)
        XCTAssertEqual(read?.name, "Kyoto Dusk")
        XCTAssertEqual(read?.swatches.map(\.hex), ["#F2A65A", "#C8553D", "#5B3758"])
        XCTAssertEqual(read?.swatches.map(\.name), ["Lantern Glow", "Temple Red", "Plum, Shadow / 紫 🌙"])
        XCTAssertEqual(read?.swatches.map(\.role), ["Accent", nil, "Text"])
    }

    func testColorRoundTrips() {
        let link = SharedLink.color(name: "Sea Glass", hex: "#9AD1D4")
        let read = SharedLink(url: link.url)
        XCTAssertEqual(read?.kind, .color)
        XCTAssertEqual(read?.name, "Sea Glass")
        XCTAssertEqual(read?.swatches, [.init(hex: "#9AD1D4", name: "Sea Glass", role: nil)])
    }

    func testURLShape() {
        let url = kyoto.url
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host(), "palettes.halilbagosi.com")
        XCTAssertEqual(url.path(), "/p/")
        let fragment = try! XCTUnwrap(url.fragment())
        // base64url: safe in a fragment, no padding.
        XCTAssertTrue(fragment.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }, fragment)
        XCTAssertEqual(SharedLink.color(name: "A", hex: "#000000").url.path(), "/c/")
    }

    func testAppSchemeFormOpensToo() {
        let fragment = kyoto.url.fragment()!
        let read = SharedLink(url: URL(string: "palettes://p/#\(fragment)")!)
        XCTAssertEqual(read, kyoto.normalizedForComparison)
    }

    func testRejectsOtherHostsKindsAndJunk() {
        let fragment = kyoto.url.fragment()!
        XCTAssertNil(SharedLink(url: URL(string: "https://example.com/p/#\(fragment)")!))
        XCTAssertNil(SharedLink(url: URL(string: "https://palettes.halilbagosi.com/x/#\(fragment)")!))
        XCTAssertNil(SharedLink(url: URL(string: "https://palettes.halilbagosi.com/p/")!))
        XCTAssertNil(SharedLink(url: URL(string: "https://palettes.halilbagosi.com/p/#notbase64!!")!))
        XCTAssertNil(SharedLink(url: URL(string: "https://palettes.halilbagosi.com/support/")!))
        XCTAssertNil(SharedLink(url: WidgetLink.library.url))
    }

    func testDropsBadHexesAndCapsCountAndNames() {
        let long = String(repeating: "x", count: 500)
        var swatches = (0..<30).map { SharedLink.Swatch(hex: String(format: "#%06X", $0), name: long, role: nil) }
        swatches.insert(.init(hex: "#GGGGGG", name: "Bad", role: nil), at: 0)
        // Built links cap at 20; a hand-made payload with more is capped on read.
        let link = SharedLink.palette(name: long, swatches: swatches)
        let read = try! XCTUnwrap(SharedLink(url: link.url))
        XCTAssertEqual(read.swatches.count, 19, "the bad hex is dropped from the 20 kept")
        XCTAssertEqual(read.name.count, SharedLink.maximumNameLength)
        XCTAssertTrue(read.swatches.allSatisfy { $0.name.count == SharedLink.maximumNameLength })
    }

    func testAllBadHexesIsNotALink() {
        let link = SharedLink.palette(name: "Nope", swatches: [.init(hex: "#12", name: "x", role: nil)])
        XCTAssertNil(SharedLink(url: link.url))
    }

    func testEmptyNamesFallBack() {
        let link = SharedLink.palette(name: "  ", swatches: [.init(hex: "#112233", name: "\n", role: " ")])
        let read = try! XCTUnwrap(SharedLink(url: link.url))
        XCTAssertEqual(read.name, "Shared Palette")
        XCTAssertEqual(read.swatches[0].name, "#112233")
        XCTAssertNil(read.swatches[0].role)
    }
}

private extension SharedLink {
    /// What reading `url` gives back: hexes as "#RRGGBB" uppercase.
    var normalizedForComparison: SharedLink {
        SharedLink(url: url)!
    }
}
