import Testing
import UIKit
@testable import Palettes

@MainActor
struct PhotoPinLocatorTests {
    private func splitImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 50, y: 0, width: 50, height: 50))
        }
    }

    @Test func pinsLandOnTheirColor() throws {
        let sampler = try #require(ImageColorExtractor.PixelSampler(image: splitImage()))
        let points = PhotoPinLocator.locate(hexes: ["#FF0000", "#0000FF"], in: sampler)
        #expect(points.count == 2)
        #expect(points[0].x < 0.5)
        #expect(points[1].x > 0.5)
    }

    @Test func pointsAreNormalized() throws {
        let sampler = try #require(ImageColorExtractor.PixelSampler(image: splitImage()))
        for p in PhotoPinLocator.locate(hexes: ["#00FF00"], in: sampler) {
            #expect((0...1).contains(p.x) && (0...1).contains(p.y))
        }
    }
}
