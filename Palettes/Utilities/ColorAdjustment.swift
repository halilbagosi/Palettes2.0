import SwiftUI

/// Shared temperature/saturation/brightness adjustment math used by the
/// scan flows and the color edit sheet. All slider values are 0…1 with 0.5 neutral.
enum ColorAdjustment {

    /// Applies temperature, saturation and brightness offsets to a base RGB (0–255) color.
    static func apply(
        baseR: Double, baseG: Double, baseB: Double,
        temperature: Double, saturation: Double, brightness: Double
    ) -> (r: Double, g: Double, b: Double) {
        let tempFactor = (temperature - 0.5) * 2.0
        let tempAmount = tempFactor * 40.0

        let rTemp = min(255, max(0, baseR + tempAmount))
        let gTemp = min(255, max(0, baseG + tempAmount * 0.15))
        let bTemp = min(255, max(0, baseB - tempAmount))

        let uiColor = UIColor(
            red: rTemp / 255.0,
            green: gTemp / 255.0,
            blue: bTemp / 255.0,
            alpha: 1.0
        )
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let satFactor = (saturation - 0.5) * 2.0
        let newSat = min(1, max(0, s + CGFloat(satFactor) * 0.5))

        let briFactor = (brightness - 0.5) * 2.0
        let newBri = min(1, max(0, b + CGFloat(briFactor) * 0.5))

        let adjusted = UIColor(hue: h, saturation: newSat, brightness: newBri, alpha: 1)
        var rOut: CGFloat = 0, gOut: CGFloat = 0, bOut: CGFloat = 0
        adjusted.getRed(&rOut, green: &gOut, blue: &bOut, alpha: &a)

        return (
            min(255, max(0, Double(rOut) * 255)),
            min(255, max(0, Double(gOut) * 255)),
            min(255, max(0, Double(bOut) * 255))
        )
    }

    static func hexString(r: Double, g: Double, b: Double) -> String {
        String(format: "#%02X%02X%02X", Int(round(r)), Int(round(g)), Int(round(b)))
    }

    static func color(r: Double, g: Double, b: Double) -> Color {
        Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0)
    }

    /// Formats a 0…1 slider value as a signed offset label, e.g. "+20 warm" / "Neutral".
    static func offsetLabel(_ value: Double, positive: String? = nil, negative: String? = nil) -> String {
        let offset = Int(round((value - 0.5) * 100))
        if offset == 0 { return "Neutral" }
        if offset > 0 {
            return positive.map { "+\(offset) \($0)" } ?? "+\(offset)"
        }
        return negative.map { "\(offset) \($0)" } ?? "\(offset)"
    }
}
