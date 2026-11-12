//
//  WidgetSnapshotTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class WidgetSnapshotTests: XCTestCase {

    private var url: URL!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-snapshot-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    private func sample() -> WidgetSnapshot {
        WidgetSnapshot(
            palettes: [
                .init(id: UUID(), name: "Sea", hexCodes: ["#1A73A8", "#7FC8F8"], colorNames: ["Deep", "Shallow"], isFavorite: true),
                .init(id: UUID(), name: "Dusk", hexCodes: ["#2B1B3D"], colorNames: ["Night"], isFavorite: false),
            ],
            colors: [
                .init(id: UUID(), name: "Ink", hex: "#111111", isFavorite: false),
                .init(id: UUID(), name: "Sun", hex: "#FFD60A", isFavorite: true),
            ]
        )
    }

    func testRoundTripsThroughTheFile() {
        let snapshot = sample()
        XCTAssertTrue(WidgetSnapshotStore.write(snapshot, to: url))
        let read = WidgetSnapshotStore.read(from: url)
        XCTAssertEqual(read, snapshot)
        XCTAssertEqual(read.palettes[0].colorNames, ["Deep", "Shallow"])
    }

    func testMissingFileReadsAsEmpty() {
        XCTAssertEqual(WidgetSnapshotStore.read(from: url), .empty)
        XCTAssertEqual(WidgetSnapshotStore.read(from: nil), .empty)
    }

    func testCorruptDataReadsAsEmpty() {
        XCTAssertEqual(WidgetSnapshotStore.decode(Data("not json".utf8)), .empty)
    }

    func testUnknownVersionReadsAsEmpty() throws {
        var snapshot = sample()
        XCTAssertEqual(WidgetSnapshot.currentVersion, 2)
        snapshot.version = WidgetSnapshot.currentVersion + 1
        let data = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(WidgetSnapshotStore.decode(data), .empty)
    }

    func testWriteWithoutURLFails() {
        XCTAssertFalse(WidgetSnapshotStore.write(sample(), to: nil))
    }

    func testFavoritesAndLookups() {
        let snapshot = sample()
        XCTAssertEqual(snapshot.favoritePalettes.map(\.name), ["Sea"])
        XCTAssertEqual(snapshot.defaultColor?.name, "Sun")
        XCTAssertEqual(snapshot.palette(id: snapshot.palettes[1].id)?.name, "Dusk")
        XCTAssertEqual(snapshot.color(id: snapshot.colors[0].id)?.name, "Ink")
        XCTAssertNil(snapshot.palette(id: UUID()))
    }

    func testFavoriteColorsKeepLibraryOrder() {
        let snapshot = WidgetSnapshot(colors: [
            .init(id: UUID(), name: "A", hex: "#111111", isFavorite: true),
            .init(id: UUID(), name: "B", hex: "#222222", isFavorite: false),
            .init(id: UUID(), name: "C", hex: "#333333", isFavorite: true),
        ])
        XCTAssertEqual(snapshot.favoriteColors.map(\.name), ["A", "C"])
        XCTAssertTrue(WidgetSnapshot.empty.favoriteColors.isEmpty)
    }

    func testDefaultColorFallsBackToFirstColor() {
        var snapshot = sample()
        snapshot.colors[1].isFavorite = false
        XCTAssertEqual(snapshot.defaultColor?.name, "Ink")
        XCTAssertNil(WidgetSnapshot.empty.defaultColor)
    }

    func testPaletteCopyTextMatchesTheAppsPlainHexExport() {
        let palette = PaletteViewModel(
            name: "Sea",
            paletteColors: [
                PaletteColor(color: .blue, hex: "#1A73A8", name: "Deep"),
                PaletteColor(color: .cyan, hex: "#7FC8F8", name: "Shallow"),
            ]
        )
        XCTAssertEqual(
            WidgetCopyText.palette(palette.hexCodes),
            PaletteExporter.export(palette, as: .plainHex)
        )
    }

    func testColorCopyTextIsTheHex() {
        XCTAssertEqual(WidgetCopyText.color("#1A73A8"), "#1A73A8")
    }
}
