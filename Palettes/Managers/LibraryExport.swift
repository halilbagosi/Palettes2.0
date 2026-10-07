//
//  LibraryExport.swift
//  Palettes
//
//  Whole-library export ("Export Library" in Settings): every user-created
//  color, palette (with names, roles, favorites) and custom tag. Archival
//  JSON — there is no importer yet; `formatVersion` leaves room for one.
//

import Foundation

struct LibraryExport: Codable, Equatable {
    struct Color: Codable, Equatable {
        var id: UUID
        var name: String
        var hex: String
        var isFavorite: Bool
        var isGenerated: Bool
    }

    struct Swatch: Codable, Equatable {
        var name: String
        var hex: String
        var role: String?
    }

    struct Palette: Codable, Equatable {
        var id: UUID
        var name: String
        var isFavorite: Bool
        var isGenerated: Bool
        var colors: [Swatch]
    }

    var formatVersion = 1
    var exportedAt: Date
    var colors: [Color]
    var palettes: [Palette]
    var customTags: [String]

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> LibraryExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LibraryExport.self, from: data)
    }
}
