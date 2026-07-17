//
//  PaletteExporterTests.swift
//  PalettesTests
//
//  Golden tests for PaletteExporter format generators.
//

import XCTest
import SwiftUI
@testable import Palettes

final class PaletteExporterTests: XCTestCase {

    private func makePalette() -> PaletteViewModel {
        PaletteViewModel(
            name: "Forest Floor",
            colors: [.green, .green, .black],
            hexCodes: ["#1B4D1B", "#99FA99", "#333333"],
            colorNames: ["Forest Green", "Pastel Mint", "Charcoal"]
        )
    }

    private func emptyPalette() -> PaletteViewModel {
        PaletteViewModel(name: "Empty", colors: [], hexCodes: [], colorNames: [])
    }

    // MARK: - CSS

    func testCSS() {
        let expected = """
        :root {
          --forest-green: #1B4D1B;
          --pastel-mint: #99FA99;
          --charcoal: #333333;
        }
        """
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .css), expected)
    }

    // MARK: - SCSS

    func testSCSS() {
        let expected = """
        $forest-green: #1B4D1B;
        $pastel-mint: #99FA99;
        $charcoal: #333333;
        """
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .scss), expected)
    }

    // MARK: - SwiftUI

    func testSwiftUI() {
        let expected = """
        extension Color {
            static let forestGreen = Color(red: 0.106, green: 0.302, blue: 0.106) // #1B4D1B
            static let pastelMint = Color(red: 0.600, green: 0.980, blue: 0.600) // #99FA99
            static let charcoal = Color(red: 0.200, green: 0.200, blue: 0.200) // #333333
        }
        """
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .swiftui), expected)
    }

    // MARK: - Tailwind

    func testTailwind() {
        let expected = """
        colors: {
          'forest-green': '#1B4D1B',
          'pastel-mint': '#99FA99',
          'charcoal': '#333333',
        }
        """
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .tailwind), expected)
    }

    // MARK: - JSON

    func testJSON() {
        let expected = """
        [
          { "name": "Forest Green", "hex": "#1B4D1B" },
          { "name": "Pastel Mint", "hex": "#99FA99" },
          { "name": "Charcoal", "hex": "#333333" }
        ]
        """
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .json), expected)
    }

    // MARK: - Plain hex

    func testPlainHex() {
        let expected = "#1B4D1B\n#99FA99\n#333333"
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .plainHex), expected)
    }

    // MARK: - Coolors URL

    func testCoolorsURL() {
        let expected = "https://coolors.co/1b4d1b-99fa99-333333"
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .coolorsURL), expected)
    }

    // MARK: - SVG

    func testSVG() {
        let expected = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"300\" height=\"140\" viewBox=\"0 0 300 140\">"
        + "<rect x=\"0\" y=\"0\" width=\"100\" height=\"100\" fill=\"#1B4D1B\"/>"
        + "<text x=\"50\" y=\"118\" text-anchor=\"middle\" font-family=\"-apple-system, sans-serif\" font-size=\"10\">Forest Green</text>"
        + "<text x=\"50\" y=\"132\" text-anchor=\"middle\" font-family=\"ui-monospace, monospace\" font-size=\"9\">#1B4D1B</text>"
        + "<rect x=\"100\" y=\"0\" width=\"100\" height=\"100\" fill=\"#99FA99\"/>"
        + "<text x=\"150\" y=\"118\" text-anchor=\"middle\" font-family=\"-apple-system, sans-serif\" font-size=\"10\">Pastel Mint</text>"
        + "<text x=\"150\" y=\"132\" text-anchor=\"middle\" font-family=\"ui-monospace, monospace\" font-size=\"9\">#99FA99</text>"
        + "<rect x=\"200\" y=\"0\" width=\"100\" height=\"100\" fill=\"#333333\"/>"
        + "<text x=\"250\" y=\"118\" text-anchor=\"middle\" font-family=\"-apple-system, sans-serif\" font-size=\"10\">Charcoal</text>"
        + "<text x=\"250\" y=\"132\" text-anchor=\"middle\" font-family=\"ui-monospace, monospace\" font-size=\"9\">#333333</text>"
        + "</svg>"
        XCTAssertEqual(PaletteExporter.export(makePalette(), as: .svg), expected)
    }

    // MARK: - Slug collision

    func testSlugCollision() {
        let palette = PaletteViewModel(
            name: "Collisions",
            colors: [.blue, .red],
            hexCodes: ["#0000FF", "#FF0000"],
            colorNames: ["Sea", "Sea!"]
        )
        let output = PaletteExporter.export(palette, as: .css)
        XCTAssertTrue(output.contains("--sea: #0000FF;"))
        XCTAssertTrue(output.contains("--sea-2: #FF0000;"))
    }

    // MARK: - XML escape

    func testXMLEscapeInSVG() {
        let palette = PaletteViewModel(
            name: "Escaped",
            colors: [.blue],
            hexCodes: ["#0000FF"],
            colorNames: ["A&B <x>"]
        )
        let output = PaletteExporter.export(palette, as: .svg)
        XCTAssertTrue(output.contains("A&amp;B &lt;x&gt;"))
    }

    // MARK: - Empty palette

    func testEmptyPaletteAllFormats() {
        let palette = emptyPalette()
        XCTAssertEqual(PaletteExporter.export(palette, as: .css), ":root {\n}")
        XCTAssertEqual(PaletteExporter.export(palette, as: .scss), "")
        XCTAssertEqual(PaletteExporter.export(palette, as: .swiftui), "extension Color {\n}")
        XCTAssertEqual(PaletteExporter.export(palette, as: .tailwind), "colors: {\n}")
        XCTAssertEqual(PaletteExporter.export(palette, as: .json), "[]")
        XCTAssertEqual(PaletteExporter.export(palette, as: .plainHex), "")
        XCTAssertEqual(PaletteExporter.export(palette, as: .coolorsURL), "https://coolors.co/")
        XCTAssertEqual(
            PaletteExporter.export(palette, as: .svg),
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0\" height=\"140\" viewBox=\"0 0 0 140\"></svg>"
        )
    }
}
