import Testing
import CoreGraphics
@testable import Palettes

@MainActor
struct ScanPickerGeometryTests {
    // A 200x100 photo letterboxed in the middle of a 200x180 area.
    private let rect = CGRect(x: 0, y: 40, width: 200, height: 100)

    @Test func touchMapsToTheImagePointUnderIt() {
        let p = ScanPickerGeometry.point(at: CGPoint(x: 50, y: 90), in: rect)
        #expect(abs(p.x - 0.25) < 0.0001)
        #expect(abs(p.y - 0.5) < 0.0001)
    }

    @Test func touchesInTheLetterboxClampToTheImageEdge() {
        #expect(ScanPickerGeometry.point(at: CGPoint(x: 100, y: 0), in: rect) == CGPoint(x: 0.5, y: 0))
        #expect(ScanPickerGeometry.point(at: CGPoint(x: 100, y: 180), in: rect) == CGPoint(x: 0.5, y: 1))
        #expect(ScanPickerGeometry.point(at: CGPoint(x: -30, y: 90), in: rect) == CGPoint(x: 0, y: 0.5))
    }

    @Test func aTouchNearTheMarkerGrabsItAndOneFarAwayDoesNot() {
        let marker = CGPoint(x: 0.5, y: 0.5) // view (100, 90)
        #expect(ScanPickerGeometry.grabsMarker(at: CGPoint(x: 110, y: 100), marker: marker, in: rect))
        #expect(!ScanPickerGeometry.grabsMarker(at: CGPoint(x: 140, y: 90), marker: marker, in: rect))
    }
}
