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

        let clusters = kMeansPP(points: pixels.map { ($0.r, $0.g, $0.b) }, k: 6, iterations: 30)
        guard let dominant = clusters.first?.centroid else { throw AppError.colorExtractionFailed }

        return (
            Double(clamped(Int(round(dominant.0)), 0, 255)),
            Double(clamped(Int(round(dominant.1)), 0, 255)),
            Double(clamped(Int(round(dominant.2)), 0, 255))
        )
    }

    /// Extract multiple distinct colors from an image for palette creation.
    ///
    /// Clusters in CIELAB space so small-but-vivid accents (a bright logo
    /// swatch, a single saturated flower) survive alongside large muted
    /// regions, then ranks by a salience score — `share * (0.5 + chroma/100)`
    /// clamped to a chroma boost of at most 1.0 — rather than raw pixel share
    /// alone. Clusters covering under 0.5% of the image are dropped outright
    /// (speckle/noise), and dedup runs in salience order so the more salient
    /// color always wins a collision.
    static func extractColors(from image: UIImage, count: Int = 6) throws -> [ExtractedColor] {
        let size = 160
        var pixels = getPixels(from: image, width: size, height: size)
        guard !pixels.isEmpty else { throw AppError.imageProcessingFailed }

        // Filter out near-black and near-white to get more interesting colors
        let filtered = filterExtremes(pixels)
        if filtered.count > pixels.count / 4 {
            pixels = filtered
        }

        let totalPixels = pixels.count
        let labPoints = pixels.map { px -> (Double, Double, Double) in
            let lab = ColorNamer.sRGBtoLab(r: px.r / 255.0, g: px.g / 255.0, b: px.b / 255.0)
            return (lab.L, lab.a, lab.b)
        }

        let clusterCount = min(count + 4, 14)
        let clusters = kMeansPP(points: labPoints, k: clusterCount, iterations: 30)

        struct Candidate {
            let hex: String
            let salience: Double
        }

        var candidates: [Candidate] = []
        for cluster in clusters {
            let share = Double(cluster.count) / Double(totalPixels)
            guard share >= 0.005 else { continue }

            let labCentroid = (L: cluster.centroid.0, a: cluster.centroid.1, b: cluster.centroid.2)
            let chromaBoost = min(1.0, ColorNamer.labChroma(labCentroid) / 100.0)
            let salience = share * (0.5 + chromaBoost)

            let rgb = ColorNamer.labToSRGB(labCentroid)
            let r = clamped(Int(round(rgb.r * 255.0)), 0, 255)
            let g = clamped(Int(round(rgb.g * 255.0)), 0, 255)
            let b = clamped(Int(round(rgb.b * 255.0)), 0, 255)
            let hexStr = String(format: "%02X%02X%02X", r, g, b)

            candidates.append(Candidate(hex: hexStr, salience: salience))
        }

        candidates.sort { $0.salience > $1.salience }

        var results: [ExtractedColor] = []
        for candidate in candidates {
            // Use perceptual distance (CIEDE2000) to check similarity. Iterating
            // in salience order means the higher-salience color already in
            // `results` always wins a collision.
            let tooSimilar = results.contains { existing in
                ColorNamer.perceptualDistance(hex1: existing.hex, hex2: "#\(candidate.hex)") < 10.0
            }
            if tooSimilar { continue }

            let name = ColorNamer.name(forHex: candidate.hex)
            results.append(ExtractedColor(hex: "#\(candidate.hex)", name: name))
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
    ///
    /// Generalized over any 3-component tuple (RGB triples for the dominant-color
    /// path, CIELAB triples for palette extraction) rather than duplicated per
    /// color space. Returns clusters sorted by pixel count descending, each
    /// paired with its member count so callers can compute pixel share.
    private static func kMeansPP(
        points: [(Double, Double, Double)],
        k: Int,
        iterations: Int
    ) -> [(centroid: (Double, Double, Double), count: Int)] {
        guard !points.isEmpty, k > 0 else { return [] }

        let actualK = min(k, points.count)

        // ── k-means++ initialization ──
        var centroids: [(Double, Double, Double)] = []

        // Use a simple deterministic seed: pick the point closest to the average
        let avg0 = points.reduce(0.0) { acc, p in acc + p.0 } / Double(points.count)
        let avg1 = points.reduce(0.0) { acc, p in acc + p.1 } / Double(points.count)
        let avg2 = points.reduce(0.0) { acc, p in acc + p.2 } / Double(points.count)

        var bestIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, p) in points.enumerated() {
            let d = sqDist(p, (avg0, avg1, avg2))
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        centroids.append(points[bestIdx])

        // Remaining centroids: pick furthest point from existing centroids
        // (simplified k-means++ that avoids randomness for deterministic results)
        while centroids.count < actualK {
            var maxMinDist = -1.0
            var nextIdx = 0
            for (i, p) in points.enumerated() {
                let minDist = centroids.map { c in sqDist(p, c) }.min() ?? 0
                if minDist > maxMinDist {
                    maxMinDist = minDist
                    nextIdx = i
                }
            }
            centroids.append(points[nextIdx])
        }

        // ── Standard k-means iterations ──
        var clusterCounts = [Int](repeating: 0, count: actualK)

        for _ in 0..<iterations {
            var sums = Array(repeating: (0.0, 0.0, 0.0), count: actualK)
            var counts = [Int](repeating: 0, count: actualK)

            for point in points {
                var minDist = Double.greatestFiniteMagnitude
                var bestCluster = 0
                for j in 0..<actualK {
                    let d = sqDist(point, centroids[j])
                    if d < minDist { minDist = d; bestCluster = j }
                }
                sums[bestCluster].0 += point.0
                sums[bestCluster].1 += point.1
                sums[bestCluster].2 += point.2
                counts[bestCluster] += 1
            }

            for j in 0..<actualK where counts[j] > 0 {
                let n = Double(counts[j])
                centroids[j] = (sums[j].0 / n, sums[j].1 / n, sums[j].2 / n)
            }
            clusterCounts = counts
        }

        // Sort by cluster size (most points first = most dominant)
        let paired = zip(centroids, clusterCounts).sorted { $0.1 > $1.1 }
        return paired.map { (centroid: $0.0, count: $0.1) }
    }

    /// Squared distance in the caller's 3-component space (fast, for cluster
    /// assignment only — used for both RGB and Lab triples).
    private static func sqDist(
        _ p1: (Double, Double, Double),
        _ p2: (Double, Double, Double)
    ) -> Double {
        let d0 = p1.0 - p2.0
        let d1 = p1.1 - p2.1
        let d2 = p1.2 - p2.2
        return d0 * d0 + d1 * d1 + d2 * d2
    }
}
