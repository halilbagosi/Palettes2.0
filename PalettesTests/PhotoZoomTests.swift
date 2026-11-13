//
//  PhotoZoomTests.swift
//  PalettesTests
//

import XCTest
import CoreGraphics
@testable import Palettes

final class PhotoZoomTests: XCTestCase {

    /// A landscape photo letterboxed in a portrait window.
    private let window = CGRect(x: 0, y: 0, width: 400, height: 800)
    private let base = CGRect(x: 0, y: 300, width: 400, height: 200)

    func testUnzoomedRectIsTheBaseRect() {
        XCTAssertEqual(PhotoZoom().rect(for: base), base)
    }

    func testPinchKeepsThePointUnderTheFingersInPlace() {
        var zoom = PhotoZoom()
        let finger = CGPoint(x: 100, y: 350)   // a quarter across, a quarter down the photo
        zoom.pinch(by: 2, from: finger, to: finger, base: base, window: window)
        let rect = zoom.rect(for: base)
        XCTAssertEqual(zoom.scale, 2, accuracy: 0.001)
        XCTAssertEqual(rect.minX + rect.width * 0.25, finger.x, accuracy: 0.001)
        // Still shorter than the window, so it stays vertically centered.
        XCTAssertEqual(rect.midY, window.midY, accuracy: 0.001)
    }

    func testMovingTheFingersPansAZoomedPhoto() {
        var zoom = PhotoZoom()
        let center = CGPoint(x: 200, y: 400)
        zoom.pinch(by: 6, from: center, to: center, base: base, window: window)
        zoom.pinch(by: 1, from: center, to: CGPoint(x: 150, y: 430), base: base, window: window)
        XCTAssertEqual(zoom.offset.width, -50, accuracy: 0.001)
        XCTAssertEqual(zoom.offset.height, 30, accuracy: 0.001)
    }

    func testPanStopsAtThePhotoEdge() {
        var zoom = PhotoZoom()
        let center = CGPoint(x: 200, y: 400)
        zoom.pinch(by: 2, from: center, to: center, base: base, window: window)
        zoom.pinch(by: 1, from: center, to: CGPoint(x: 5000, y: 400), base: base, window: window)
        XCTAssertEqual(zoom.rect(for: base).minX, window.minX, accuracy: 0.001)
    }

    func testScaleIsClampedAndPinchingOutResets() {
        var zoom = PhotoZoom()
        let finger = CGPoint(x: 90, y: 330)
        zoom.pinch(by: 100, from: finger, to: finger, base: base, window: window)
        XCTAssertEqual(zoom.scale, PhotoZoom.maxScale, accuracy: 0.001)
        zoom.pinch(by: 0.001, from: finger, to: finger, base: base, window: window)
        XCTAssertEqual(zoom, PhotoZoom())
    }

    func testOrbCameraZoomClamps() {
        XCTAssertEqual(OrbCameraZoom.factor(base: 2, magnification: 1.5, limit: 6), 3, accuracy: 0.001)
        XCTAssertEqual(OrbCameraZoom.factor(base: 2, magnification: 10, limit: 6), 6, accuracy: 0.001)
        XCTAssertEqual(OrbCameraZoom.factor(base: 2, magnification: 0.1, limit: 6), 1, accuracy: 0.001)
        XCTAssertEqual(OrbCameraZoom.limit(deviceMax: 123), OrbCameraZoom.maxFactor)
        XCTAssertEqual(OrbCameraZoom.limit(deviceMax: 0.5), 1)
    }
}
