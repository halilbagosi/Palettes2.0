import Testing
import CoreGraphics
@testable import Palettes

@MainActor
struct ScanPickerGeometryTests {
    // A 200x100 photo filling a 180x180 area: scaled 1.8x to 360x180, so 90 pt
    // are cropped off each side.
    private let view = CGSize(width: 180, height: 180)
    private var fill: CGRect { ScanPickerGeometry.fillRect(imageSize: CGSize(width: 200, height: 100), in: view) }
    private var visible: CGRect { ScanPickerGeometry.visibleRect(fill: fill, in: view) }

    @Test func fillRectCoversTheViewAndCropsTheLongAxis() {
        #expect(fill == CGRect(x: -90, y: 0, width: 360, height: 180))
        #expect(visible == CGRect(x: 0, y: 0, width: 180, height: 180))
        // Portrait photo: the crop is top and bottom.
        let portrait = ScanPickerGeometry.fillRect(imageSize: CGSize(width: 100, height: 200), in: view)
        #expect(portrait == CGRect(x: 0, y: -90, width: 180, height: 360))
    }

    @Test func touchMapsToTheImagePointUnderIt() {
        // View x 45 is 135 pt into the 360 pt-wide fill rect.
        let p = ScanPickerGeometry.point(at: CGPoint(x: 45, y: 90), fill: fill, visible: visible)
        #expect(abs(p.x - 0.375) < 0.0001)
        #expect(abs(p.y - 0.5) < 0.0001)
    }

    @Test func touchesOutsideTheVisibleRectClampToItsEdge() {
        // The visible left edge is 25% across the image, the right edge 75%.
        let left = ScanPickerGeometry.point(at: CGPoint(x: -60, y: 200), fill: fill, visible: visible)
        #expect(abs(left.x - 0.25) < 0.0001)
        #expect(left.y == 1)
        let right = ScanPickerGeometry.point(at: CGPoint(x: 500, y: -10), fill: fill, visible: visible)
        #expect(abs(right.x - 0.75) < 0.0001)
        #expect(right.y == 0)
    }

    @Test func pointAndViewPositionRoundTripUnderFill() {
        for p in [CGPoint(x: 0.3, y: 0.2), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.7, y: 0.9)] {
            let position = PhotoPinGeometry.position(of: p, in: fill)
            let back = ScanPickerGeometry.point(at: position, fill: fill, visible: visible)
            #expect(abs(back.x - p.x) < 0.0001 && abs(back.y - p.y) < 0.0001)
        }
    }

    @Test func aStartingPointInTheCroppedPartIsPulledIntoView() {
        let cropped = ScanPickerGeometry.clampedIntoVisible(CGPoint(x: 0.05, y: 0.4), fill: fill, visible: visible)
        #expect(abs(cropped.x - 0.25) < 0.0001)
        #expect(abs(cropped.y - 0.4) < 0.0001)
        let shown = CGPoint(x: 0.6, y: 0.4)
        #expect(ScanPickerGeometry.clampedIntoVisible(shown, fill: fill, visible: visible) == shown)
    }

    @Test func dragFollowsTheFingerAndStopsAtTheVisibleEdge() {
        let moved = ScanPickerGeometry.moved(from: CGPoint(x: 0.5, y: 0.5), by: CGSize(width: 36, height: 0), fill: fill, visible: visible)
        #expect(abs(moved.x - 0.6) < 0.0001) // 36 / 360
        let pinned = ScanPickerGeometry.moved(from: CGPoint(x: 0.5, y: 0.5), by: CGSize(width: 900, height: -900), fill: fill, visible: visible)
        #expect(abs(pinned.x - 0.75) < 0.0001)
        #expect(pinned.y == 0)
    }

    @Test func aTouchNearTheMarkerGrabsItAndOneFarAwayDoesNot() {
        let marker = CGPoint(x: 0.5, y: 0.5) // view (90, 90)
        #expect(ScanPickerGeometry.grabsMarker(at: CGPoint(x: 100, y: 100), marker: marker, fill: fill))
        #expect(!ScanPickerGeometry.grabsMarker(at: CGPoint(x: 140, y: 90), marker: marker, fill: fill))
    }
}
