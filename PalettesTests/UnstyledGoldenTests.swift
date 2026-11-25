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

    /// Recorded on `dev` @ afa556b, before styles existed.
    private static let golden: UInt64 = 0x9B9626D397E3D195
}
