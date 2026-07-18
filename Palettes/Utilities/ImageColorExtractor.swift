import UIKit

enum ImageColorExtractor {

    struct ExtractedColor {
        let hex: String
        let name: String
    }

    // MARK: - Public API

    /// Extract the single dominant color from an image.
    static func extractDominantRGB(from image: UIImage) throws -> (r: Double, g: Double, b: Double) {
        let size = 80
        var pixels = getPixels(from: image, width: size, height: size)
        guard !pixels.isEmpty else { throw AppError.imageProcessingFailed }

        // Filter out near-black and near-white pixels for better extraction
        let filtered = filterExtremes(pixels)
        if filtered.isEmpty {
            // Fall back to unfiltered if everything got removed
            pixels = getPixels(from: image, width: size, height: size)
        } else {
            pixels = filtered
        }

        let centroids = kMeansPP(pixels: pixels, k: 6, iterations: 30)
        guard let dominant = centroids.first else { throw AppError.colorExtractionFailed }

        return (
            Double(clamped(Int(round(dominant.r)), 0, 255)),
            Double(clamped(Int(round(dominant.g)), 0, 255)),
            Double(clamped(Int(round(dominant.b)), 0, 255))
        )
    }

    /// Extract multiple distinct colors from an image for palette creation.
    static func extractColors(from image: UIImage, count: Int = 6) throws -> [ExtractedColor] {
        let size = 80
        var pixels = getPixels(from: image, width: size, height: size)
        guard !pixels.isEmpty else { throw AppError.imageProcessingFailed }

        // Filter out near-black and near-white to get more interesting colors
        let filtered = filterExtremes(pixels)
        if filtered.count > pixels.count / 4 {
            pixels = filtered
        }

        let clusterCount = min(count + 4, 14)
        let centroids = kMeansPP(pixels: pixels, k: clusterCount, iterations: 30)

        var results: [ExtractedColor] = []
        for centroid in centroids {
            let r = clamped(Int(round(centroid.r)), 0, 255)
            let g = clamped(Int(round(centroid.g)), 0, 255)
            let b = clamped(Int(round(centroid.b)), 0, 255)
            let hexStr = String(format: "%02X%02X%02X", r, g, b)

            // Use perceptual distance (CIEDE2000) to check similarity
            let tooSimilar = results.contains { existing in
                ColorNamer.perceptualDistance(hex1: existing.hex, hex2: "#\(hexStr)") < 10.0
            }
            if tooSimilar { continue }

            let name = ColorNamer.name(forHex: hexStr)
            results.append(ExtractedColor(hex: "#\(hexStr)", name: name))
            if results.count >= count { break }
        }

        guard !results.isEmpty else { throw AppError.colorExtractionFailed }
        return results
    }

    /// A reusable sampler that rasterizes an image once into an
    /// orientation-normalized, size-capped RGBA buffer, then answers many point
    /// queries cheaply. Build one per image and reuse it across a drag gesture
    /// instead of re-rendering the image on every touch move.
    struct PixelSampler {
        private let raw: [UInt8]
        private let width: Int
        private let height: Int

        /// Rasterizes `image` into a working buffer no larger than `maxDim` on
        /// its long side, top-left origin. Returns nil if it cannot be rendered.
        init?(image: UIImage, maxDim: CGFloat = 400) {
            let srcSize = image.size
            let longSide = max(srcSize.width, srcSize.height, 1)
            let scale = min(1, maxDim / longSide)
            let w = max(1, Int((srcSize.width * scale).rounded()))
            let h = max(1, Int((srcSize.height * scale).rounded()))

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
            let normalized = renderer.image { _ in
                image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            guard let cg = normalized.cgImage else { return nil }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var buffer = [UInt8](repeating: 0, count: w * h * 4)
            guard let ctx = CGContext(
                data: &buffer,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

            self.raw = buffer
            self.width = w
            self.height = h
        }

        /// Sample a color at a normalized point, averaging a small neighborhood
        /// for stability against JPEG noise / grain.
        ///
        /// - Parameters:
        ///   - point: normalized image coordinate, (0,0) = top-left, (1,1) = bottom-right.
        ///            Out-of-range values clamp to the nearest edge pixel.
        ///   - radius: half-size of the averaged square neighborhood in working pixels.
        func color(at point: CGPoint, radius: Int = 2) -> (r: Double, g: Double, b: Double) {
            let cx = ImageColorExtractor.clamped(Int((point.x * Double(width - 1)).rounded()), 0, width - 1)
            let cy = ImageColorExtractor.clamped(Int((point.y * Double(height - 1)).rounded()), 0, height - 1)

            var rSum = 0.0, gSum = 0.0, bSum = 0.0, n = 0.0
            for dy in -radius...radius {
                for dx in -radius...radius {
                    let px = ImageColorExtractor.clamped(cx + dx, 0, width - 1)
                    let py = ImageColorExtractor.clamped(cy + dy, 0, height - 1)
                    let offset = (py * width + px) * 4
                    let alpha = Double(raw[offset + 3])
                    guard alpha > 0 else { continue }
                    rSum += Double(raw[offset])
                    gSum += Double(raw[offset + 1])
                    bSum += Double(raw[offset + 2])
                    n += 1
                }
            }
            guard n > 0 else { return (128, 128, 128) }
            return (rSum / n, gSum / n, bSum / n)
        }
    }

    /// Sample a color from a specific point in the image, averaging a small
    /// neighborhood for stability against JPEG noise / grain.
    ///
    /// Convenience for one-off samples. For repeated sampling of the same image
    /// (e.g. a drag gesture) build a `PixelSampler` once and reuse it, rather
    /// than paying the per-call rasterization cost here.
    ///
    /// - Parameters:
    ///   - point: normalized image coordinate, (0,0) = top-left, (1,1) = bottom-right.
    ///            Out-of-range values clamp to the nearest edge pixel.
    ///   - radius: half-size of the averaged square neighborhood in working pixels.
    static func sampleColor(
        from image: UIImage,
        at point: CGPoint,
        radius: Int = 2
    ) -> (r: Double, g: Double, b: Double) {
        guard let sampler = PixelSampler(image: image) else { return (128, 128, 128) }
        return sampler.color(at: point, radius: radius)
    }

    // MARK: - Helpers

    private static func clamped(_ value: Int, _ low: Int, _ high: Int) -> Int {
        max(low, min(high, value))
    }

    /// Filter out near-black (luminance < 15) and near-white (luminance > 240) pixels
    private static func filterExtremes(_ pixels: [(r: Double, g: Double, b: Double)]) -> [(r: Double, g: Double, b: Double)] {
        return pixels.filter { (px: (r: Double, g: Double, b: Double)) -> Bool in
            // Relative luminance approximation
            let lum = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b
            return lum > 15 && lum < 240
        }
    }

    // MARK: - Pixel Extraction

    private static func getPixels(from image: UIImage, width: Int, height: Int) -> [(r: Double, g: Double, b: Double)] {
        guard let cgImage = image.cgImage else { return [] }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [(r: Double, g: Double, b: Double)] = []
        pixels.reserveCapacity(width * height)
        for i in 0..<(width * height) {
            let offset = i * 4
            let alpha = Double(rawData[offset + 3])
            guard alpha > 0 else { continue } // Skip fully transparent pixels
            pixels.append((
                Double(rawData[offset]),
                Double(rawData[offset + 1]),
                Double(rawData[offset + 2])
            ))
        }
        return pixels
    }

    // MARK: - K-Means++ Clustering

    /// K-means with k-means++ initialization for better convergence.
    private static func kMeansPP(
        pixels: [(r: Double, g: Double, b: Double)],
        k: Int,
        iterations: Int
    ) -> [(r: Double, g: Double, b: Double)] {
        guard !pixels.isEmpty, k > 0 else { return [] }

        let actualK = min(k, pixels.count)

        // ── k-means++ initialization ──
        var centroids: [(r: Double, g: Double, b: Double)] = []

        // Use a simple deterministic seed: pick the pixel closest to the average
        let avgR = pixels.reduce(0.0) { acc, px in acc + px.r } / Double(pixels.count)
        let avgG = pixels.reduce(0.0) { acc, px in acc + px.g } / Double(pixels.count)
        let avgB = pixels.reduce(0.0) { acc, px in acc + px.b } / Double(pixels.count)

        var bestIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, px) in pixels.enumerated() {
            let d = sqDist(px, (avgR, avgG, avgB))
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        centroids.append(pixels[bestIdx])

        // Remaining centroids: pick furthest point from existing centroids
        // (simplified k-means++ that avoids randomness for deterministic results)
        while centroids.count < actualK {
            var maxMinDist = -1.0
            var nextIdx = 0
            for (i, px) in pixels.enumerated() {
                let minDist = centroids.map { c in sqDist(px, c) }.min() ?? 0
                if minDist > maxMinDist {
                    maxMinDist = minDist
                    nextIdx = i
                }
            }
            centroids.append(pixels[nextIdx])
        }

        // ── Standard k-means iterations ──
        var clusterCounts = [Int](repeating: 0, count: actualK)

        for _ in 0..<iterations {
            var sums = Array(repeating: (r: 0.0, g: 0.0, b: 0.0), count: actualK)
            var counts = [Int](repeating: 0, count: actualK)

            for pixel in pixels {
                var minDist = Double.greatestFiniteMagnitude
                var bestCluster = 0
                for j in 0..<actualK {
                    let d = sqDist(pixel, centroids[j])
                    if d < minDist { minDist = d; bestCluster = j }
                }
                sums[bestCluster].r += pixel.r
                sums[bestCluster].g += pixel.g
                sums[bestCluster].b += pixel.b
                counts[bestCluster] += 1
            }

            for j in 0..<actualK where counts[j] > 0 {
                let n = Double(counts[j])
                centroids[j] = (sums[j].r / n, sums[j].g / n, sums[j].b / n)
            }
            clusterCounts = counts
        }

        // Sort by cluster size (most pixels first = most dominant)
        let paired = zip(centroids, clusterCounts).sorted { $0.1 > $1.1 }
        return paired.map { $0.0 }
    }

    /// Squared RGB distance (fast, for cluster assignment only)
    private static func sqDist(
        _ p1: (r: Double, g: Double, b: Double),
        _ p2: (r: Double, g: Double, b: Double)
    ) -> Double {
        let dr = p1.r - p2.r
        let dg = p1.g - p2.g
        let db = p1.b - p2.b
        return dr * dr + dg * dg + db * db
    }
}
