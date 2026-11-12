//
//  WidgetRotationTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class WidgetRotationTests: XCTestCase {

    private func palette(_ name: String, favorite: Bool) -> WidgetSnapshot.Palette {
        .init(id: UUID(), name: name, hexCodes: ["#000000"], colorNames: ["Black"], isFavorite: favorite)
    }

    private func swatch(_ i: Int) -> WidgetSnapshot.Swatch {
        .init(id: UUID(), name: "C\(i)", hex: "#000000", isFavorite: false)
    }

    private func hour(_ k: Int, plus seconds: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(k) * 3600 + seconds)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ offset: Int, hour h: Int = 12) -> Date {
        let start = utc.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: h))!
        return utc.date(byAdding: .day, value: offset, to: start)!
    }

    // MARK: Hourly rotation

    func testRotationCyclesFavoritesInLibraryOrder() {
        let snapshot = WidgetSnapshot(palettes: [
            palette("A", favorite: true), palette("x", favorite: false),
            palette("B", favorite: true), palette("C", favorite: true),
        ])
        let k = 900_000 // divisible by 3
        let names = (0..<6).map { WidgetRotation.favoritePalette(in: snapshot, at: hour(k + $0, plus: 60))!.name }
        XCTAssertEqual(names, ["A", "B", "C", "A", "B", "C"])
    }

    func testRotationIsStableWithinAnHour() {
        let snapshot = WidgetSnapshot(palettes: [palette("A", favorite: true), palette("B", favorite: true)])
        XCTAssertEqual(
            WidgetRotation.favoritePalette(in: snapshot, at: hour(41, plus: 1))?.name,
            WidgetRotation.favoritePalette(in: snapshot, at: hour(41, plus: 3599))?.name
        )
    }

    func testRotationWithoutFavoritesIsNil() {
        let snapshot = WidgetSnapshot(palettes: [palette("x", favorite: false)])
        XCTAssertNil(WidgetRotation.favoritePalette(in: snapshot, at: .now))
    }

    func testHourlyDatesStartAtTheCurrentHour() {
        let dates = WidgetRotation.hourlyDates(from: hour(10, plus: 1234))
        XCTAssertEqual(dates.count, 24)
        XCTAssertEqual(dates.first, hour(10))
        XCTAssertEqual(dates.last, hour(33))
    }

    // MARK: Of the day

    func testColorOfTheDayIsStableWithinADay() {
        let snapshot = WidgetSnapshot(colors: (0..<10).map(swatch))
        XCTAssertEqual(
            WidgetRotation.colorOfTheDay(in: snapshot, at: day(3, hour: 0), calendar: utc),
            WidgetRotation.colorOfTheDay(in: snapshot, at: day(3, hour: 23), calendar: utc)
        )
    }

    func testColorOfTheDayChangesAcrossDays() {
        let snapshot = WidgetSnapshot(colors: (0..<10).map(swatch))
        let picks = (0..<30).compactMap { WidgetRotation.colorOfTheDay(in: snapshot, at: day($0), calendar: utc)?.name }
        XCTAssertGreaterThanOrEqual(Set(picks).count, 5)
    }

    func testPaletteAndColorOfTheDayDoNotMoveInLockstep() {
        let snapshot = WidgetSnapshot(
            palettes: (0..<10).map { palette("P\($0)", favorite: false) },
            colors: (0..<10).map(swatch)
        )
        let paletteIndices = (0..<30).map { d in
            snapshot.palettes.firstIndex { $0 == WidgetRotation.paletteOfTheDay(in: snapshot, at: day(d), calendar: utc) }!
        }
        let colorIndices = (0..<30).map { d in
            snapshot.colors.firstIndex { $0 == WidgetRotation.colorOfTheDay(in: snapshot, at: day(d), calendar: utc) }!
        }
        XCTAssertNotEqual(paletteIndices, colorIndices)
    }

    func testOfTheDayIsNilForAnEmptyLibrary() {
        XCTAssertNil(WidgetRotation.colorOfTheDay(in: .empty, at: .now, calendar: utc))
        XCTAssertNil(WidgetRotation.paletteOfTheDay(in: .empty, at: .now, calendar: utc))
    }

    func testDayDatesAreTodayAndTomorrow() {
        let dates = WidgetRotation.dayDates(from: day(5, hour: 15), calendar: utc)
        XCTAssertEqual(dates, [day(5, hour: 0), day(6, hour: 0)])
    }
}
