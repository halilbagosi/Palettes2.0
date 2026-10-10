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

    func testEveryCenteredCutoutSizeMorphsFromItsCutout() {
        for size in IslandGeometry.centeredCutoutSizes {
            let screen = CGSize(width: size.width, height: size.height)
            XCTAssertEqual(IslandGeometry.make(topInset: 62, screenSize: screen).kind, .dynamicIsland, "\(size)")
            XCTAssertEqual(IslandGeometry.make(topInset: 47, screenSize: screen).kind, .notch, "\(size)")
        }
    }

    func testIPadPullsFromTheBezel() {
        for size in [CGSize(width: 820, height: 1180), CGSize(width: 1180, height: 820),
                     CGSize(width: 1032, height: 1376), CGSize(width: 744, height: 1133)] {
            XCTAssertEqual(IslandGeometry.make(topInset: 24, screenSize: size).kind, .bezel, "\(size)")
        }
    }

    func testOffCenterCutoutPullsFromTheBezel() {
        // A phone with a tall inset but a screen size no centered-cutout iPhone
        // has (iPhone Duo): its cutout is not where the island would be drawn.
        for size in [CGSize(width: 384, height: 860), CGSize(width: 640, height: 860)] {
            XCTAssertEqual(IslandGeometry.make(topInset: 62, screenSize: size).kind, .bezel, "\(size)")
        }
    }

    func testHomeButtonPhonesAndLandscapePullFromTheBezel() {
        XCTAssertEqual(IslandGeometry.make(topInset: 20, screenSize: CGSize(width: 375, height: 667)).kind, .bezel)
        XCTAssertEqual(IslandGeometry.make(topInset: 0, screenSize: portrait).kind, .bezel)
        XCTAssertEqual(IslandGeometry.make(topInset: 0, screenSize: CGSize(width: 874, height: 402)).kind, .bezel)
    }

    func testFloatingWindowHasNoMorph() {
        let floating = IslandGeometry.make(topInset: 24, screenSize: CGSize(width: 700, height: 600),
                                           reachesTopEdge: false)
        XCTAssertEqual(floating.kind, .none)
        XCTAssertFalse(IslandGeometry.none.hasMorph)
        // A centered cutout is the screen's own, so it does not depend on the window.
        XCTAssertEqual(IslandGeometry.make(topInset: 62, screenSize: portrait, reachesTopEdge: false).kind,
                       .dynamicIsland)
    }

    func testBezelSitsJustAboveTheScreenEdgeAndSpansIt() {
        let g = IslandGeometry.make(topInset: 24, screenSize: CGSize(width: 820, height: 1180))
        XCTAssertTrue(g.hasMorph)
        XCTAssertEqual(g.drawnBottom, -1)
        let rect = g.drawnRect(screenWidth: 820)
        XCTAssertEqual(rect.maxY, -1)
        XCTAssertLessThan(rect.minX, 0)
        XCTAssertGreaterThan(rect.maxX, 820)
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

@MainActor
final class IslandMorphBezelTests: XCTestCase {
    private func controller(island: IslandGeometry, width: CGFloat = 820) -> IslandMorphController {
        IslandMorphController(placement: .init(
            island: island, screenWidth: width,
            restCenter: CGPoint(x: width / 2, y: 450), restDiameter: 310))
    }

    func testIslandNeckIsUnchanged() {
        let c = controller(island: .make(topInset: 62, screenSize: CGSize(width: 402, height: 874)), width: 402)
        XCTAssertEqual(c.neckBase, IslandMorphController.neckWidth)
        XCTAssertEqual(IslandMorphController.snapGap(), 52 * (1 - 12.0 / 34), accuracy: 1e-9)
    }

    func testBezelDropStartsUnderTheFingerAndFollowsIt() {
        let c = controller(island: .bezel)
        c.dragChanged(translation: .zero, location: CGPoint(x: 300, y: 10), time: 0)
        XCTAssertEqual(c.orbFrame.center.x, 300)
        c.dragChanged(translation: CGSize(width: 40, height: 60), location: CGPoint(x: 340, y: 70), time: 0.1)
        XCTAssertEqual(c.orbFrame.center.x, 340)
    }

    func testBezelDropStaysClearOfTheCorners() {
        let c = controller(island: .bezel)
        c.dragChanged(translation: .zero, location: CGPoint(x: 5, y: 10), time: 0)
        XCTAssertEqual(c.orbFrame.center.x, IslandMorphController.bezelSideMargin)
        c.dragChanged(translation: CGSize(width: 900, height: 0), location: CGPoint(x: 905, y: 10), time: 0.1)
        XCTAssertEqual(c.orbFrame.center.x, 820 - IslandMorphController.bezelSideMargin)
    }

    func testBezelNeckIsAWideUThatDoesNotReformAsTheOrbGrows() {
        let c = controller(island: .bezel)
        c.debugHold(pull: 200)
        let wide = c.neckBase
        XCTAssertGreaterThan(wide, IslandMorphController.neckWidth)
        XCTAssertEqual(wide, IslandMorphController.pullRadiusEnd * 2 * IslandMorphController.bezelNeckRatio,
                       accuracy: 1e-9)
    }

    func testIsHiddenAboveTheEdgeBeforeThePull() {
        let c = controller(island: .bezel)
        let frame = c.orbFrame
        XCTAssertLessThanOrEqual(frame.center.y + frame.diameter / 2, 0)
    }
}
