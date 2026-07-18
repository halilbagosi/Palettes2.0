# Photo Loupe Eyedropper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users press-and-drag a magnifier loupe on a scanned photo to sample any specific color, overriding the auto-extracted dominant color, while the existing adjustment sliders keep working on the sampled color.

**Architecture:** Three isolated pieces. (1) A pure pixel-sampling function on `ImageColorExtractor` that averages a small region around a normalized point. (2) A pure coordinate-mapping helper (`PhotoLoupeGeometry`) that converts a touch point in an aspect-fit image view into a normalized (0–1) image point. (3) A self-contained SwiftUI `PhotoLoupeView` that renders the image, animates fill→fit while dragging, draws the magnifier loupe, and reports sampled colors out via callbacks. `ColorInputView` wires the callbacks into its existing scan state (`baseR/G/B`, sliders, `scanName`) so both the auto-extract path and the loupe path converge on identical downstream state.

**Tech Stack:** SwiftUI, UIKit (`UIImage`, `UIGraphicsImageRenderer`, `CGContext`), XCTest.

## Global Constraints

- Deployment target is **iOS 17.0**. Any iOS 26-only API must be gated behind `@available(iOS 26.0, *)` via `Palettes/Compatibility/` shims. Build the loupe with standard SwiftUI available on iOS 17 (`DragGesture`, `scaleEffect`, `clipShape`, `.aspectRatio`).
- New Swift files are auto-included via Xcode synchronized file groups. **Do not hand-edit `Palettes.xcodeproj/project.pbxproj`** to add files.
- MVVM: `AppData` is the single source of truth. This feature reads no persistence directly; it only feeds `ColorInputView`'s local `@State`.
- Preserve the `PaletteViewModel` parallel-array alignment invariant (not touched by this feature, but do not break it).
- Tests use `XCTest` with `@testable import Palettes`, in the `PalettesTests` target.
- Branch: `feature/photo-loupe-eyedropper` (feature → dev → staging → main). Never commit to `dev`/`main` directly.
- Build/test command (substitute an available simulator from `xcrun simctl list devices available`):
  `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"`

---

## File Structure

- **Modify** `Palettes/Utilities/ImageColorExtractor.swift` — add `sampleColor(from:at:radius:)`.
- **Create** `Palettes/Utilities/PhotoLoupeGeometry.swift` — pure aspect-fit coordinate mapping.
- **Create** `Palettes/Views/Components/PhotoLoupeView.swift` — the interactive loupe SwiftUI view.
- **Modify** `Palettes/Views/Components/ColorInputView.swift` — swap the static scan image for `PhotoLoupeView` in `.dominant` mode and wire callbacks.
- **Create** `PalettesTests/ImageColorSampleTests.swift` — tests for `sampleColor`.
- **Create** `PalettesTests/PhotoLoupeGeometryTests.swift` — tests for the mapping helper.

---

## Task 1: Pixel-sampling utility on `ImageColorExtractor`

**Files:**
- Modify: `Palettes/Utilities/ImageColorExtractor.swift`
- Test: `PalettesTests/ImageColorSampleTests.swift` (create)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `ImageColorExtractor.sampleColor(from image: UIImage, at point: CGPoint, radius: Int = 2) -> (r: Double, g: Double, b: Double)`. `point` is normalized 0–1 image space, `(0,0)` = top-left, `(1,1)` = bottom-right. Returns averaged RGB in 0–255. Out-of-range points clamp to the nearest edge pixel.

- [ ] **Step 1: Write the failing tests**

Create `PalettesTests/ImageColorSampleTests.swift`:

```swift
//
//  ImageColorSampleTests.swift
//  PalettesTests
//

import XCTest
import UIKit
@testable import Palettes

final class ImageColorSampleTests: XCTestCase {

    /// Draws a `size`×`size` image whose left half is `left` and right half is `right`.
    private func splitImage(left: UIColor, right: UIColor, size: CGFloat = 40) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            left.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size / 2, height: size))
            right.setFill()
            ctx.fill(CGRect(x: size / 2, y: 0, width: size / 2, height: size))
        }
    }

    private func solidImage(_ color: UIColor, size: CGFloat = 40) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    func testSamplesSolidColorAnywhere() {
        let img = solidImage(.red)
        let c = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(c.r, 255, accuracy: 4)
        XCTAssertEqual(c.g, 0, accuracy: 4)
        XCTAssertEqual(c.b, 0, accuracy: 4)
    }

    func testSamplesLeftAndRightHalvesDistinctly() {
        let img = splitImage(left: .red, right: .blue)
        let left = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.2, y: 0.5))
        let right = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.8, y: 0.5))
        XCTAssertEqual(left.r, 255, accuracy: 6)
        XCTAssertEqual(left.b, 0, accuracy: 6)
        XCTAssertEqual(right.b, 255, accuracy: 6)
        XCTAssertEqual(right.r, 0, accuracy: 6)
    }

    func testTopLeftOriginConvention() {
        // Top half green, bottom half black — verifies (0,0) is the top.
        let size: CGFloat = 40
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size / 2))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: size / 2, width: size, height: size / 2))
        }
        let top = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.5, y: 0.1))
        XCTAssertEqual(top.g, 255, accuracy: 6)
        XCTAssertEqual(top.r, 0, accuracy: 6)
    }

    func testOutOfBoundsPointClampsWithoutCrashing() {
        let img = solidImage(.red)
        let c = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: -0.5, y: 1.9))
        XCTAssertEqual(c.r, 255, accuracy: 4)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>" -only-testing:PalettesTests/ImageColorSampleTests`
Expected: FAIL to compile — `sampleColor` does not exist yet.

- [ ] **Step 3: Implement `sampleColor`**

In `Palettes/Utilities/ImageColorExtractor.swift`, add inside the `enum ImageColorExtractor` body (e.g. after `extractColors`, before `// MARK: - Helpers`):

```swift
    /// Sample a color from a specific point in the image, averaging a small
    /// neighborhood for stability against JPEG noise / grain.
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
        // Render into an orientation-normalized, size-capped bitmap so the
        // pixel buffer is top-left origin and bounded in memory.
        let maxDim: CGFloat = 400
        let srcSize = image.size
        let longSide = max(srcSize.width, srcSize.height, 1)
        let scale = min(1, maxDim / longSide)
        let workW = max(1, Int((srcSize.width * scale).rounded()))
        let workH = max(1, Int((srcSize.height * scale).rounded()))

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: workW, height: workH))
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: workW, height: workH))
        }
        guard let cg = normalized.cgImage else { return (128, 128, 128) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: workW * workH * 4)
        guard let ctx = CGContext(
            data: &raw,
            width: workW,
            height: workH,
            bitsPerComponent: 8,
            bytesPerRow: workW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (128, 128, 128) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: workW, height: workH))

        let cx = clamped(Int((point.x * Double(workW - 1)).rounded()), 0, workW - 1)
        let cy = clamped(Int((point.y * Double(workH - 1)).rounded()), 0, workH - 1)

        var rSum = 0.0, gSum = 0.0, bSum = 0.0, n = 0.0
        for dy in -radius...radius {
            for dx in -radius...radius {
                let px = clamped(cx + dx, 0, workW - 1)
                let py = clamped(cy + dy, 0, workH - 1)
                let offset = (py * workW + px) * 4
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
```

Note: `clamped(_:_:_:)` already exists as a `private static` helper in this file and is reused here.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>" -only-testing:PalettesTests/ImageColorSampleTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Palettes/Utilities/ImageColorExtractor.swift PalettesTests/ImageColorSampleTests.swift
git commit -m "feat: add ImageColorExtractor.sampleColor for point sampling"
```

---

## Task 2: Coordinate-mapping helper `PhotoLoupeGeometry`

**Files:**
- Create: `Palettes/Utilities/PhotoLoupeGeometry.swift`
- Test: `PalettesTests/PhotoLoupeGeometryTests.swift` (create)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `PhotoLoupeGeometry.normalizedPoint(forViewPoint viewPoint: CGPoint, viewSize: CGSize, imageSize: CGSize) -> CGPoint`. Assumes the image is displayed **aspect-fit** (letterboxed) within `viewSize`. Returns a normalized point in 0–1 image space, clamped to `[0,1]` when the touch is over a letterbox bar.

- [ ] **Step 1: Write the failing tests**

Create `PalettesTests/PhotoLoupeGeometryTests.swift`:

```swift
//
//  PhotoLoupeGeometryTests.swift
//  PalettesTests
//

import XCTest
import CoreGraphics
@testable import Palettes

final class PhotoLoupeGeometryTests: XCTestCase {

    func testCenterMapsToCenterForSquareInSquare() {
        let p = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 100),
            viewSize: CGSize(width: 200, height: 200),
            imageSize: CGSize(width: 500, height: 500)
        )
        XCTAssertEqual(p.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.001)
    }

    func testLandscapeImageInSquareViewHasVerticalBars() {
        // 2:1 image in 200×200 view: displayed 200 wide, 100 tall, 50pt bars top/bottom.
        let view = CGSize(width: 200, height: 200)
        let image = CGSize(width: 400, height: 200)

        // Center of the displayed image (y = 100) → (0.5, 0.5).
        let center = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 100), viewSize: view, imageSize: image)
        XCTAssertEqual(center.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(center.y, 0.5, accuracy: 0.001)

        // Top edge of displayed image is at y = 50 → normalized y = 0.
        let topEdge = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 50), viewSize: view, imageSize: image)
        XCTAssertEqual(topEdge.y, 0.0, accuracy: 0.001)

        // A touch in the top bar (y = 10) clamps to 0.
        let inBar = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 10), viewSize: view, imageSize: image)
        XCTAssertEqual(inBar.y, 0.0, accuracy: 0.001)
    }

    func testPortraitImageInSquareViewHasHorizontalBars() {
        // 1:2 image in 200×200 view: displayed 100 wide, 200 tall, 50pt bars left/right.
        let view = CGSize(width: 200, height: 200)
        let image = CGSize(width: 200, height: 400)

        // Left edge of displayed image at x = 50 → normalized x = 0.
        let leftEdge = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 50, y: 100), viewSize: view, imageSize: image)
        XCTAssertEqual(leftEdge.x, 0.0, accuracy: 0.001)

        // A touch in the right bar (x = 190) clamps to 1.
        let inBar = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 190, y: 100), viewSize: view, imageSize: image)
        XCTAssertEqual(inBar.x, 1.0, accuracy: 0.001)
    }

    func testDegenerateSizesDoNotCrash() {
        let p = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 10, y: 10),
            viewSize: .zero,
            imageSize: .zero
        )
        XCTAssertTrue(p.x >= 0 && p.x <= 1)
        XCTAssertTrue(p.y >= 0 && p.y <= 1)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>" -only-testing:PalettesTests/PhotoLoupeGeometryTests`
Expected: FAIL to compile — `PhotoLoupeGeometry` does not exist.

- [ ] **Step 3: Implement `PhotoLoupeGeometry`**

Create `Palettes/Utilities/PhotoLoupeGeometry.swift`:

```swift
import CoreGraphics

/// Pure geometry for mapping a touch point inside an aspect-fit image view
/// onto a normalized (0–1) image coordinate. Isolated from SwiftUI so the
/// letterbox math is unit-testable.
enum PhotoLoupeGeometry {

    /// Maps a point in view space to a normalized image point, assuming the
    /// image is displayed aspect-fit (letterboxed) inside `viewSize`.
    /// Touches over letterbox bars clamp to `[0,1]`.
    static func normalizedPoint(
        forViewPoint viewPoint: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize
    ) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let displayW: CGFloat
        let displayH: CGFloat
        if imageAspect > viewAspect {
            // Image fills the view width; bars top and bottom.
            displayW = viewSize.width
            displayH = viewSize.width / imageAspect
        } else {
            // Image fills the view height; bars left and right.
            displayH = viewSize.height
            displayW = viewSize.height * imageAspect
        }
        let originX = (viewSize.width - displayW) / 2
        let originY = (viewSize.height - displayH) / 2

        let nx = (viewPoint.x - originX) / displayW
        let ny = (viewPoint.y - originY) / displayH
        return CGPoint(x: clamp01(nx), y: clamp01(ny))
    }

    private static func clamp01(_ v: CGFloat) -> CGFloat {
        min(1, max(0, v))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>" -only-testing:PalettesTests/PhotoLoupeGeometryTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Palettes/Utilities/PhotoLoupeGeometry.swift PalettesTests/PhotoLoupeGeometryTests.swift
git commit -m "feat: add PhotoLoupeGeometry aspect-fit coordinate mapping"
```

---

## Task 3: `PhotoLoupeView` interactive loupe

**Files:**
- Create: `Palettes/Views/Components/PhotoLoupeView.swift`

**Interfaces:**
- Consumes: `ImageColorExtractor.sampleColor(from:at:radius:)` (Task 1), `PhotoLoupeGeometry.normalizedPoint(forViewPoint:viewSize:imageSize:)` (Task 2).
- Produces:
  ```swift
  PhotoLoupeView(
      image: UIImage,
      onSample: (_ rgb: (r: Double, g: Double, b: Double)) -> Void,
      onSampleEnd: () -> Void
  )
  ```
  Renders `image` aspect-**fill** at rest and aspect-**fit** while dragging. During a drag it calls `onSample` live with the sampled RGB (0–255); on release it calls `onSampleEnd` once. The view owns no scan/adjustment/naming state.

**Note on testing:** This view is a visual/interactive component. Its testable logic lives in Tasks 1 and 2 (both unit-tested). This task is verified by a SwiftUI `#Preview` and a build + manual run, not by unit tests — a magnifier's rendered pixels are not meaningfully unit-testable.

- [ ] **Step 1: Create the view**

Create `Palettes/Views/Components/PhotoLoupeView.swift`:

```swift
import SwiftUI

/// Interactive photo eyedropper. Displays an image and lets the user press
/// and drag a magnifier loupe to sample any point's color. Reports sampled
/// colors out via callbacks and owns none of the host's scan state.
///
/// At rest the image is aspect-fill (matching the surrounding preview look).
/// While dragging it animates to aspect-fit so every region is reachable, and
/// `PhotoLoupeGeometry` maps the touch to a normalized image point.
struct PhotoLoupeView: View {
    let image: UIImage
    var cornerRadius: CGFloat = 20
    let onSample: (_ rgb: (r: Double, g: Double, b: Double)) -> Void
    let onSampleEnd: () -> Void

    @State private var touchPoint: CGPoint?
    @State private var isDragging = false
    @State private var loupeColor: Color = .gray

    private let loupeDiameter: CGFloat = 110
    private let loupeZoom: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: isDragging ? .fit : .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .animation(.easeInOut(duration: 0.2), value: isDragging)

                if isDragging, let pt = touchPoint {
                    loupe(at: pt, in: geo.size)
                }

                if !isDragging {
                    hint
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geo.size))
        }
    }

    // MARK: - Hint

    private var hint: some View {
        VStack {
            Spacer()
            Label("Drag to pick a color", systemImage: "eyedropper")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 10)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Loupe

    private func loupe(at point: CGPoint, in size: CGSize) -> some View {
        // Position the loupe above the finger; flip below when near the top.
        let gap: CGFloat = loupeDiameter / 2 + 28
        let above = point.y > loupeDiameter + 24
        let centerY = above ? point.y - gap : point.y + gap

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .scaleEffect(loupeZoom)
                .offset(
                    x: (size.width / 2 - point.x) * loupeZoom,
                    y: (size.height / 2 - point.y) * loupeZoom
                )
                .frame(width: loupeDiameter, height: loupeDiameter)
                .clipShape(Circle())

            // Crosshair
            Rectangle().fill(.white).frame(width: 1, height: 14).blendMode(.difference)
            Rectangle().fill(.white).frame(width: 14, height: 1).blendMode(.difference)

            Circle()
                .stroke(Color.white, lineWidth: 3)
            Circle()
                .stroke(Color.black.opacity(0.25), lineWidth: 1)
        }
        .frame(width: loupeDiameter, height: loupeDiameter)
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(loupeColor)
                .frame(width: 44, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white, lineWidth: 1.5)
                )
                .offset(y: 18)
        }
        .shadow(radius: 6)
        .position(x: point.x, y: centerY)
        .allowsHitTesting(false)
    }

    // MARK: - Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging { isDragging = true }
                touchPoint = value.location
                let normalized = PhotoLoupeGeometry.normalizedPoint(
                    forViewPoint: value.location,
                    viewSize: size,
                    imageSize: image.size
                )
                let rgb = ImageColorExtractor.sampleColor(from: image, at: normalized, radius: 2)
                loupeColor = Color(
                    red: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255
                )
                onSample(rgb)
            }
            .onEnded { _ in
                isDragging = false
                touchPoint = nil
                onSampleEnd()
            }
    }
}

#Preview {
    let img = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { ctx in
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow]
        for (i, c) in colors.enumerated() {
            c.setFill()
            ctx.fill(CGRect(x: CGFloat(i) * 75, y: 0, width: 75, height: 200))
        }
    }
    return PhotoLoupeView(image: img, onSample: { _ in }, onSampleEnd: {})
        .frame(height: 200)
        .padding()
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Palettes/Views/Components/PhotoLoupeView.swift
git commit -m "feat: add PhotoLoupeView interactive photo eyedropper"
```

---

## Task 4: Wire `PhotoLoupeView` into `ColorInputView`

**Files:**
- Modify: `Palettes/Views/Components/ColorInputView.swift`

**Interfaces:**
- Consumes: `PhotoLoupeView(image:onSample:onSampleEnd:)` (Task 3). Reuses existing `ColorInputView` state (`baseR/baseG/baseB`, `temperatureValue/saturationValue/brightnessValue`, `hasExtractedColor`, `scanName`, `selectedImage`) and the existing `autoName(forRawHex:)` method.
- Produces: no new public interface.

**Behavior:** In `.dominant` mode with a `selectedImage`, `photoArea` renders `PhotoLoupeView` instead of the static `Image`. The `onSample` callback writes the sampled RGB into `baseR/G/B`, resets the three sliders to `0.5`, and sets `hasExtractedColor = true` — mirroring `extract(from:)`'s dominant branch so the sliders keep working on the sampled color. `onSampleEnd` recomputes `scanName` via `autoName`. In `.palette` mode (or when no image), the static image / placeholder is unchanged.

- [ ] **Step 1: Replace the image branch in `photoArea`**

In `Palettes/Views/Components/ColorInputView.swift`, in the `photoArea` computed property, replace this block:

```swift
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
```

with:

```swift
            if let image = selectedImage {
                if case .dominant = scanExtraction {
                    PhotoLoupeView(
                        image: image,
                        onSample: { rgb in
                            baseR = rgb.r
                            baseG = rgb.g
                            baseB = rgb.b
                            temperatureValue = 0.5
                            saturationValue = 0.5
                            brightnessValue = 0.5
                            hasExtractedColor = true
                        },
                        onSampleEnd: {
                            let hex = String(
                                format: "%02X%02X%02X",
                                Int(round(baseR)), Int(round(baseG)), Int(round(baseB))
                            )
                            scanName = autoName(forRawHex: hex)
                        }
                    )
                    .frame(height: 200)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            } else {
```

Leave the rest of `photoArea` (the `else` placeholder branch, the `.frame(height: 200)` / `.clipShape` / padding on the `ZStack`) unchanged.

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the full test suite (regression check)**

Run: `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,name=<SIM>"`
Expected: PASS — existing suites plus the two new test files.

- [ ] **Step 4: Manual verification in the simulator**

1. Launch the app, open the create-color / add-color sheet, select **Scan**.
2. Pick a multi-color photo from the library. Confirm the dominant color is auto-extracted (swatch + sliders populated) and the "Drag to pick a color" hint shows on the photo.
3. Press and drag on the photo. Confirm: the photo animates to fit (whole image visible), the loupe magnifier appears above the finger with a live swatch, and the color updates as you move.
4. Drag near the **top** edge — confirm the loupe flips below the finger.
5. Release over a distinct color region. Confirm the main swatch, `adjustedColor` preview, and the color name update to the sampled color.
6. Move the **Temperature / Saturation / Brightness** sliders — confirm they adjust *from* the newly sampled color (sliders start neutral after each sample).
7. Add the color and confirm it lands in the palette with the sampled value.

- [ ] **Step 5: Commit**

```bash
git add Palettes/Views/Components/ColorInputView.swift
git commit -m "feat: use PhotoLoupeView for point-picking in dominant scan flow"
```

---

## Task 5: Update the graphify knowledge graph

**Files:** none (regenerates `graphify-out/`).

- [ ] **Step 1: Regenerate the graph**

Run: `graphify update .`
Expected: completes without error (AST-only, no API cost).

- [ ] **Step 2: Commit if the graph changed**

```bash
git add graphify-out
git commit -m "chore: update graphify graph for photo loupe eyedropper" || echo "no graph changes"
```

---

## Self-Review

**1. Spec coverage:**
- Loupe eyedropper on `.dominant` scan flow → Tasks 3 + 4. ✓
- Auto-extract preserved as instant default → Task 4 leaves `extract(from:)` untouched; loupe overrides via shared state. ✓
- Fill→fit animation while dragging → Task 3 (`aspectRatio(contentMode: isDragging ? .fit : .fill)` + animation). ✓
- Small averaged region sampling → Task 1 (`radius` neighborhood average). ✓
- Sliders keep working on sampled color → Task 4 writes `baseR/G/B` + resets sliders; `adjustedRGB` recomputes from base. ✓
- Name recompute on drag-end only → Task 4 `onSampleEnd`; live `onSample` does not touch `scanName`. ✓
- Coordinate mapping + letterbox clamp → Task 2 with tests. ✓
- Loupe flips near top edge → Task 3 (`above` logic). ✓
- Works for camera + library photos → both populate `selectedImage`; Task 4 keys off `selectedImage`, source-agnostic. ✓
- `.palette` mode unchanged → Task 4 `else` branch keeps static image. ✓
- Testing (sampleColor, mapping, preview) → Tasks 1, 2, 3. ✓
- iOS 17 floor, no pbxproj edits → Global Constraints; only standard SwiftUI APIs used. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code and exact commands. ✓

**3. Type consistency:** `sampleColor(from:at:radius:)` returns `(r,g,b)` Doubles 0–255, consumed identically in Task 3's gesture and Task 4's callback. `normalizedPoint(forViewPoint:viewSize:imageSize:)` returns `CGPoint`, consumed in Task 3. `PhotoLoupeView(image:onSample:onSampleEnd:)` signature matches its use in Task 4. `autoName(forRawHex:)` and the scan-state property names match `ColorInputView`. ✓
