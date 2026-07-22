//
//  PaletteExporterTests.swift
//  PalettesTests
//
//  Golden tests for PaletteExporter format generators.
//

import XCTest
import SwiftUI
import PDFKit
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

    func testSVGUsesDisplayNameEvenWhenRoleTagged() {
        // CRITICAL regression guard: SVG swatch labels must always be the
        // color's display name ("Ocean"), never the role ("Primary"), per
        // plans/010 line 93 ("SVG ... unaffected"). The pre-fix
        // slugSourcesAndHexes-driven implementation rendered the role here.
        let palette = PaletteViewModel(
            name: "Roled",
            colors: [.blue],
            hexCodes: ["#0077BE"],
            colorNames: ["Ocean"],
            colorRoles: ["Primary"]
        )
        let output = PaletteExporter.export(palette, as: .svg)
        XCTAssertTrue(output.contains(">Ocean<"), "SVG label must be the display name: \(output)")
        XCTAssertFalse(output.contains(">Primary<"), "SVG label must not be the role name: \(output)")
    }

    // MARK: - Slug collision

    private func collisionPalette() -> PaletteViewModel {
        PaletteViewModel(
            name: "Collisions",
            colors: [.blue, .red],
            hexCodes: ["#0000FF", "#FF0000"],
            colorNames: ["Sea", "Sea!"]
        )
    }

    func testSlugCollision() {
        let output = PaletteExporter.export(collisionPalette(), as: .css)
        XCTAssertTrue(output.contains("--sea: #0000FF;"))
        XCTAssertTrue(output.contains("--sea-2: #FF0000;"))
    }

    func testSlugCollisionSCSS() {
        let output = PaletteExporter.export(collisionPalette(), as: .scss)
        XCTAssertTrue(output.contains("$sea: #0000FF;"))
        XCTAssertTrue(output.contains("$sea-2: #FF0000;"))
    }

    func testSlugCollisionTailwind() {
        let output = PaletteExporter.export(collisionPalette(), as: .tailwind)
        XCTAssertTrue(output.contains("'sea': '#0000FF',"))
        XCTAssertTrue(output.contains("'sea-2': '#FF0000',"))
    }

    func testSlugCollisionSwiftUI() {
        let output = PaletteExporter.export(collisionPalette(), as: .swiftui)
        XCTAssertTrue(output.contains("static let sea = Color"))
        XCTAssertTrue(output.contains("static let sea2 = Color"))
    }

    // MARK: - Role-driven export names

    private func makeRolePalette() -> PaletteViewModel {
        PaletteViewModel(
            name: "Roled",
            colors: [.blue, .orange],
            hexCodes: ["#0077BE", "#C2B280"],
            colorNames: ["Ocean", "Sand"],
            colorRoles: ["Primary", ""]
        )
    }

    func testRoleDrivenCSS() {
        let expected = """
        :root {
          --primary: #0077BE;
          --sand: #C2B280;
        }
        """
        XCTAssertEqual(PaletteExporter.export(makeRolePalette(), as: .css), expected)
    }

    func testRoleDrivenSCSS() {
        let expected = """
        $primary: #0077BE;
        $sand: #C2B280;
        """
        XCTAssertEqual(PaletteExporter.export(makeRolePalette(), as: .scss), expected)
    }

    func testRoleDrivenTailwind() {
        let expected = """
        colors: {
          'primary': '#0077BE',
          'sand': '#C2B280',
        }
        """
        XCTAssertEqual(PaletteExporter.export(makeRolePalette(), as: .tailwind), expected)
    }

    func testRoleDrivenSwiftUI() {
        let expected = """
        extension Color {
            static let primary = Color(red: 0.000, green: 0.467, blue: 0.745) // #0077BE
            static let sand = Color(red: 0.761, green: 0.698, blue: 0.502) // #C2B280
        }
        """
        XCTAssertEqual(PaletteExporter.export(makeRolePalette(), as: .swiftui), expected)
    }

    func testRoleDrivenJSON() {
        // "name" stays the color's display name; a tagged color gains a
        // separate "role" field holding the slugified role. Untagged colors
        // omit the "role" field entirely.
        let expected = """
        [
          { "name": "Ocean", "role": "primary", "hex": "#0077BE" },
          { "name": "Sand", "hex": "#C2B280" }
        ]
        """
        XCTAssertEqual(PaletteExporter.export(makeRolePalette(), as: .json), expected)
    }

    func testJSONRoleFieldCollisionAmongTaggedColors() {
        // Two colors both tagged "Primary" must dedup through the shared
        // uniqueSlugs pass, same as CSS/SCSS/etc, yielding primary / primary-2
        // in the "role" fields.
        let palette = PaletteViewModel(
            name: "RoleRoleCollision",
            colors: [.blue, .cyan],
            hexCodes: ["#0077BE", "#00AACC"],
            colorNames: ["Ocean", "Sky"],
            colorRoles: ["Primary", "Primary"]
        )
        let expected = """
        [
          { "name": "Ocean", "role": "primary", "hex": "#0077BE" },
          { "name": "Sky", "role": "primary-2", "hex": "#00AACC" }
        ]
        """
        XCTAssertEqual(PaletteExporter.export(palette, as: .json), expected)
    }

    func testJSONRoleFieldOmittedWhenRoleCollidesWithUntaggedName() {
        // Role "Primary" collides with a second, untagged color literally
        // named "Primary". The tagged color's role field still resolves to
        // "primary"; the untagged color gets no "role" field at all (its
        // name-derived slug is irrelevant to JSON).
        let palette = PaletteViewModel(
            name: "RoleNameCollision",
            colors: [.blue, .red],
            hexCodes: ["#0000FF", "#FF0000"],
            colorNames: ["Ocean", "Primary"],
            colorRoles: ["Primary", ""]
        )
        let expected = """
        [
          { "name": "Ocean", "role": "primary", "hex": "#0000FF" },
          { "name": "Primary", "hex": "#FF0000" }
        ]
        """
        XCTAssertEqual(PaletteExporter.export(palette, as: .json), expected)
    }

    func testRoleNameSlugCollision() {
        // A color tagged with role "Primary" alongside a different color
        // literally *named* "Primary" (untagged) must collide and dedup.
        let palette = PaletteViewModel(
            name: "RoleCollision",
            colors: [.blue, .red],
            hexCodes: ["#0000FF", "#FF0000"],
            colorNames: ["Ocean", "Primary"],
            colorRoles: ["Primary", ""]
        )
        let output = PaletteExporter.export(palette, as: .css)
        XCTAssertTrue(output.contains("--primary: #0000FF;"))
        XCTAssertTrue(output.contains("--primary-2: #FF0000;"))
    }

    // MARK: - Untagged-format regression (role must not affect these)

    func testRolePresentDoesNotAffectPlainHexSVGOrCoolors() {
        // Using the original (role-free) test palette, plainHex/SVG/Coolors
        // output must remain byte-identical to pre-change behavior.
        let palette = makePalette()
        XCTAssertEqual(PaletteExporter.export(palette, as: .plainHex), "#1B4D1B\n#99FA99\n#333333")
        XCTAssertEqual(PaletteExporter.export(palette, as: .coolorsURL), "https://coolors.co/1b4d1b-99fa99-333333")
        let svgExpected = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"300\" height=\"140\" viewBox=\"0 0 300 140\">"
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
        XCTAssertEqual(PaletteExporter.export(palette, as: .svg), svgExpected)
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

    // MARK: - ASE

    func testASEGoldenBytes() {
        let palette = PaletteViewModel(
            name: "Reds",
            colors: [.red],
            hexCodes: ["#FF0000"],
            colorNames: ["Red"]
        )

        // "Red" = 3 chars + null terminator = nameLength 4 (UTF-16 code units).
        // blockLength = 2 (nameLength field) + 4*2 (name UTF-16BE) + 4 ("RGB ") + 12 (3 floats) + 2 (colorType) = 28
        let expected: [UInt8] = [
            0x41, 0x53, 0x45, 0x46,             // "ASEF"
            0x00, 0x01,                         // version major = 1
            0x00, 0x00,                         // version minor = 0
            0x00, 0x00, 0x00, 0x01,             // block count = 1
            0x00, 0x01,                         // block type = 0x0001 (color entry)
            0x00, 0x00, 0x00, 0x1C,             // block length = 28
            0x00, 0x04,                         // name length = 4 (UTF-16 units incl. null)
            0x00, 0x52,                         // 'R'
            0x00, 0x65,                         // 'e'
            0x00, 0x64,                         // 'd'
            0x00, 0x00,                         // null terminator
            0x52, 0x47, 0x42, 0x20,             // "RGB "
            0x3F, 0x80, 0x00, 0x00,             // r = 1.0 (Float32 BE)
            0x00, 0x00, 0x00, 0x00,             // g = 0.0
            0x00, 0x00, 0x00, 0x00,             // b = 0.0
            0x00, 0x02                          // color type = 0x0002 (normal)
        ]

        let data = PaletteExporter.aseData(palette)
        XCTAssertEqual(Array(data), expected)
    }

    /// Decodes the null-terminated UTF-16BE color name from an ASE color
    /// block, given the 12-byte header + block-type/length/name-length
    /// preamble is fixed-size at the start of a single-color ASE payload.
    private func decodeASEFirstColorName(_ data: Data) -> String {
        let bytes = Array(data)
        // offsets: 0-11 header, 12-13 block type, 14-17 block length, 18-19 name length
        let nameLength = Int(bytes[18]) << 8 | Int(bytes[19])
        var units: [UInt16] = []
        var offset = 20
        for _ in 0..<nameLength {
            let unit = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
            units.append(unit)
            offset += 2
        }
        if units.last == 0 { units.removeLast() } // drop null terminator
        return String(decoding: units, as: UTF16.self)
    }

    func testASEUsesDisplayNameEvenWhenRoleTagged() {
        // IMPORTANT: ASE swatch names are design-tool labels; a role-tagged
        // color must still export its display name ("Ocean"), not the role
        // ("Primary").
        let palette = PaletteViewModel(
            name: "Roled",
            colors: [.blue],
            hexCodes: ["#0077BE"],
            colorNames: ["Ocean"],
            colorRoles: ["Primary"]
        )
        let data = PaletteExporter.aseData(palette)
        XCTAssertEqual(decodeASEFirstColorName(data), "Ocean")
    }

    // MARK: - PDF

    @MainActor
    func testPDFDataIsValidPDF() {
        let data = PaletteExporter.pdfData(makePalette())
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }

    @MainActor
    func testPDFUsesDisplayNameEvenWhenRoleTagged() {
        // IMPORTANT: PDF swatch labels are design-tool labels; a role-tagged
        // color must still export its display name ("Ocean"), not the role
        // ("Primary").
        let palette = PaletteViewModel(
            name: "Roled",
            colors: [.blue],
            hexCodes: ["#0077BE"],
            colorNames: ["Ocean"],
            colorRoles: ["Primary"]
        )
        let data = PaletteExporter.pdfData(palette)
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else {
            XCTFail("Could not parse generated PDF")
            return
        }
        let text = page.string ?? ""
        XCTAssertTrue(text.contains("Ocean"), "PDF text should contain display name: \(text)")
        XCTAssertFalse(text.contains("Primary"), "PDF text should not contain role name: \(text)")
    }
}
