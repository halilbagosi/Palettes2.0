//
//  UnstyledGoldenTests.swift
//  PalettesTests
//
//  Styles must not change a single unstyled build. This pins a matrix of
//  today's outputs (schemes × anchors × sizes × seeds) as one FNV-1a hash.
//  If it fails after an intentional change to unstyled building, re-record:
//  the failure message prints the new hash.
//

import XCTest
@testable import Palettes

@MainActor
final class UnstyledGoldenTests: XCTestCase {

    static func signature() -> String {
        var lines: [String] = []
        let anchorSets: [[String]] = [[], ["#3060A0"], ["#808080"], ["#3366CC", "#CC6633"]]
        for scheme in [HarmonyScheme.auto, .complementary, .monochromatic, .uiLight, .uiDark] {
            for anchors in anchorSets {
                for size in [4, 8] {
                    for seed: UInt64 in [1, 7] {
                        let built = PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: size, scheme: scheme, hue: 200, seed: seed))
                        lines.append([scheme.rawValue, anchors.joined(separator: ","), "\(size)", "\(seed)",
                                      built.scheme.rawValue, built.hexes.joined(separator: ","), built.roles.joined(separator: ",")]
                            .joined(separator: "|"))
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    func testUnstyledBuildsAreUnchanged() {
        let hash = Self.fnv1a(Self.signature())
        XCTAssertEqual(hash, Self.golden, "unstyled output changed; new hash 0x\(String(hash, radix: 16, uppercase: true))")
    }

    /// Recorded at 5db38d9 (after Task 1, before any builder change).
    private static let golden: UInt64 = 0x9B9626D397E3D195

    /// Seed-chosen hues and non-balanced tones, which the first matrix leaves out.
    static func toneSignature() -> String {
        var lines: [String] = []
        let tones = [PaletteTone(lightness: .dark), PaletteTone(chroma: .muted), PaletteTone(lightness: .light, chroma: .vivid)]
        for scheme in [HarmonyScheme.auto, .complementary, .monochromatic, .uiLight, .uiDark] {
            for anchors in [[], ["#3060A0"]] as [[String]] {
                for (toneIndex, tone) in tones.enumerated() {
                    for hue in [nil, 200.0] as [Double?] {
                        for seed: UInt64 in [1, 7] {
                            let built = PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: 8, scheme: scheme, tone: tone, hue: hue, seed: seed))
                            lines.append([scheme.rawValue, anchors.joined(separator: ","), "\(toneIndex)", hue.map { "\($0)" } ?? "seed", "\(seed)",
                                          built.scheme.rawValue, built.hexes.joined(separator: ","), built.roles.joined(separator: ",")]
                                .joined(separator: "|"))
                        }
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    func testUnstyledToneAndSeedHueBuildsAreUnchanged() {
        let hash = Self.fnv1a(Self.toneSignature())
        XCTAssertEqual(hash, Self.toneGolden, "unstyled tone output changed; new hash 0x\(String(hash, radix: 16, uppercase: true))")
    }

    /// Recorded at 24119ef, whose unstyled path review confirmed unchanged from 5db38d9.
    private static let toneGolden: UInt64 = 0x6FBCEBA967A991F1
}
