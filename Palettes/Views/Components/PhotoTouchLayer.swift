//
//  PhotoTouchLayer.swift
//  Palettes
//
//  The touch surface of the full-screen photo color picker. One finger drags
//  the sample point; two fingers pinch to zoom and pan the photo. It reads
//  raw touches because SwiftUI's magnify gesture never reports where the
//  fingers are now, which a pinch that also pans needs.
//

import SwiftUI
import UIKit

struct PhotoTouchLayer: UIViewRepresentable {
    /// One finger is down or moving: its location, and its speed in points per second.
    var onSample: (_ location: CGPoint, _ velocity: CGSize) -> Void
    var onSampleEnded: () -> Void
    /// A second finger landed. `wasTap` is true when the first had barely
    /// moved, i.e. it was the start of the pinch and not a deliberate sample.
    var onPinchBegan: (_ wasTap: Bool) -> Void
    /// The fingers' midpoint moved from `previous` to `current` while spreading by `factor`.
    var onPinch: (_ factor: CGFloat, _ previous: CGPoint, _ current: CGPoint) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.handlers = self
        return view
    }

    func updateUIView(_ uiView: TouchView, context: Context) {
        uiView.handlers = self
    }

    final class TouchView: UIView {
        deinit {}

        var handlers: PhotoTouchLayer?

        private enum Mode { case idle, sampling, pinching, waitingForLift }
        private var mode = Mode.idle
        private var active: [UITouch] = []
        private var sampleStart: CGPoint = .zero
        private var sampleTravel: CGFloat = 0
        private var lastSample: (point: CGPoint, time: TimeInterval)?
        private var lastPinch: (midpoint: CGPoint, spread: CGFloat)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            active.append(contentsOf: touches)
            if mode == .idle, active.count == 1, let touch = active.first {
                mode = .sampling
                let point = touch.location(in: self)
                sampleStart = point
                sampleTravel = 0
                lastSample = (point, touch.timestamp)
                handlers?.onSample(point, .zero)
            } else if active.count >= 2, mode != .pinching {
                if mode == .sampling { handlers?.onSampleEnded() }
                handlers?.onPinchBegan(mode == .sampling && sampleTravel < 12)
                mode = .pinching
                lastPinch = measurePinch()
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            switch mode {
            case .sampling:
                guard let touch = active.first else { return }
                let point = touch.location(in: self)
                sampleTravel = max(sampleTravel, hypot(point.x - sampleStart.x, point.y - sampleStart.y))
                var velocity = CGSize.zero
                if let last = lastSample, touch.timestamp > last.time {
                    let dt = touch.timestamp - last.time
                    velocity = CGSize(width: (point.x - last.point.x) / dt, height: (point.y - last.point.y) / dt)
                }
                lastSample = (point, touch.timestamp)
                handlers?.onSample(point, velocity)
            case .pinching:
                guard let now = measurePinch(), let last = lastPinch else { return }
                if last.spread > 1, now.spread > 1 {
                    handlers?.onPinch(now.spread / last.spread, last.midpoint, now.midpoint)
                }
                lastPinch = now
            case .idle, .waitingForLift:
                break
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            lift(touches)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            lift(touches)
        }

        private func lift(_ touches: Set<UITouch>) {
            active.removeAll(where: touches.contains)
            switch mode {
            case .sampling where active.isEmpty:
                mode = .idle
                handlers?.onSampleEnded()
            case .pinching where active.count < 2:
                // The finger left behind doesn't start sampling: it would
                // jump the sample point to wherever the pinch ended.
                mode = active.isEmpty ? .idle : .waitingForLift
                lastPinch = nil
            case .pinching:
                lastPinch = measurePinch()   // a third finger left; re-base on the first two
            case .waitingForLift where active.isEmpty:
                mode = .idle
            default:
                break
            }
        }

        private func measurePinch() -> (midpoint: CGPoint, spread: CGFloat)? {
            guard active.count >= 2 else { return nil }
            let a = active[0].location(in: self), b = active[1].location(in: self)
            return (CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), hypot(a.x - b.x, a.y - b.y))
        }
    }
}
