//
//  CreateWidgetArt.swift
//  PalettesWidgets
//
//  The face shared by the New Color and New Palette widgets: full-bleed
//  artwork, a glass-like + disc, and a title with a one-line subtitle.
//  The artwork is drawn with Core Graphics into an image so that tinted and
//  clear Home Screen modes keep its colours (the system recolours shapes
//  and gradients, but not an image marked full-colour).
//

import CoreGraphics
import os
import SwiftUI

/// New Color's face: a luminous field of hues that says "any colour".
struct NewColorFace: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CreateFace(art: CreateArt.hueField(dark: colorScheme == .dark),
                   title: "New Color", subtitle: "Pick or scan a color")
    }
}

/// New Palette's face: one of the curated palettes.
struct NewPaletteFace: View {
    let hexes: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        CreateFace(art: CreateArt.paletteFan(hexes: hexes, dark: colorScheme == .dark),
                   title: "New Palette", subtitle: "Start from a color or photo")
    }
}

struct CreateFace: View {
    let art: CGImage?
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let art {
                Image(decorative: art, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .fullColorInAccentedModes()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                CreatePlusBadge()
                Spacer(minLength: 0)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // Up to two lines: at large Dynamic Type sizes the subtitle
                // wraps rather than truncating.
                Text(subtitle)
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .opacity(0.85)
                    .padding(.top, 1)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(14)
        }
    }
}

/// The + affordance: an imitation of the app's glass buttons (widgets can't
/// draw the real material), like `GlassCircle` but larger and brighter.
struct CreatePlusBadge: View {
    var size: CGFloat = 40
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            // Light mode's brighter artwork needs a little help for the +.
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.3), radius: 1.5, y: 0.5)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.26), in: Circle())
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.2)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75)
            )
            .overlay(Circle().stroke(Color.black.opacity(colorScheme == .dark ? 0 : 0.12), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

// MARK: - Artwork

nonisolated enum CreateArt {
    /// Pixel size of the square artwork: a 170pt tile at @3x, so the fan's
    /// edges and hairlines stay crisp. About 1.2 MB per image; each one is
    /// drawn once per process and cached.
    static let pixels = 540

    /// Curated five-colour palettes the New Palette widget rotates through,
    /// one a day.
    static let palettes: [[String]] = [
        ["#264653", "#2A9D8F", "#E9C46A", "#F4A261", "#E76F51"],
        ["#355070", "#6D597A", "#B56576", "#E56B6F", "#EAAC8B"],
        ["#0B3C5D", "#1A73A8", "#7FC8F8", "#F2E8CF", "#E2683C"],
        ["#3E8E5E", "#A7C957", "#F2E8CF", "#D9B44A", "#BC4749"],
        ["#3D348B", "#7678ED", "#F7B801", "#F18701", "#F35B04"],
        ["#17131F", "#7A5CFF", "#FF5E7A", "#FFB020", "#FFE3A3"],
        ["#1B4332", "#40916C", "#95D5B2", "#FFE5EC", "#FF8FAB"],
        ["#006D77", "#83C5BE", "#EDF6F9", "#FFDDD2", "#E29578"],
    ]

    /// The palette shown on a given day (`WidgetRotation.dayIndex`). Cycles
    /// through the list so consecutive days never repeat.
    static func palette(forDay day: Int) -> [String] {
        let count = palettes.count
        return palettes[((day % count) + count) % count]
    }

    // MARK: New Color

    /// A soft, luminous field of hues arranged like a colour wheel around
    /// the edges: coral, amber, teal, blue and violet, meeting in magenta
    /// on the left. The darker coral sits under the + so it reads clearly.
    static func hueField(dark: Bool) -> CGImage? {
        dark ? hueFieldDark : hueFieldLight
    }

    private static let hueFieldLight = drawHueField(dark: false)
    private static let hueFieldDark = drawHueField(dark: true)

    private static func drawHueField(dark: Bool) -> CGImage? {
        draw { ctx, s in
            fill(ctx, s, hex: dark ? "#1B1626" : "#FFF6EE")
            let blobs: [(hex: String, x: CGFloat, y: CGFloat, r: CGFloat)] = [
                ("#FF5E7A", 0.00, 0.05, 0.75),
                ("#FFB020", 1.00, 0.00, 0.75),
                ("#2EC4B6", 1.00, 0.95, 0.70),
                ("#3D8BFF", 0.55, 1.05, 0.60),
                ("#7A5CFF", 0.00, 0.95, 0.75),
            ]
            for blob in blobs {
                radial(ctx, center: CGPoint(x: blob.x * s, y: blob.y * s), radius: blob.r * s * (dark ? 0.9 : 1),
                       hex: blob.hex, alpha: 1)
            }
            // A luminous core, right of centre and clear of the +.
            radial(ctx, center: CGPoint(x: 0.6 * s, y: 0.45 * s), radius: 0.42 * s,
                   hex: dark ? "#C7B8FF" : "#FFFFFF", alpha: dark ? 0.32 : 0.6)
            bottomScrim(ctx, s, strength: dark ? 0.45 : 0.32)
        }
    }

    // MARK: New Palette

    private struct FanKey: Hashable {
        let hexes: [String]
        let dark: Bool
    }

    /// Fans already drawn in this process. Only the curated palettes are
    /// ever passed in, so it stays small.
    private static let fanCache = OSAllocatedUnfairLock(initialState: [FanKey: CGImage]())

    /// A palette as a fan of rounded swatch cards, like a paint fan deck,
    /// over a deep wash of its darkest colour. Drawn once per palette and
    /// appearance, then cached.
    static func paletteFan(hexes: [String], dark: Bool) -> CGImage? {
        let key = FanKey(hexes: hexes, dark: dark)
        if let cached = fanCache.withLock({ $0[key] }) { return cached }
        guard let image = drawPaletteFan(hexes: hexes, dark: dark) else { return nil }
        fanCache.withLock { $0[key] = image }
        return image
    }

    private static func drawPaletteFan(hexes: [String], dark: Bool) -> CGImage? {
        let list = hexes.isEmpty ? [HexRGB.fallbackGrey] : hexes
        // Darkest card at the back, lightest at the front.
        let byLuminance = list.sorted { (HexRGB.luminance($0) ?? 0) < (HexRGB.luminance($1) ?? 0) }
        let darkest = byLuminance.first ?? HexRGB.fallbackGrey
        return draw { ctx, s in
            // Well below the darkest card so even that card stands out.
            ctx.setFillColor(mix(darkest, toward: 0, by: dark ? 0.72 : 0.58))
            ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
            // A soft lift behind the light end of the fan, away from the
            // darkest card and the +.
            radialColor(ctx, center: CGPoint(x: 0.95 * s, y: -0.05 * s), radius: 0.85 * s,
                        color: mix(darkest, toward: 1, by: dark ? 0.08 : 0.22), alpha: 0.7)
            // The cards hinge on a point below the bottom-right corner.
            let pivot = CGPoint(x: 0.90 * s, y: 1.20 * s)
            let angles: [CGFloat] = [-50, -36, -22, -8, 6]
            for (i, hex) in byLuminance.prefix(angles.count).enumerated() {
                ctx.saveGState()
                ctx.translateBy(x: pivot.x, y: pivot.y)
                ctx.rotate(by: angles[i] * .pi / 180)
                let card = CGPath(roundedRect: CGRect(x: -0.125 * s, y: -1.0 * s, width: 0.25 * s, height: 1.0 * s),
                                  cornerWidth: 0.045 * s, cornerHeight: 0.045 * s, transform: nil)
                ctx.saveGState()
                // Shadow offsets ignore the flipped transform: negative is down.
                ctx.setShadow(offset: CGSize(width: 0.01 * s, height: -0.01 * s), blur: 0.05 * s,
                              color: CGColor(gray: 0, alpha: 0.32))
                ctx.addPath(card)
                ctx.setFillColor(color(hex))
                ctx.fillPath()
                ctx.restoreGState()
                ctx.addPath(card)
                ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.22))
                ctx.setLineWidth(0.006 * s)
                ctx.strokePath()
                ctx.restoreGState()
            }
            bottomScrim(ctx, s, strength: dark ? 0.5 : 0.38)
        }
    }

    /// `hex` moved toward black (0) or white (1).
    static func mix(_ hex: String, toward grey: CGFloat, by t: CGFloat) -> CGColor {
        let c = HexRGB.components(hex) ?? HexRGB.components(HexRGB.fallbackGrey)!
        func m(_ v: Int) -> CGFloat { CGFloat(v) / 255 * (1 - t) + grey * t }
        return CGColor(colorSpace: space, components: [m(c.r), m(c.g), m(c.b), 1]) ?? CGColor(gray: grey, alpha: 1)
    }

    // MARK: Drawing helpers

    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!

    /// A square sRGB bitmap with a top-left origin.
    private static func draw(_ body: (CGContext, CGFloat) -> Void) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let s = CGFloat(pixels)
        ctx.translateBy(x: 0, y: s)
        ctx.scaleBy(x: 1, y: -1)
        body(ctx, s)
        return ctx.makeImage()
    }

    static func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
        let c = HexRGB.components(hex) ?? HexRGB.components(HexRGB.fallbackGrey)!
        return CGColor(colorSpace: space, components: [CGFloat(c.r) / 255, CGFloat(c.g) / 255, CGFloat(c.b) / 255, alpha])
            ?? CGColor(gray: 0.5, alpha: alpha)
    }

    private static func fill(_ ctx: CGContext, _ s: CGFloat, hex: String) {
        ctx.setFillColor(color(hex))
        ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    }

    /// A blob that fades out with a smooth, Gaussian-like falloff.
    private static func radial(_ ctx: CGContext, center: CGPoint, radius: CGFloat, hex: String, alpha: CGFloat) {
        radialColor(ctx, center: center, radius: radius, color: color(hex), alpha: alpha)
    }

    private static func radialColor(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color base: CGColor, alpha: CGFloat) {
        let steps = 10
        var colors: [CGColor] = []
        var locations: [CGFloat] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let falloff = pow(1 - t * t, 2)
            colors.append(base.copy(alpha: alpha * falloff) ?? base)
            locations.append(t)
        }
        guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations) else { return }
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    /// Darkens the lower part so white text stays legible on any colours.
    private static func bottomScrim(_ ctx: CGContext, _ s: CGFloat, strength: CGFloat) {
        let colors = [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: strength * 0.55), CGColor(gray: 0, alpha: strength)]
        guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.6, 1]) else { return }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s * 0.45), end: CGPoint(x: 0, y: s), options: [])
    }
}
