//
//  SheetLayoutTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class SheetLayoutTests: XCTestCase {

    private func resolve(_ w: CGFloat, _ h: CGFloat, _ sc: UserInterfaceSizeClass?, min: CGFloat = 300) -> SheetLayout {
        SheetLayout.resolve(size: CGSize(width: w, height: h), horizontal: sc, minStackedHeight: min)
    }

    func testPhoneLandscapeIsSplit() { XCTAssertEqual(resolve(852, 393, .compact), .split) }
    func testPhonePortraitIsStacked() { XCTAssertEqual(resolve(393, 852, .compact), .stacked) }
    func testIPadLandscapeIsSplit() { XCTAssertEqual(resolve(1180, 820, .regular), .split) }
    func testIPadPortraitIsStacked() {
        XCTAssertEqual(resolve(820, 1180, .regular), .stacked)
        XCTAssertEqual(resolve(1024, 1366, .regular), .stacked)
    }
    func testRegularNearSquareIsSplit() { XCTAssertEqual(resolve(900, 1000, .regular), .split) }
    func testNarrowShortStaysStackedEvenWhenContentDoesNotFit() {
        XCTAssertEqual(resolve(380, 430, .compact, min: 520), .stacked)
        XCTAssertEqual(resolve(393, 852, .compact, min: 2000), .stacked)
    }
    func testWideShortSplitsViaWidthGreaterThanHeight() {
        XCTAssertEqual(resolve(700, 400, .compact, min: 300), .split)
    }
    func testWideEnoughPortraitTooShortIsSplit() {
        XCTAssertEqual(resolve(600, 650, .compact, min: 700), .split)
        XCTAssertEqual(resolve(599, 650, .compact, min: 700), .stacked)
    }
    func testDuoOuterPortraitStackedWhenContentFits() {
        XCTAssertEqual(resolve(380, 430, .compact, min: 300), .stacked)
    }
    func testHeightExactlyMinStackedHeightIsStacked() { XCTAssertEqual(resolve(393, 500, .compact, min: 500), .stacked) }
    func testRegularRatioExactlyThreeQuartersIsSplit() { XCTAssertEqual(resolve(750, 1000, .regular), .split) }
    func testNilSizeClassPortraitIsStacked() { XCTAssertEqual(resolve(393, 852, nil), .stacked) }
    func testSquareIsStacked() { XCTAssertEqual(resolve(500, 500, .compact), .stacked) }
    func testLargerMinStackedHeightFlipsBorderlineToSplit() {
        XCTAssertEqual(resolve(650, 700, .compact, min: 600), .stacked)
        XCTAssertEqual(resolve(650, 700, .compact, min: 800), .split)
    }

    // MARK: SheetMeasureTracker

    private func sz(_ w: CGFloat, _ h: CGFloat) -> CGSize { CGSize(width: w, height: h) }

    func testTrackerFirstReadingApplies() {
        var t = SheetMeasureTracker()
        XCTAssertEqual(t.apply(size: sz(393, 700), bottomInset: 34), sz(393, 700))
    }
    func testTrackerKeyboardShrinkIgnoredAndDismissRestores() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 700), bottomInset: 34)
        XCTAssertEqual(t.apply(size: sz(393, 400), bottomInset: 334), sz(393, 700))
        XCTAssertEqual(t.apply(size: sz(393, 700), bottomInset: 34), sz(393, 700))
        XCTAssertEqual(t.apply(size: sz(393, 650), bottomInset: 34), sz(393, 650))
    }
    func testTrackerWidthChangeResetsBaseline() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 700), bottomInset: 34)
        XCTAssertEqual(t.apply(size: sz(700, 393), bottomInset: 21), sz(700, 393))
        XCTAssertEqual(t.apply(size: sz(700, 150), bottomInset: 321), sz(700, 393))
    }
    func testTrackerWidthToleranceIgnoresSubPointJitter() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 700), bottomInset: 34)
        XCTAssertEqual(t.apply(size: sz(393.3, 400), bottomInset: 334), sz(393, 700))
    }
    func testTrackerHeightOnlyResizeWithUnchangedInsetApplies() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 700), bottomInset: 34)
        XCTAssertEqual(t.apply(size: sz(393, 500), bottomInset: 34), sz(393, 500))
    }
    func testTrackerSmallInsetIncreaseIsNotKeyboard() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 700), bottomInset: 34)
        XCTAssertEqual(t.apply(size: sz(393, 650), bottomInset: 84), sz(393, 650))
    }
    func testTrackerFirstMeasurementWithKeyboardUpEstimatesFullHeight() {
        var t = SheetMeasureTracker()
        XCTAssertEqual(t.apply(size: sz(393, 400), bottomInset: 334), sz(393, 700))
        // Further keyboard shrink ignored; dismiss gives the true size.
        XCTAssertEqual(t.apply(size: sz(393, 380), bottomInset: 354), sz(393, 700))
        XCTAssertEqual(t.apply(size: sz(393, 710), bottomInset: 34), sz(393, 710))
    }
    func testTrackerRotationWithKeyboardUpKeepsPortraitStacked() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 700), bottomInset: 34)
        // Rotation to a still-portrait-shaped width while the keyboard is up.
        let s = t.apply(size: sz(430, 520), bottomInset: 334)
        XCTAssertEqual(s, sz(430, 820))
        XCTAssertEqual(SheetLayout.resolve(size: s, horizontal: .compact, minStackedHeight: 600), .stacked)
    }
    func testTrackerTransientLowInsetDoesNotStickBaseline() {
        var t = SheetMeasureTracker()
        // Present animation reads inset 0; the host really has a 120pt inset bar.
        t.apply(size: sz(393, 800), bottomInset: 0)
        t.apply(size: sz(393, 800), bottomInset: 120)
        // A legitimate detent shrink must apply.
        XCTAssertEqual(t.apply(size: sz(393, 600), bottomInset: 120), sz(393, 600))
    }
    func testTrackerGrowthRebaselines() {
        var t = SheetMeasureTracker()
        t.apply(size: sz(393, 500), bottomInset: 0)
        t.apply(size: sz(393, 800), bottomInset: 120)
        XCTAssertEqual(t.apply(size: sz(393, 600), bottomInset: 120), sz(393, 600))
    }
}
