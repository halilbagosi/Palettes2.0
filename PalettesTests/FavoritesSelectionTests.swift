//
//  FavoritesSelectionTests.swift
//

import XCTest
@testable import Palettes

@MainActor
final class FavoritesSelectionTests: XCTestCase {

    private func palette(_ fav: Bool) -> WidgetSnapshot.Palette {
        .init(id: UUID(), name: "P", hexCodes: ["#FF0000"], colorNames: ["Red"], isFavorite: fav)
    }

    private func swatch(_ fav: Bool) -> WidgetSnapshot.Swatch {
        .init(id: UUID(), name: "C", hex: "#00FF00", isFavorite: fav)
    }

    func testChosenOrderIsKept() {
        let a = palette(false), b = palette(true), c = palette(false)
        let snapshot = WidgetSnapshot(palettes: [a, b, c])
        let result = FavoritesSelection.palettes(useChosen: true, chosenIDs: [c.id, a.id], in: snapshot, capacity: 5)
        XCTAssertEqual(result.map(\.id), [c.id, a.id])
    }

    func testDeletedIDsAreSkipped() {
        let a = palette(false)
        let snapshot = WidgetSnapshot(palettes: [a])
        let result = FavoritesSelection.palettes(useChosen: true, chosenIDs: [UUID(), a.id], in: snapshot, capacity: 5)
        XCTAssertEqual(result.map(\.id), [a.id])
    }

    func testAllDeletedFallsBackToFavorites() {
        let fav = swatch(true), other = swatch(false)
        let snapshot = WidgetSnapshot(colors: [other, fav])
        let result = FavoritesSelection.colors(useChosen: true, chosenIDs: [UUID()], in: snapshot, capacity: 4)
        XCTAssertEqual(result.map(\.id), [fav.id])
    }

    func testFavoritesModeIgnoresChosen() {
        let fav = swatch(true), other = swatch(false)
        let snapshot = WidgetSnapshot(colors: [other, fav])
        let result = FavoritesSelection.colors(useChosen: false, chosenIDs: [other.id], in: snapshot, capacity: 4)
        XCTAssertEqual(result.map(\.id), [fav.id])
    }

    func testCapacityPrefix() {
        let colors = (0..<6).map { _ in swatch(true) }
        let snapshot = WidgetSnapshot(colors: colors)
        XCTAssertEqual(FavoritesSelection.colors(useChosen: false, chosenIDs: [], in: snapshot, capacity: 4).map(\.id),
                       colors.prefix(4).map(\.id))
        XCTAssertEqual(FavoritesSelection.colors(useChosen: true, chosenIDs: colors.map(\.id), in: snapshot, capacity: 3).count, 3)
    }

    func testDuplicatesRemoved() {
        let a = palette(false), b = palette(false)
        let snapshot = WidgetSnapshot(palettes: [a, b])
        let result = FavoritesSelection.palettes(useChosen: true, chosenIDs: [a.id, b.id, a.id], in: snapshot, capacity: 5)
        XCTAssertEqual(result.map(\.id), [a.id, b.id])
    }
}
