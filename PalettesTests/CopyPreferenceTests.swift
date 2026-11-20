import XCTest
import SwiftUI
@testable import Palettes

@MainActor
final class CopyPreferenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "CopyPreferenceTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func palette() -> PaletteViewModel {
        PaletteViewModel(
            name: "Test",
            colors: [Color(hex: "#FF0000")!, Color(hex: "#00FF00")!],
            hexCodes: ["#FF0000", "#00FF00"],
            colorNames: ["Red", "Green"]
        )
    }

    func testUnsetByDefault() {
        XCTAssertNil(CopyPreference.colorFormat(in: defaults))
        XCTAssertNil(CopyPreference.paletteFormat(in: defaults))
    }

    func testRoundTripAndClear() {
        for format in ColorCopyFormat.allCases {
            CopyPreference.setColorFormat(format, in: defaults)
            XCTAssertEqual(CopyPreference.colorFormat(in: defaults), format)
        }
        for format in PaletteCopyFormat.allCases {
            CopyPreference.setPaletteFormat(format, in: defaults)
            XCTAssertEqual(CopyPreference.paletteFormat(in: defaults), format)
        }
        CopyPreference.setColorFormat(nil, in: defaults)
        CopyPreference.setPaletteFormat(nil, in: defaults)
        XCTAssertNil(CopyPreference.colorFormat(in: defaults))
        XCTAssertNil(CopyPreference.paletteFormat(in: defaults))
    }

    func testColorText() {
        let color = Color(hex: "#FF0000")!
        XCTAssertEqual(CopyPreference.text(hex: "#FF0000", color: color, as: .hex), "#FF0000")
        XCTAssertEqual(CopyPreference.text(hex: "#FF0000", color: color, as: .rgb), "R: 255 G: 0 B: 0")
    }

    func testPaletteTextPerFormat() {
        let p = palette()
        XCTAssertEqual(CopyPreference.text(for: p, as: .hex), "#FF0000, #00FF00")
        XCTAssertEqual(CopyPreference.text(for: p, as: .rgb), "R: 255 G: 0 B: 0 | R: 0 G: 255 B: 0")
        XCTAssertEqual(CopyPreference.text(for: p, as: .css), PaletteExporter.export(p, as: .css))
        XCTAssertEqual(CopyPreference.text(for: p, as: .scss), PaletteExporter.export(p, as: .scss))
        XCTAssertEqual(CopyPreference.text(for: p, as: .swiftui), PaletteExporter.export(p, as: .swiftui))
        XCTAssertEqual(CopyPreference.text(for: p, as: .tailwind), PaletteExporter.export(p, as: .tailwind))
        XCTAssertEqual(CopyPreference.text(for: p, as: .json), PaletteExporter.export(p, as: .json))
        XCTAssertEqual(CopyPreference.text(for: p, as: .coolorsURL), PaletteExporter.export(p, as: .coolorsURL))
        for format in PaletteCopyFormat.allCases {
            XCTAssertFalse(CopyPreference.text(for: p, as: format).isEmpty, format.displayName)
        }
    }

    func testWidgetCopyFallsBackToHexWhenUnset() {
        let p = palette()
        let unset = CopyPreference.widgetPaletteText(p, in: defaults)
        XCTAssertEqual(unset.text, "#FF0000, #00FF00")
        XCTAssertEqual(unset.label, "Copied HEX")
        let color = CopyPreference.widgetColorText(hex: "#FF0000", color: .red, in: defaults)
        XCTAssertEqual(color.text, "#FF0000")
        XCTAssertEqual(color.label, "Copied HEX")
    }

    func testWidgetCopyHonorsSavedFormat() {
        let p = palette()
        CopyPreference.setPaletteFormat(.css, in: defaults)
        let copy = CopyPreference.widgetPaletteText(p, in: defaults)
        XCTAssertEqual(copy.text, PaletteExporter.export(p, as: .css))
        XCTAssertEqual(copy.label, "Copied CSS")
    }
}
