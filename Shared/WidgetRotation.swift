//
//  WidgetRotation.swift
//  Palettes (app + widgets)
//
//  Which palette or colour a time-based widget shows. Everything here is a
//  pure function of the snapshot and the date, so every widget instance
//  agrees and reloads never reshuffle. Never use `Hasher`: it is seeded
//  per process.
//

import Foundation

nonisolated enum WidgetRotation {
    static let colorSalt: UInt64 = 0xC0105EED_C0105EED
    static let paletteSalt: UInt64 = 0x9A1E77E5_9A1E77E5

    // MARK: Hourly

    /// Whole hours since the reference date.
    static func hourIndex(at date: Date) -> Int {
        Int((date.timeIntervalSinceReferenceDate / 3600).rounded(.down))
    }

    /// The start of the current hour, then each following hour.
    static func hourlyDates(from date: Date, count: Int = 24) -> [Date] {
        let start = hourIndex(at: date)
        return (0..<count).map { Date(timeIntervalSinceReferenceDate: Double(start + $0) * 3600) }
    }

    static func favoritePalette(in snapshot: WidgetSnapshot, at date: Date) -> WidgetSnapshot.Palette? {
        let favorites = snapshot.favoritePalettes
        guard !favorites.isEmpty else { return nil }
        return favorites[positiveModulo(hourIndex(at: date), favorites.count)]
    }

    // MARK: Daily

    static func dayIndex(at date: Date, calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    /// Start of today, then start of tomorrow.
    static func dayDates(from date: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        return [today, tomorrow]
    }

    static func colorOfTheDay(in snapshot: WidgetSnapshot, at date: Date, calendar: Calendar = .current) -> WidgetSnapshot.Swatch? {
        guard !snapshot.colors.isEmpty else { return nil }
        let i = dailyIndex(day: dayIndex(at: date, calendar: calendar), salt: colorSalt, count: snapshot.colors.count)
        return snapshot.colors[i]
    }

    static func paletteOfTheDay(in snapshot: WidgetSnapshot, at date: Date, calendar: Calendar = .current) -> WidgetSnapshot.Palette? {
        guard !snapshot.palettes.isEmpty else { return nil }
        let i = dailyIndex(day: dayIndex(at: date, calendar: calendar), salt: paletteSalt, count: snapshot.palettes.count)
        return snapshot.palettes[i]
    }

    // MARK: Helpers

    static func dailyIndex(day: Int, salt: UInt64, count: Int) -> Int {
        Int(mix(UInt64(bitPattern: Int64(day)) ^ salt) % UInt64(count))
    }

    /// SplitMix64 finalizer: a fixed, well-spread 64-bit mix.
    static func mix(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    private static func positiveModulo(_ a: Int, _ n: Int) -> Int { ((a % n) + n) % n }
}
