//
//  ExportFilesTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ExportFilesTests: XCTestCase {

    override func tearDown() {
        ExportFiles.removeAll()
        super.tearDown()
    }

    func testWriteStaysInsideExportDirectory() throws {
        let url = try ExportFiles.write(Data("x".utf8), baseName: "../../etc/passwd", ext: "svg")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL,
                       ExportFiles.directory.standardizedFileURL)
        XCTAssertEqual(url.pathExtension, "svg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testUnsafeOrEmptyNameFallsBackToPalette() throws {
        let url = try ExportFiles.write(Data(), baseName: "/:..", ext: "pdf")
        XCTAssertEqual(url.lastPathComponent, "palette.pdf")
    }

    func testUnicodeNameIsKept() throws {
        let url = try ExportFiles.write(Data(), baseName: "café-noir", ext: "ase")
        XCTAssertEqual(url.lastPathComponent, "café-noir.ase")
    }

    func testRemoveAllDeletesEverything() throws {
        let url = try ExportFiles.write(Data("x".utf8), baseName: "a", ext: "json")
        ExportFiles.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
