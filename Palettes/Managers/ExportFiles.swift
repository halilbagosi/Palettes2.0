//
//  ExportFiles.swift
//  Palettes
//
//  Scratch space for files handed to the share sheet. Everything lives in one
//  app-owned temp subfolder so it can be swept after sharing and on launch
//  without touching anything else in tmp/.
//

import Foundation

enum ExportFiles {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    /// Writes `data` to `<directory>/<baseName>.<ext>`. `baseName` is reduced
    /// to letters, numbers, `-` and `_`, so a palette name can never escape
    /// `directory`; the result is capped at 80 characters; an empty result falls back to "palette".
    static func write(_ data: Data, baseName: String, ext: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safe = String(String(baseName.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }).prefix(80))
        let url = directory
            .appendingPathComponent(safe.isEmpty ? "palette" : safe)
            .appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
