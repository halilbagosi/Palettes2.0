//
//  ReviewPromptTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ReviewPromptTests: XCTestCase {

    func testAsksWhenTheThirdPaletteIsSaved() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(previousCount: 2, count: 3, lastAskedVersion: nil, version: "1.0"))
        XCTAssertTrue(ReviewPrompt.shouldAsk(previousCount: 7, count: 8, lastAskedVersion: nil, version: "1.0"))
    }

    func testDoesNotAskBeforeTheUserHasAFewPalettes() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(previousCount: 0, count: 1, lastAskedVersion: nil, version: "1.0"))
        XCTAssertFalse(ReviewPrompt.shouldAsk(previousCount: 1, count: 2, lastAskedVersion: nil, version: "1.0"))
    }

    func testAsksOnlyOncePerVersion() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(previousCount: 3, count: 4, lastAskedVersion: "1.0", version: "1.0"))
        XCTAssertTrue(ReviewPrompt.shouldAsk(previousCount: 3, count: 4, lastAskedVersion: "1.0", version: "1.1"))
    }

    func testImportsAndDeletionsAreNotSaves() {
        XCTAssertFalse(ReviewPrompt.shouldAsk(previousCount: 0, count: 12, lastAskedVersion: nil, version: "1.0"))
        XCTAssertFalse(ReviewPrompt.shouldAsk(previousCount: 5, count: 4, lastAskedVersion: nil, version: "1.0"))
        XCTAssertFalse(ReviewPrompt.shouldAsk(previousCount: 4, count: 4, lastAskedVersion: nil, version: "1.0"))
    }

    func testWriteReviewLinkNeedsAnAppStoreID() {
        XCTAssertNil(AppLinks.writeReviewURL(appStoreID: nil))
        XCTAssertEqual(AppLinks.writeReviewURL(appStoreID: "123456789")?.absoluteString,
                       "https://apps.apple.com/app/id123456789?action=write-review")
    }
}
