import Testing
import UIKit
@testable import Palettes

@MainActor
struct UIImageDownsampleTests {
    /// An image whose pixel size equals its point size (scale 1).
    private func image(_ width: CGFloat, _ height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func smallImageIsReturnedUntouched() {
        let small = image(1000, 800)
        #expect(small.downsampled(longSide: 2048) === small)
        let exact = image(2048, 1024)
        #expect(exact.downsampled(longSide: 2048) === exact)
    }

    @Test func landscapeLongSideBecomesTheLimitAndAspectIsKept() {
        let result = image(4000, 3000).downsampled(longSide: 2048)
        #expect(result.size == CGSize(width: 2048, height: 1536))
        #expect(result.scale == 1)
    }

    @Test func portraitLongSideBecomesTheLimitAndAspectIsKept() {
        let result = image(3000, 4000).downsampled(longSide: 2048)
        #expect(result.size == CGSize(width: 1536, height: 2048))
    }

    @Test func dataIsDecodedToAThumbnailWithAspectKept() throws {
        let data = try #require(image(4000, 3000).pngData())
        let result = try #require(UIImage.downsampled(from: data, longSide: 2048))
        #expect(result.size == CGSize(width: 2048, height: 1536))
    }

    @Test func smallDataIsNotEnlarged() throws {
        let data = try #require(image(1000, 500).pngData())
        let result = try #require(UIImage.downsampled(from: data, longSide: 2048))
        #expect(result.size == CGSize(width: 1000, height: 500))
    }

    @Test func garbageDataGivesNil() {
        #expect(UIImage.downsampled(from: Data([1, 2, 3]), longSide: 2048) == nil)
    }
}
