import XCTest
@testable import Palettes

final class IslandGeometryTests: XCTestCase {
    private let portrait = CGSize(width: 402, height: 874)

    func testDynamicIslandAtInset62() {
        let g = IslandGeometry.make(topInset: 62, screenSize: portrait)
        XCTAssertEqual(g.kind, .dynamicIsland)
        XCTAssertEqual(g.width, 84)
        XCTAssertEqual(g.height, 34)
        XCTAssertEqual(g.top, 17)
        XCTAssertEqual(g.bottom, 51)
    }

    func testIslandBottomFollowsTheInset() {
        // 14 Pro to 16 Plus (59), 16 Pro to 18 Pro Max (62), and the Air's lower island (68).
        for inset in [59.0, 62, 68] {
            let g = IslandGeometry.make(topInset: inset, screenSize: CGSize(width: 420, height: 912))
            XCTAssertEqual(g.kind, .dynamicIsland, "inset \(inset)")
            XCTAssertEqual(g.bottom, inset - 11, "inset \(inset)")
        }
    }

    func testNotchBetween44And58() {
        for inset in [44.0, 47, 48, 50] {
            let g = IslandGeometry.make(topInset: inset, screenSize: CGSize(width: 390, height: 844))
            XCTAssertEqual(g.kind, .notch, "inset \(inset)")
            XCTAssertEqual(g.width, 84)
            XCTAssertEqual(g.top, 0)
            XCTAssertEqual(g.bottom, inset - 14, "inset \(inset)")
        }
    }

    func testEveryCutoutIsDrawnAtTheSmallestCutoutsWidth() {
        for size in IslandGeometry.centeredCutoutSizes {
            let screen = CGSize(width: size.width, height: size.height)
            for inset in [47.0, 62] {
                let rect = IslandGeometry.make(topInset: inset, screenSize: screen).drawnRect(screenWidth: screen.width)
                XCTAssertEqual(rect.width, 82, "\(size) inset \(inset)")
                XCTAssertEqual(rect.midX, screen.width / 2, "\(size) inset \(inset)")
            }
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

    func testIPadWindowPullsFromItsTopEdge() {
        // iPadOS runs apps in resizable windows, even when one fills the screen.
        let window = IslandGeometry.make(topInset: 24, screenSize: CGSize(width: 700, height: 600))
        XCTAssertEqual(window.kind, .bezel)
        XCTAssertTrue(window.hasMorph)
        XCTAssertFalse(IslandGeometry.none.hasMorph)
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
        let hardware = CGRect(x: (402.0 - 84) / 2, y: 17, width: 84, height: 34)
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
        XCTAssertEqual(rect.maxY, 32)
        XCTAssertEqual(rect.midX, 195)
        XCTAssertEqual(rect.width, 82)
    }

    func testIslandAndNotchShareTheirFlatBottom() {
        let island = IslandGeometry.make(topInset: 62, screenSize: portrait)
        let notch = IslandGeometry.make(topInset: 47, screenSize: CGSize(width: 390, height: 844))
        XCTAssertEqual(island.drawnFlatHalfWidth, 25)
        XCTAssertEqual(notch.drawnFlatHalfWidth, 25)
        XCTAssertEqual(IslandGeometry.bezel.drawnFlatHalfWidth, 0)
    }

    private func neck(depth: CGFloat, diameter: CGFloat, waist: CGFloat = 34) -> IslandGooCanvas.NeckOutline? {
        IslandGooCanvas.neckOutline(
            centerX: 100, junction: 50, tuckTop: 36,
            blob: .init(center: CGPoint(x: 100, y: 50 + depth), diameter: diameter),
            waist: waist, reach: 27)
    }

    @MainActor
    func testNeckMeetsTheCutoutWithinItsReach() {
        // From a drop tucked into the cutout to one hanging far below it.
        for depth in stride(from: -10.0, through: 120, by: 5) {
            for waist in [34.0, 20, 6] {
                guard let outline = neck(depth: depth, diameter: 47, waist: waist) else { continue }
                let bounds = outline.path.boundingRect
                XCTAssertLessThanOrEqual(bounds.maxX, 127 + 1e-6, "depth \(depth) waist \(waist)")
                XCTAssertGreaterThanOrEqual(bounds.minX, 73 - 1e-6, "depth \(depth) waist \(waist)")
                XCTAssertGreaterThanOrEqual(outline.filletRadius, 0)
                XCTAssertLessThanOrEqual(outline.filletRadius, IslandGooCanvas.maxFilletRadius)
            }
        }
    }

    @MainActor
    func testNeckRunsIntoTheDropsOutline() {
        // Long neck: a rod with fillets, ending on the drop's circle.
        let outline = try! XCTUnwrap(neck(depth: 90, diameter: 60))
        let bounds = outline.path.boundingRect
        XCTAssertLessThanOrEqual(bounds.maxY, 140 + 1e-6)
        XCTAssertEqual(bounds.minY, 36, accuracy: 1e-6)
        // The rod's middle is the waist.
        XCTAssertTrue(outline.path.contains(CGPoint(x: 100 + 16.5, y: 85)))
        XCTAssertFalse(outline.path.contains(CGPoint(x: 100 + 17.5, y: 85)))
    }

    @MainActor
    func testNeckVanishesAsItPinchesOff() {
        XCTAssertNil(neck(depth: 60, diameter: 47, waist: 0))
        let thread = try! XCTUnwrap(neck(depth: 60, diameter: 47, waist: 1))
        XCTAssertLessThan(thread.filletRadius, 0.5)
    }

    @MainActor
    func testFadeIsSolidThenEasedToClear() {
        let stops = IslandGooCanvas.fadeStops(from: 0.2, to: 0.6)
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.last?.location, 1)
        let locations = stops.map(\.location)
        XCTAssertEqual(locations, locations.sorted())
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

    func testCutoutNeckSnapsSoonAfterTheDropClearsIt() {
        let c = controller(island: .make(topInset: 59, screenSize: CGSize(width: 393, height: 852)), width: 393)
        XCTAssertEqual(c.currentNeckReach, IslandMorphController.cutoutNeckReach)
        XCTAssertLessThan(IslandMorphController.snapGap(reach: c.currentNeckReach), IslandMorphController.snapGap())
        XCTAssertEqual(controller(island: .bezel).currentNeckReach, IslandMorphController.neckReach)
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
