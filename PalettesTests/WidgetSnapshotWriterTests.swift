//
//  WidgetSnapshotWriterTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

@MainActor
final class WidgetSnapshotWriterTests: XCTestCase {

    private var url: URL!
    private var reloads = 0

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("writer-\(UUID().uuidString).json")
        reloads = 0
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    private func makeWriter() -> WidgetSnapshotWriter {
        WidgetSnapshotWriter(url: url, reload: { [unowned self] in self.reloads += 1 })
    }

    private let palettes = [
        PaletteViewModel(name: "Sea", paletteColors: [
            PaletteColor(color: .blue, hex: "#1A73A8", name: "Deep"),
            PaletteColor(color: .cyan, hex: "#7FC8F8", name: "Shallow"),
        ], isFavorite: true),
        PaletteViewModel(name: "Dusk", paletteColors: [
            PaletteColor(color: .purple, hex: "#2B1B3D", name: "Night"),
        ]),
    ]

    private let colors = [
        ColorViewModel(name: "Ink", color: .black, HEX: "#111111", usedInPalette: false),
        ColorViewModel(name: "Sun", color: .yellow, HEX: "#FFD60A", usedInPalette: true, isFavorite: true),
    ]

    func testSnapshotKeepsLibraryOrderAndFavorites() {
        let snapshot = WidgetSnapshotWriter.snapshot(palettes: palettes, colors: colors)
        XCTAssertEqual(snapshot.palettes.map(\.name), ["Sea", "Dusk"])
        XCTAssertEqual(snapshot.palettes.map(\.isFavorite), [true, false])
        XCTAssertEqual(snapshot.palettes[0].hexCodes, ["#1A73A8", "#7FC8F8"])
        XCTAssertEqual(snapshot.palettes[0].colorNames, ["Deep", "Shallow"])
        XCTAssertEqual(snapshot.palettes[0].id, palettes[0].id)
        XCTAssertEqual(snapshot.colors.map(\.hex), ["#111111", "#FFD60A"])
        XCTAssertEqual(snapshot.colors.map(\.isFavorite), [false, true])
    }

    func testWritesAndReloadsOnFirstUpdate() {
        let writer = makeWriter()
        XCTAssertTrue(writer.update(palettes: palettes, colors: colors))
        XCTAssertEqual(reloads, 1)
        XCTAssertEqual(WidgetSnapshotStore.read(from: url).palettes.count, 2)
    }

    func testSkipsAnUnchangedSnapshot() {
        let writer = makeWriter()
        writer.update(palettes: palettes, colors: colors)
        XCTAssertFalse(writer.update(palettes: palettes, colors: colors))
        XCTAssertEqual(reloads, 1)
    }

    /// PaletteViewModel's == compares ids only; the writer must still see
    /// a rename.
    func testWritesAgainAfterARename() {
        let writer = makeWriter()
        writer.update(palettes: palettes, colors: colors)
        var renamed = palettes
        renamed[0].name = "Ocean"
        XCTAssertTrue(writer.update(palettes: renamed, colors: colors))
        XCTAssertEqual(reloads, 2)
        XCTAssertEqual(WidgetSnapshotStore.read(from: url).palettes[0].name, "Ocean")
    }

    func testFailedWriteIsRetriedNextTime() {
        let writer = WidgetSnapshotWriter(url: nil, reload: { [unowned self] in self.reloads += 1 })
        XCTAssertFalse(writer.update(palettes: palettes, colors: colors))
        XCTAssertFalse(writer.update(palettes: palettes, colors: colors))
        XCTAssertEqual(reloads, 0)
    }
}
