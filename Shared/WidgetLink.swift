//
//  WidgetLink.swift
//  Palettes (app + widgets)
//
//  The palettes:// URLs widgets and controls open. The app parses them in
//  PaletteTabView.onOpenURL.
//

import Foundation

nonisolated enum WidgetLink: Equatable, Sendable {
    case palette(UUID)
    case color(UUID)
    case newPalette
    case newColor
    case scanColor
    case scanPalette
    case copyPalette(UUID)
    case copyColor(UUID)
    case library

    static let scheme = "palettes"

    var url: URL {
        let path: String
        switch self {
        case .palette(let id): path = "palette/\(id.uuidString)"
        case .color(let id): path = "color/\(id.uuidString)"
        case .newPalette: path = "new/palette"
        case .newColor: path = "new/color"
        case .scanColor: path = "new/scan"
        case .scanPalette: path = "new/scan-palette"
        case .copyPalette(let id): path = "copy/palette/\(id.uuidString)"
        case .copyColor(let id): path = "copy/color/\(id.uuidString)"
        case .library: path = "library"
        }
        return URL(string: "\(Self.scheme)://\(path)")!
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host(percentEncoded: false)?.lowercased()
        else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }

        switch (host, parts.count) {
        case ("library", 0):
            self = .library
        case ("palette", 1):
            guard let id = UUID(uuidString: parts[0]) else { return nil }
            self = .palette(id)
        case ("color", 1):
            guard let id = UUID(uuidString: parts[0]) else { return nil }
            self = .color(id)
        case ("new", 1):
            switch parts[0].lowercased() {
            case "palette": self = .newPalette
            case "color": self = .newColor
            case "scan": self = .scanColor
            case "scan-palette": self = .scanPalette
            default: return nil
            }
        case ("copy", 2):
            guard let id = UUID(uuidString: parts[1]) else { return nil }
            switch parts[0].lowercased() {
            case "palette": self = .copyPalette(id)
            case "color": self = .copyColor(id)
            default: return nil
            }
        default:
            return nil
        }
    }
}
