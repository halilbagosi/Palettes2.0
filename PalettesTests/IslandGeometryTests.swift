import XCTest
@testable import Palettes

final class IslandGeometryTests: XCTestCase {
    private let portrait = CGSize(width: 402, height: 874)

    func testDynamicIslandAtInset62() {
        let g = IslandGeometry.make(topInset: 62, screenSize: portrait)
        XCTAssertEqual(g.kind, .dynamicIsland)
        XCTAssertEqual(g.width, 125)
        XCTAssertEqual(g.height, 37)
        XCTAssertEqual(g.top, 14)
        XCTAssertEqual(g.bottom, 51)
    }

    func testDynamicIslandAtInset59UsesHigherPlacement() {
        let g = IslandGeometry.make(topInset: 59, screenSize: CGSize(width: 393, height: 852))
        XCTAssertEqual(g.kind, .dynamicIsland)
        XCTAssertEqual(g.top, 11)
    }

    func testNotchBetween44And58() {
        for inset in [44.0, 47, 50, 58] {
            let g = IslandGeometry.make(topInset: inset, screenSize: CGSize(width: 390, height: 844))
            XCTAssertEqual(g.kind, .notch, "inset \(inset)")
            XCTAssertEqual(g.width, 160)
            XCTAssertEqual(g.height, 31)
            XCTAssertEqual(g.top, 0)
        }
    }

    func testNoneForSmallInsetsAndLandscape() {
        XCTAssertEqual(IslandGeometry.make(topInset: 20, screenSize: CGSize(width: 375, height: 667)).kind, .none)
        XCTAssertEqual(IslandGeometry.make(topInset: 0, screenSize: portrait).kind, .none)
        XCTAssertEqual(IslandGeometry.make(topInset: 62, screenSize: CGSize(width: 874, height: 402)).kind, .none)
        XCTAssertFalse(IslandGeometry.none.hasMorph)
    }

    func testDrawnIslandIsOnePointSmallerOnEverySide() {
        let g = IslandGeometry.make(topInset: 62, screenSize: portrait)
        let rect = g.drawnRect(screenWidth: 402)
        let hardware = CGRect(x: (402.0 - 125) / 2, y: 14, width: 125, height: 37)
        XCTAssertEqual(rect.minX, hardware.minX + 1)
        XCTAssertEqual(rect.maxX, hardware.maxX - 1)
        XCTAssertEqual(rect.minY, hardware.minY + 1)
        XCTAssertEqual(rect.maxY, hardware.maxY - 1)
        XCTAssertEqual(g.drawnBottom, rect.maxY)
        XCTAssertEqual(g.drawnRect(screenWidth: 402).midX, 201)
    }

    func testNotchOverhangsTheScreenEdgeAndIsCentered() {
        let g = IslandGeometry.make(topInset: 47, screenSize: CGSize(width: 390, height: 844))
        let rect = g.drawnRect(screenWidth: 390)
        XCTAssertEqual(rect.minY, -10)
        XCTAssertEqual(rect.maxY, 30)
        XCTAssertEqual(rect.midX, 195)
        XCTAssertEqual(rect.width, 158)
    }

    func testNoneHasEmptyShape() {
        XCTAssertTrue(IslandGeometry.none.path(screenWidth: 375).isEmpty)
    }
}
