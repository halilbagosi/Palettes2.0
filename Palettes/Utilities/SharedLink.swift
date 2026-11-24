//
//  SharedLink.swift
//  Palettes
//
//  The link Share sends for a palette or a color:
//  https://palettes.halilbagosi.com/p/#<data> (palette) or /c/#<data> (color).
//  <data> is base64url JSON holding the colors themselves, so no server
//  stores anything, and the fragment never even reaches the web server.
//
//  With Palettes installed, iOS opens the link in the app (Associated
//  Domains: applinks:palettes.halilbagosi.com), which shows it for Save or
//  Discard. Without it, the web page at that path sends the person to the
//  App Store. The page decodes the same JSON (see the palettes-app repo).
//
//  JSON, version 1, short keys to keep links short:
//    {"v":1,"n":"Kyoto Dusk","c":[{"h":"F2A65A","n":"Lantern Glow","r":"Accent"}]}
//  "n" at the top is the palette name (absent for a color); "r" is optional.
//

import Foundation

nonisolated struct SharedLink: Equatable, Sendable, Identifiable {
    enum Kind: String, Sendable {
        case palette = "p"
        case color = "c"
    }

    struct Swatch: Equatable, Sendable {
        /// "#RRGGBB", uppercase.
        var hex: String
        var name: String
        var role: String?
    }

    let id = UUID()
    var kind: Kind
    /// The palette's name; for a color, the color's name.
    var name: String
    var swatches: [Swatch]

    static let host = "palettes.halilbagosi.com"
    /// Same cap as PaletteDraft.maximumColors; anything past it is dropped.
    static let maximumSwatches = 20
    /// Names are cut to this when read, so a crafted link can't flood the UI.
    static let maximumNameLength = 80

    static func == (lhs: SharedLink, rhs: SharedLink) -> Bool {
        lhs.kind == rhs.kind && lhs.name == rhs.name && lhs.swatches == rhs.swatches
    }

    // MARK: - Building

    static func palette(name: String, swatches: [Swatch]) -> SharedLink {
        SharedLink(kind: .palette, name: name, swatches: Array(swatches.prefix(maximumSwatches)))
    }

    static func color(name: String, hex: String) -> SharedLink {
        SharedLink(kind: .color, name: name, swatches: [Swatch(hex: hex, name: name, role: nil)])
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/\(kind.rawValue)/"
        components.fragment = Self.encode(payload)
        return components.url!
    }

    // MARK: - Reading

    /// Reads a share link: the https link above, or the same path and
    /// fragment on the app's own scheme (palettes://p/#…), which opens the
    /// app without the web round trip (used by tests and the simulator).
    init?(url: URL) {
        let kindToken: String
        switch url.scheme?.lowercased() {
        case "https":
            guard url.host(percentEncoded: false)?.lowercased() == Self.host,
                  let first = url.pathComponents.first(where: { $0 != "/" }) else { return nil }
            kindToken = first
        case "palettes":
            guard let host = url.host(percentEncoded: false) else { return nil }
            kindToken = host
        default:
            return nil
        }
        guard let kind = Kind(rawValue: kindToken.lowercased()),
              let fragment = url.fragment(percentEncoded: false), !fragment.isEmpty,
              let payload = Self.decode(fragment)
        else { return nil }

        let swatches = payload.c.prefix(Self.maximumSwatches).compactMap { raw -> Swatch? in
            guard let hex = Self.normalizedHex(raw.h) else { return nil }
            let name = Self.cleaned(raw.n) ?? hex
            return Swatch(hex: hex, name: name, role: Self.cleaned(raw.r))
        }
        guard !swatches.isEmpty else { return nil }

        switch kind {
        case .palette:
            self.init(kind: .palette, name: Self.cleaned(payload.n) ?? "Shared Palette", swatches: swatches)
        case .color:
            let swatch = swatches[0]
            self.init(kind: .color, name: swatch.name, swatches: [Swatch(hex: swatch.hex, name: swatch.name, role: nil)])
        }
    }

    private init(kind: Kind, name: String, swatches: [Swatch]) {
        self.kind = kind
        self.name = name
        self.swatches = swatches
    }

    // MARK: - Payload

    private struct Payload: Codable {
        struct RawSwatch: Codable {
            var h: String
            var n: String?
            var r: String?
        }
        var v: Int
        var n: String?
        var c: [RawSwatch]
    }

    private var payload: Payload {
        Payload(
            v: 1,
            n: kind == .palette ? name : nil,
            c: swatches.map { swatch in
                let bare = swatch.hex.hasPrefix("#") ? String(swatch.hex.dropFirst()) : swatch.hex
                return .init(h: bare.uppercased(), n: swatch.name, r: swatch.role)
            }
        )
    }

    private static func encode(_ payload: Payload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(payload)) ?? Data()
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decode(_ fragment: String) -> Payload? {
        // 20 swatches with long names stay well under this.
        guard fragment.count <= 16_000 else { return nil }
        var base64 = fragment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.v == 1
        else { return nil }
        return payload
    }

    /// "#RRGGBB" for 6 hex digits (with or without "#"), else nil.
    private static func normalizedHex(_ raw: String) -> String? {
        var digits = raw.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, HexRGB.components(digits) != nil else { return nil }
        return "#" + digits.uppercased()
    }

    /// Trimmed, control characters removed, capped; nil when empty.
    private static func cleaned(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let scalars = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let text = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return String(text.prefix(maximumNameLength))
    }
}
