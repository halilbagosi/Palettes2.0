//
//  MorphingCardGridTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class MorphingCardGridTests: XCTestCase {

    private let compact = MorphingCardGrid(minColumnWidth: 160, maxColumnWidth: 280, rowHeight: 118, spacing: 12)
    private let normal = MorphingCardGrid(minColumnWidth: 340, maxColumnWidth: 560, rowHeight: 180, spacing: 20)

    // MARK: columnCount

    func testColumnCountPhonePortrait() {
        XCTAssertEqual(compact.columnCount(forWidth: 361), 2)
        XCTAssertEqual(normal.columnCount(forWidth: 361), 1)
    }

    func testColumnCountGrowsWithWidth() {
        XCTAssertEqual(normal.columnCount(forWidth: 700), 2)
        XCTAssertEqual(compact.columnCount(forWidth: 1000), 5)
    }

    func testColumnCountNeverBelowOne() {
        XCTAssertEqual(compact.columnCount(forWidth: 0), 1)
        XCTAssertEqual(compact.columnCount(forWidth: 50), 1)
        XCTAssertEqual(normal.columnCount(forWidth: -10), 1)
    }

    func testColumnCountWithFoldSplitsEvenlyEitherSide() {
        var grid = compact
        grid.foldSpan = 480...520
        // 480pt each side -> 2 columns per side.
        XCTAssertEqual(grid.columnCount(forWidth: 1000), 4)
    }

    func testFoldAtEdgeFallsBackToPlainColumns() {
        var grid = compact
        grid.foldSpan = 0...40
        XCTAssertEqual(grid.columnCount(forWidth: 1000), compact.columnCount(forWidth: 1000))
    }

    // MARK: itemRange (compact @ 361 -> 2 columns, row stride 130)

    func testItemRangeFirstRowOnly() {
        XCTAssertEqual(compact.itemRange(fromY: 0, toY: 100, width: 361, itemCount: 100), 0..<2)
    }

    func testItemRangeSpansRowsInclusive() {
        // maxY 300 lies in row 2 -> rows 0...2 -> 6 items.
        XCTAssertEqual(compact.itemRange(fromY: 0, toY: 300, width: 361, itemCount: 100), 0..<6)
    }

    func testItemRangeMiddleWindow() {
        // 260 -> row 2, 400 -> row 3.
        XCTAssertEqual(compact.itemRange(fromY: 260, toY: 400, width: 361, itemCount: 100), 4..<8)
    }

    func testItemRangeClampsNegativeMinY() {
        XCTAssertEqual(compact.itemRange(fromY: -500, toY: 100, width: 361, itemCount: 100), 0..<2)
    }

    func testItemRangeClampsToItemCount() {
        XCTAssertEqual(compact.itemRange(fromY: 0, toY: 10_000, width: 361, itemCount: 7), 0..<7)
    }

    func testItemRangeBeyondEndIsEmpty() {
        let r = compact.itemRange(fromY: 10_000, toY: 11_000, width: 361, itemCount: 7)
        XCTAssertTrue(r.isEmpty)
    }

    func testItemRangeEmptyCollection() {
        XCTAssertTrue(compact.itemRange(fromY: 0, toY: 500, width: 361, itemCount: 0).isEmpty)
    }
}
