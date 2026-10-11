import Testing
import CoreGraphics
@testable import Palettes

@MainActor
struct PhotoPinGeometryTests {
    // A 200x100 image letterboxed in the middle of a 200x300 area.
    private let rect = CGRect(x: 0, y: 100, width: 200, height: 100)

    @Test func dragFollowsTheFingerOneToOne() {
        let moved = PhotoPinGeometry.moved(from: CGPoint(x: 0.5, y: 0.5), by: CGSize(width: 40, height: -10), in: rect)
        #expect(abs(moved.x - 0.7) < 0.0001)
        #expect(abs(moved.y - 0.4) < 0.0001)
    }

    @Test func dragClampsToTheImageRect() {
        let moved = PhotoPinGeometry.moved(from: CGPoint(x: 0.9, y: 0.1), by: CGSize(width: 500, height: -500), in: rect)
        #expect(moved == CGPoint(x: 1, y: 0))
        let other = PhotoPinGeometry.moved(from: CGPoint(x: 0.1, y: 0.9), by: CGSize(width: -500, height: 500), in: rect)
        #expect(other == CGPoint(x: 0, y: 1))
    }

    @Test func nudgeMovesFivePercentAndClamps() {
        #expect(abs(PhotoPinGeometry.nudged(CGPoint(x: 0.5, y: 0.3), by: 1).x - 0.55) < 0.0001)
        #expect(PhotoPinGeometry.nudged(CGPoint(x: 0.5, y: 0.3), by: -1).y == 0.3)
        #expect(PhotoPinGeometry.nudged(CGPoint(x: 0.98, y: 0.3), by: 1).x == 1)
        #expect(PhotoPinGeometry.nudged(CGPoint(x: 0.02, y: 0.3), by: -1).x == 0)
    }

    @Test func viewPositionMapsIntoTheImageRect() {
        let p = PhotoPinGeometry.position(of: CGPoint(x: 0.25, y: 0.5), in: rect)
        #expect(p == CGPoint(x: 50, y: 150))
    }
}
