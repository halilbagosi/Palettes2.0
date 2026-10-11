//
//  PrivacyPolicyTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class PrivacyPolicyTests: XCTestCase {

    func testPolicyShipsInAppBundle() throws {
        let text = try XCTUnwrap(PrivacyPolicy.load(), "PrivacyPolicy.md must be a bundle resource")
        XCTAssertTrue(text.contains("iCloud"))
        XCTAssertTrue(text.contains(AppLinks.supportEmail), "policy and Settings must show the same contact")
    }

    func testBlocksSplitHeadingsAndParagraphs() {
        let blocks = PrivacyPolicy.blocks(from: "# Title\n\nIntro line.\n\n## Section\n\nBody **bold**.\n- item")
        XCTAssertEqual(blocks, [
            .heading("Title", level: 1),
            .paragraph("Intro line."),
            .heading("Section", level: 2),
            .paragraph("Body **bold**.\n- item"),
        ])
    }
}
