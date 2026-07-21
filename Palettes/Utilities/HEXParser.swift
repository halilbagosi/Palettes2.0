//
//  HEXParser.swift
//  Palettes
//
//  Created by Halil Bagosi on 24.2.26.
//

import SwiftUI

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        switch cleaned.count {
        case 3, 4:
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        case 6, 8:
            break
        default:
            return nil
        }

        guard let number = UInt64(cleaned, radix: 16) else {
            return nil
        }

        // For 8-digit (RRGGBBAA) input, shift past the discarded alpha byte.
        let shift: UInt64 = cleaned.count == 8 ? 8 : 0
        let shifted = number >> shift

        let r = Double((shifted >> 16) & 0xFF) / 255.0
        let g = Double((shifted >> 8) & 0xFF) / 255.0
        let b = Double(shifted & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - CIEDE2000 Color Naming

enum ColorNamer {

    // ── Comprehensive named-color database (~460 entries) ──────────────
    // Values are sRGB 0-255. Covers CSS named colors, X11 set, plus
    // curated design-palette additions for pastels, earth tones, neons,
    // and neutral shades.

    private static let namedColors: [(name: String, r: Double, g: Double, b: Double)] = [
        // ── Whites & Near-Whites ──
        ("White",              255, 255, 255),
        ("Snow",               255, 250, 250),
        ("Ghost White",        248, 248, 255),
        ("Ivory",              255, 255, 240),
        ("Floral White",       255, 250, 240),
        ("Linen",              250, 240, 230),
        ("Seashell",           255, 245, 238),
        ("Old Lace",           253, 245, 230),
        ("Cornsilk",           255, 248, 220),
        ("Lemon Chiffon",      255, 250, 205),
        ("Antique White",      250, 235, 215),
        ("Papaya Whip",        255, 239, 213),
        ("Blanched Almond",    255, 235, 205),
        ("Bisque",             255, 228, 196),
        ("Moccasin",           255, 228, 181),
        ("Navajo White",       255, 222, 173),
        ("Wheat",              245, 222, 179),
        ("Peach Puff",         255, 218, 185),
        ("Misty Rose",         255, 228, 225),
        ("Lavender Blush",     255, 240, 245),
        ("Honeydew",           240, 255, 240),
        ("Mint Cream",         245, 255, 250),
        ("Azure",              240, 255, 255),
        ("Alice Blue",         240, 248, 255),
        ("Cream",              255, 253, 208),

        // ── Grays & Neutrals ──
        ("Black",                0,   0,   0),
        ("Jet",                 52,  52,  52),
        ("Onyx",                53,  56,  57),
        ("Charcoal",            54,  69,  79),
        ("Dark Gray",           64,  64,  64),
        ("Outer Space",         65,  74,  76),
        ("Dim Gray",           105, 105, 105),
        ("Gray",               128, 128, 128),
        ("Battleship Gray",    132, 132, 130),
        ("Ash Gray",           178, 190, 181),
        ("Dark Silver",        113, 112, 110),
        ("Silver",             192, 192, 192),
        ("Light Gray",         211, 211, 211),
        ("Gainsboro",          220, 220, 220),
        ("Platinum",           229, 228, 226),
        ("White Smoke",        245, 245, 245),
        ("Slate Gray",         112, 128, 144),
        ("Light Slate Gray",   119, 136, 153),
        ("Cool Gray",          140, 146, 172),
        ("Warm Gray",          152, 142, 132),
        ("Taupe",              72,   60,  50),
        ("Taupe Gray",         139, 133, 137),

        // ── Reds ──
        ("Dark Red",           139,   0,   0),
        ("Maroon",             128,   0,   0),
        ("Blood Red",          102,   0,   0),
        ("Oxblood",            101,   0,  11),
        ("Garnet",             115,  54,  53),
        ("Burgundy",           128,   0,  32),
        ("Crimson",            220,  20,  60),
        ("Red",                255,   0,   0),
        ("Fire Engine Red",    206,  32,  41),
        ("Scarlet",            255,  36,   0),
        ("Vermilion",          227,  66,  52),
        ("Cardinal",           196,  30,  58),
        ("Ruby",               224,  17,  95),
        ("Carmine",            150,   0,  24),
        ("Firebrick",          178,  34,  34),
        ("Indian Red",         205,  92,  92),
        ("Chili Red",          226,  61,  40),
        ("Brick Red",          203,  65,  84),
        ("Persian Red",        204,  51,  51),
        ("Rosewood",           101,   0,  11),
        ("Rust",               183,  65,  14),
        ("Burnt Sienna Red",   233,  78,  43),

        // ── Pinks ──
        ("Pink",               255, 192, 203),
        ("Light Pink",         255, 182, 193),
        ("Hot Pink",           255, 105, 180),
        ("Deep Pink",          255,  20, 147),
        ("Magenta Rose",       255,   0, 144),
        ("Rose",               255,   0, 127),
        ("French Rose",        246,  74, 138),
        ("Rose Pink",          255, 102, 204),
        ("Cerise",             222,  49,  99),
        ("Carnation Pink",     255, 166, 201),
        ("Blush",              222,  93, 131),
        ("Salmon Pink",        255, 145, 164),
        ("Watermelon",         253,  70,  89),
        ("Flamingo Pink",      252, 142, 172),
        ("Pastel Pink",        255, 209, 220),
        ("Baby Pink",          244, 194, 194),
        ("Bubblegum",          255, 193, 204),
        ("Fuchsia",            255,   0, 255),
        ("Magenta",            255,   0, 255),
        ("Orchid Pink",        242, 189, 205),
        ("Thulian Pink",       222, 111, 161),
        ("Dusty Rose",         194, 111, 120),
        ("Mauve",              224, 176, 255),
        ("Old Rose",           192, 128, 129),
        ("Rosé",               181, 101, 118),
        ("Punch",              236,  60,  84),
        ("Rosewater",          244, 194, 194),

        // ── Oranges ──
        ("Orange Red",         255,  69,   0),
        ("Red Orange",         255,  83,  73),
        ("Tomato",             255,  99,  71),
        ("Dark Orange",        255, 140,   0),
        ("Orange",             255, 165,   0),
        ("International Orange", 255,  79,   0),
        ("Safety Orange",      255, 103,   0),
        ("Tangerine",          255, 159,   0),
        ("Carrot",             237, 145,  33),
        ("Pumpkin",            255, 117,  24),
        ("Burnt Orange",       204,  85,   0),
        ("Persimmon",          236,  88,   0),
        ("Coral",              255, 127,  80),
        ("Light Coral",        240, 128, 128),
        ("Salmon",             250, 128, 114),
        ("Light Salmon",       255, 160, 122),
        ("Dark Salmon",        233, 150, 122),
        ("Peach",              255, 204, 153),
        ("Apricot",            251, 206, 177),
        ("Melon",              254, 186, 173),
        ("Cantaloupe",         255, 166, 128),
        ("Papaya",             255, 219, 172),
        ("Mandarin",           247, 114,  51),
        ("Tiger",              252, 109,  36),
        ("Copper",             184, 115,  51),
        ("Amber",              255, 191,   0),
        ("Bronze",             205, 127,  50),
        ("Cinnamon",           210, 105,  30),

        // ── Yellows ──
        ("Yellow",             255, 255,   0),
        ("Light Yellow",       255, 255, 224),
        ("Lemon",              255, 247,   0),
        ("Canary",             255, 239,   0),
        ("Banana",             255, 225,  53),
        ("Gold",               255, 215,   0),
        ("Golden Rod",         218, 165,  32),
        ("Dark Golden Rod",    184, 134,  11),
        ("Pale Golden Rod",    238, 232, 170),
        ("Khaki",              240, 230, 140),
        ("Dark Khaki",         189, 183, 107),
        ("Saffron",            244, 196,  48),
        ("Mustard",            255, 219,  88),
        ("Goldenrod",          218, 165,  32),
        ("Flax",               238, 220, 130),
        ("Jasmine",            248, 222, 126),
        ("Maize",              251, 236, 93),
        ("Champagne",          247, 231, 206),
        ("Buttermilk",         255, 241, 181),
        ("Butter",             255, 239, 161),
        ("Blonde",             250, 240, 190),
        ("Honey",              235, 177,  52),
        ("Sunflower",          255, 218,  3),
        ("Dijon",              193, 157,  10),
        ("Turmeric",           255, 195,  75),

        // ── Greens ──
        ("Dark Green",           0, 100,   0),
        ("Green",                0, 128,   0),
        ("Forest Green",        34, 139,  34),
        ("Sea Green",           46, 139,  87),
        ("Medium Sea Green",    60, 179, 113),
        ("Spring Green",         0, 255, 127),
        ("Medium Spring Green",  0, 250, 154),
        ("Lime Green",          50, 205,  50),
        ("Lime",                 0, 255,   0),
        ("Lawn Green",         124, 252,   0),
        ("Chartreuse",         127, 255,   0),
        ("Green Yellow",       173, 255,  47),
        ("Yellow Green",       154, 205,  50),
        ("Olive Drab",         107, 142,  35),
        ("Olive",              128, 128,   0),
        ("Dark Olive Green",    85, 107,  47),
        ("Pale Green",         152, 251, 152),
        ("Light Green",        144, 238, 144),
        ("Medium Aquamarine",  102, 205, 170),
        ("Dark Sea Green",     143, 188, 143),
        ("Emerald",             80, 200, 120),
        ("Jade",                 0, 168, 107),
        ("Malachite",           11, 218,  81),
        ("Mint",               152, 255, 152),
        ("Mint Green",          62, 180, 137),
        ("Sage",               188, 184, 138),
        ("Fern",                79, 121,  66),
        ("Moss Green",         138, 154,  91),
        ("Hunter Green",        53,  94,  59),
        ("Shamrock",             0, 158,  96),
        ("Kelly Green",         76, 187,  23),
        ("Pine",                 1,  68,  33),
        ("Army Green",          75,  83,  32),
        ("Juniper",             60, 100,  85),
        ("Basil",               92, 128,   1),
        ("Pistachio",          147, 197, 114),
        ("Avocado",             86, 130,   3),
        ("Pear",               209, 226,  49),
        ("Lime Zest",          204, 255,   0),
        ("Neon Green",          57, 255,  20),
        ("Harlequin",          63,  255,   0),
        ("Celadon",            172, 225, 175),
        ("Tea Green",          208, 240, 192),
        ("Honeydew Green",     198, 224, 180),
        ("Seafoam",            159, 226, 191),

        // ── Teals & Cyans ──
        ("Teal",                 0, 128, 128),
        ("Dark Teal",            0,  80,  80),
        ("Dark Cyan",            0, 139, 139),
        ("Cyan",                 0, 255, 255),
        ("Aqua",                 0, 255, 255),
        ("Light Cyan",         224, 255, 255),
        ("Pale Turquoise",     175, 238, 238),
        ("Aquamarine",         127, 255, 212),
        ("Turquoise",           64, 224, 208),
        ("Medium Turquoise",    72, 209, 204),
        ("Dark Turquoise",       0, 206, 209),
        ("Cadet Blue",          95, 158, 160),
        ("Light Sea Green",     32, 178, 170),
        ("Verdigris",           67, 179, 174),
        ("Robin Egg Blue",       0, 204, 204),
        ("Tiffany Blue",       129, 216, 208),
        ("Celeste",            178, 255, 255),
        ("Electric Blue",       44, 117, 255),
        ("Persian Green",        0, 166, 147),
        ("Caribbean Green",      0, 204, 153),

        // ── Blues ──
        ("Navy",                 0,   0, 128),
        ("Dark Blue",            0,   0, 139),
        ("Medium Blue",          0,   0, 205),
        ("Blue",                 0,   0, 255),
        ("Midnight Blue",       25,  25, 112),
        ("Royal Blue",          65, 105, 225),
        ("Cobalt Blue",          0,  71, 171),
        ("Ultramarine",         63,   0, 255),
        ("Cerulean",            42, 82,  190),
        ("Sapphire",            15,  82, 186),
        ("Azure Blue",           0, 127, 255),
        ("Cornflower Blue",    100, 149, 237),
        ("Steel Blue",          70, 130, 180),
        ("Dodger Blue",         30, 144, 255),
        ("Deep Sky Blue",        0, 191, 255),
        ("Sky Blue",           135, 206, 235),
        ("Light Sky Blue",     135, 206, 250),
        ("Light Steel Blue",   176, 196, 222),
        ("Light Blue",         173, 216, 230),
        ("Powder Blue",        176, 224, 230),
        ("Periwinkle",         204, 204, 255),
        ("Baby Blue",          137, 207, 240),
        ("Carolina Blue",      123, 175, 212),
        ("Cornflower",         100, 149, 237),
        ("Columbia Blue",      155, 221, 255),
        ("Ice Blue",           153, 204, 255),
        ("Oxford Blue",          0,  33,  71),
        ("Denim",               21,  96, 189),
        ("Prussian Blue",        0,  49,  83),
        ("Yale Blue",           15,  77, 146),
        ("Egyptian Blue",       16,  52, 166),
        ("Klein Blue",           0,  47, 167),
        ("Space Blue",          29,  41,  81),
        ("Brandeis Blue",        0, 112, 255),
        ("French Blue",          0, 114, 187),
        ("Glaucous",           96,  130, 182),
        ("Maya Blue",          115, 194, 251),
        ("Jordy Blue",         138, 185, 241),
        ("Pastel Blue",        174, 198, 207),
        ("Steel",              75,  105, 120),

        // ── Purples & Violets ──
        ("Indigo",              75,   0, 130),
        ("Dark Violet",        148,   0, 211),
        ("Dark Magenta",       139,   0, 139),
        ("Dark Orchid",        153,  50, 204),
        ("Purple",             128,   0, 128),
        ("Medium Orchid",      186,  85, 211),
        ("Medium Purple",      147, 112, 219),
        ("Blue Violet",        138,  43, 226),
        ("Violet",             238, 130, 238),
        ("Plum",               221, 160, 221),
        ("Orchid",             218, 112, 214),
        ("Thistle",            216, 191, 216),
        ("Lavender",           230, 230, 250),
        ("Rebecca Purple",     102,  51, 153),
        ("Amethyst",           153, 102, 204),
        ("Wisteria",           201, 160, 220),
        ("Heliotrope",         223, 115, 255),
        ("Grape",              111,  45, 168),
        ("Eggplant",            97,  64,  81),
        ("Plum Purple",        142,  69, 133),
        ("Mulberry",           197,  75, 140),
        ("Royal Purple",       120,  81, 169),
        ("Persian Indigo",      50,  18, 122),
        ("Byzantium",          112,  41,  99),
        ("Tyrian Purple",      102,   2,  60),
        ("Imperial Purple",    102,   2, 102),
        ("Mauve Taupe",        145,  95, 109),
        ("Lilac",              200, 162, 200),
        ("Pastel Violet",      203, 153, 201),
        ("Pastel Purple",      179, 158, 181),
        ("Iris",               93,   63, 211),
        ("Pansy Purple",       120,  24,  74),
        ("African Violet",     178, 132, 190),
        ("Ultra Violet",       100,  83, 148),
        ("Deep Purple",        54,    0, 118),
        ("Electric Purple",    191,   0, 255),
        ("Neon Purple",        187,  59, 255),
        ("Palatinate",         104,  40, 120),
        ("Puce",               204, 136, 153),

        // ── Browns ──
        ("Saddle Brown",       139,  69,  19),
        ("Sienna",             160,  82,  45),
        ("Chocolate",          210, 105,  30),
        ("Brown",              165,  42,  42),
        ("Peru",               205, 133,  63),
        ("Sandy Brown",        244, 164,  96),
        ("Rosy Brown",         188, 143, 143),
        ("Burlywood",          222, 184, 135),
        ("Tan",                210, 180, 140),
        ("Dark Tan",           145, 129,  81),
        ("Beige",              245, 245, 220),
        ("Coffee",             111,  78,  55),
        ("Espresso",            78,  42,  20),
        ("Mocha",              124,  82,  47),
        ("Umber",              99,   81,  71),
        ("Raw Umber",          130, 102,  68),
        ("Burnt Umber",        138,  51,  36),
        ("Sepia",              112,  66,  20),
        ("Walnut",              94,  72,  46),
        ("Chestnut",           149,  69,  53),
        ("Cacao",              110,  54,  30),
        ("Mahogany",           192,  64,   0),
        ("Auburn",             165,  42,  42),
        ("Caramel",            255, 171, 119),
        ("Toffee",             176, 112,  48),
        ("Cider",              185, 121,   0),
        ("Hickory",            108,  78,  34),
        ("Pecan",              112,  68,  21),
        ("Hazel",              142, 118,  24),
        ("Fawn",               229, 170, 112),
        ("Camel",              193, 154, 107),
        ("Desert Sand",        237, 201, 175),
        ("Khaki Brown",        195, 176, 145),
        ("Sand",               194, 178, 128),
        ("Oatmeal",            214, 200, 179),
        ("Ecru",               194, 178, 128),
        ("Buff",               240, 220, 130),
        ("Biscuit",            241, 220, 188),

        // ── Earth Tones ──
        ("Terracotta",         204, 102,  51),
        ("Clay",               183, 110,  64),
        ("Brick",              175,  64,  53),
        ("Adobe",              189, 108,  72),
        ("Sandstone",          210, 180, 140),
        ("Desert",             193, 154, 107),
        ("Dust",               178, 153, 110),
        ("Driftwood",          175, 150, 112),
        ("Pebble",             192, 183, 163),
        ("Stone",              153, 146, 129),
        ("Mushroom",           186, 171, 150),
        ("Truffle",            107,  68,  35),

        // ── Metallics / Special ──
        ("Rose Gold",          183, 110, 121),
        ("Brass",              181, 166, 66),
        ("Antique Brass",      205, 149, 117),
        ("Burnished Gold",     169, 137,  12),

        // ── Neons & Brights ──
        ("Neon Pink",          255,  16, 240),
        ("Neon Orange",        255,  95,  31),
        ("Neon Yellow",        207, 255,   4),
        ("Neon Blue",           70, 102, 255),
        ("Neon Red",           255,  49,  49),
        ("Electric Lime",      206, 255,   0),
        ("Laser Lemon",        255, 255, 102),
        ("Radical Red",        255,  53,  94),
        ("Vivid Tangerine",    255, 160, 137),
        ("Shocking Pink",      252, 15,  192),
        ("Electric Violet",    143,   0, 255),
        ("Screaming Green",    118, 255,  60),
        ("Neon Coral",         255,  67,  95),
        ("Hot Magenta",        255,  29, 206),
    ]

    private static let namedColorsLab: [(name: String, lab: (L: Double, a: Double, b: Double))] =
        namedColors.map { ($0.name, sRGBtoLab(r: $0.r / 255.0, g: $0.g / 255.0, b: $0.b / 255.0)) }

    // ── Public API ──

    static func name(forHex hex: String) -> String {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6,
              let number = UInt64(cleaned, radix: 16) else {
            return "Unknown"
        }

        let r = Double((number >> 16) & 0xFF) / 255.0
        let g = Double((number >> 8) & 0xFF) / 255.0
        let b = Double(number & 0xFF) / 255.0

        let lab = sRGBtoLab(r: r, g: g, b: b)

        var bestName = "Unknown"
        var bestDelta = Double.greatestFiniteMagnitude

        for entry in namedColorsLab {
            let delta = ciede2000(lab, entry.lab)
            if delta < bestDelta {
                bestDelta = delta
                bestName = entry.name
            }
        }

        return bestName
    }

    // Also expose a distance function for external consumers
    static func perceptualDistance(hex1: String, hex2: String) -> Double {
        func parse(_ hex: String) -> (r: Double, g: Double, b: Double)? {
            var c = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if c.hasPrefix("#") { c.removeFirst() }
            guard c.count == 6, let n = UInt64(c, radix: 16) else { return nil }
            return (Double((n >> 16) & 0xFF) / 255.0, Double((n >> 8) & 0xFF) / 255.0, Double(n & 0xFF) / 255.0)
        }
        guard let c1 = parse(hex1), let c2 = parse(hex2) else { return .greatestFiniteMagnitude }
        let lab1 = sRGBtoLab(r: c1.r, g: c1.g, b: c1.b)
        let lab2 = sRGBtoLab(r: c2.r, g: c2.g, b: c2.b)
        return ciede2000(lab1, lab2)
    }

    // ── sRGB → XYZ → CIELAB conversion ────────────────────────────────

    static func sRGBtoLab(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
        // Linearize sRGB
        func linearize(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let rLin = linearize(r)
        let gLin = linearize(g)
        let bLin = linearize(b)

        // sRGB → XYZ (D65 illuminant)
        let x = (rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375) / 0.95047
        let y = (rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750) / 1.00000
        let z = (rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041) / 1.08883

        // XYZ → Lab
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0/3.0) : (903.3 * t + 16.0) / 116.0
        }
        let fx = f(x)
        let fy = f(y)
        let fz = f(z)

        let L = 116.0 * fy - 16.0
        let a = 500.0 * (fx - fy)
        let bVal = 200.0 * (fy - fz)
        return (L, a, bVal)
    }

    /// Chroma magnitude in CIELAB: sqrt(a² + b²).
    static func labChroma(_ lab: (L: Double, a: Double, b: Double)) -> Double {
        (lab.a * lab.a + lab.b * lab.b).squareRoot()
    }

    /// Inverse of `sRGBtoLab`: CIELAB → XYZ → linear sRGB → sRGB (D65), clamped to 0...1.
    static func labToSRGB(_ lab: (L: Double, a: Double, b: Double)) -> (r: Double, g: Double, b: Double) {
        let fy = (lab.L + 16.0) / 116.0
        let fx = fy + lab.a / 500.0
        let fz = fy - lab.b / 200.0

        func fInv(_ t: Double) -> Double {
            let t3 = t * t * t
            return t3 > 0.008856 ? t3 : (116.0 * t - 16.0) / 903.3
        }

        // XYZ (D65 illuminant)
        let x = fInv(fx) * 0.95047
        let y = lab.L > 903.3 * 0.008856 ? fy * fy * fy : lab.L / 903.3
        let z = fInv(fz) * 1.08883

        let rLin = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
        let gLin = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
        let bLin = x * 0.0556434 + y * -0.2040259 + z * 1.0572252

        func gammaEncode(_ c: Double) -> Double {
            let clamped = max(0.0, c)
            let v = clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
            return min(1.0, max(0.0, v))
        }

        return (gammaEncode(rLin), gammaEncode(gLin), gammaEncode(bLin))
    }

    // ── CIEDE2000 ΔE implementation ───────────────────────────────────

    private static func ciede2000(
        _ lab1: (L: Double, a: Double, b: Double),
        _ lab2: (L: Double, a: Double, b: Double)
    ) -> Double {
        let pi = Double.pi

        let lBar = (lab1.L + lab2.L) / 2.0
        let c1 = sqrt(lab1.a * lab1.a + lab1.b * lab1.b)
        let c2 = sqrt(lab2.a * lab2.a + lab2.b * lab2.b)
        let cBar = (c1 + c2) / 2.0

        let cBar7 = pow(cBar, 7.0)
        let g = 0.5 * (1.0 - sqrt(cBar7 / (cBar7 + pow(25.0, 7.0))))

        let a1P = lab1.a * (1.0 + g)
        let a2P = lab2.a * (1.0 + g)

        let c1P = sqrt(a1P * a1P + lab1.b * lab1.b)
        let c2P = sqrt(a2P * a2P + lab2.b * lab2.b)
        let cBarP = (c1P + c2P) / 2.0

        var h1P = atan2(lab1.b, a1P) * 180.0 / pi
        if h1P < 0 { h1P += 360.0 }
        var h2P = atan2(lab2.b, a2P) * 180.0 / pi
        if h2P < 0 { h2P += 360.0 }

        var hBarP: Double
        if abs(h1P - h2P) <= 180.0 {
            hBarP = (h1P + h2P) / 2.0
        } else if h1P + h2P < 360.0 {
            hBarP = (h1P + h2P + 360.0) / 2.0
        } else {
            hBarP = (h1P + h2P - 360.0) / 2.0
        }

        let dLP = lab2.L - lab1.L
        let dCP = c2P - c1P

        var dhP: Double
        if c1P * c2P == 0 {
            dhP = 0
        } else if abs(h2P - h1P) <= 180.0 {
            dhP = h2P - h1P
        } else if h2P - h1P > 180.0 {
            dhP = h2P - h1P - 360.0
        } else {
            dhP = h2P - h1P + 360.0
        }

        let dHP = 2.0 * sqrt(c1P * c2P) * sin(dhP * pi / 360.0)

        let t = 1.0
            - 0.17 * cos((hBarP - 30.0) * pi / 180.0)
            + 0.24 * cos(2.0 * hBarP * pi / 180.0)
            + 0.32 * cos((3.0 * hBarP + 6.0) * pi / 180.0)
            - 0.20 * cos((4.0 * hBarP - 63.0) * pi / 180.0)

        let lBar50sq = (lBar - 50.0) * (lBar - 50.0)
        let sL = 1.0 + 0.015 * lBar50sq / sqrt(20.0 + lBar50sq)
        let sC = 1.0 + 0.045 * cBarP
        let sH = 1.0 + 0.015 * cBarP * t

        let cBarP7 = pow(cBarP, 7.0)
        let rC = 2.0 * sqrt(cBarP7 / (cBarP7 + pow(25.0, 7.0)))
        let dTheta = 30.0 * exp(-((hBarP - 275.0) / 25.0) * ((hBarP - 275.0) / 25.0))
        let rT = -sin(2.0 * dTheta * pi / 180.0) * rC

        let valL = dLP / sL
        let valC = dCP / sC
        let valH = dHP / sH

        return sqrt(valL * valL + valC * valC + valH * valH + rT * valC * valH)
    }
}
