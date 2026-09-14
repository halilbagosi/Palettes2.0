import XCTest
@testable import Palettes

final class GeneratedBadgeVisibilityTests: XCTestCase {
    func testVisibleIDsIncludesCardsIntersectingViewport() {
        let visibleID = UUID()
        let partialID = UUID()
        let offscreenID = UUID()

        let frames = [
            GeneratedBadgeVisibilityFrame(
                id: visibleID,
                frame: CGRect(x: 10, y: 20, width: 100, height: 100)
            ),
            GeneratedBadgeVisibilityFrame(
                id: partialID,
                frame: CGRect(x: 10, y: 190, width: 100, height: 100)
            ),
            GeneratedBadgeVisibilityFrame(
                id: offscreenID,
                frame: CGRect(x: 10, y: 240, width: 100, height: 100)
            )
        ]

        let visibleIDs = GeneratedBadgeVisibility.visibleIDs(
            from: frames,
            viewportSize: CGSize(width: 320, height: 200)
        )

        XCTAssertEqual(visibleIDs, [visibleID, partialID])
    }

    func testVisibleIDsExcludesCardsOutsideViewport() {
        let offscreenID = UUID()
        let frame = GeneratedBadgeVisibilityFrame(
            id: offscreenID,
            frame: CGRect(x: 0, y: 200, width: 100, height: 100)
        )

        let visibleIDs = GeneratedBadgeVisibility.visibleIDs(
            from: [frame],
            viewportSize: CGSize(width: 320, height: 200)
        )

        XCTAssertTrue(visibleIDs.isEmpty)
    }
}
