//
//  MotionStage.swift
//  Palettes
//
//  DEBUG-only stage for the marketing film. Launch with `-motionStage YES`
//  (with sunset.jpg copied into the app's Documents folder via
//  `xcrun simctl get_app_container <sim> <bundle> data`) to replace the app with a scripted, self-playing sequence built from real
//  Liquid Glass: `glassEffect` shapes inside `GlassEffectContainer`s, so drops
//  merge and split with the system's own liquid morphing, driven by SwiftUI
//  springs. Record it with `xcrun simctl io <sim> recordVideo`; the script
//  starts `MotionStage.leadIn` seconds after launch so the recording can
//  begin first. See marketing/motion/BRIEF.md.
//

#if DEBUG
import SwiftUI

enum MotionStage {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "motionStage") }
    /// Seconds of still frame before the script starts.
    static let leadIn: Double = 6.0

    static func image(_ name: String) -> UIImage? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return UIImage(contentsOfFile: docs.appendingPathComponent(name).path)
    }
}

@available(iOS 26.0, *)
struct MotionStageView: View {
    // Scene state. Every change happens inside `withAnimation(spring)`, so the
    // glass morphs between states with real physics.
    @State private var dropY: CGFloat = 0
    @State private var dropSize: CGFloat = 0
    @State private var showDrop = false
    @State private var photo = 0.0
    @State private var droplets: [Droplet] = []
    @State private var cards: [CardState] = []
    @State private var wheel: [Bead] = []
    @State private var spin = Angle.zero
    @State private var icon: [Bead] = []
    @State private var showIcon = false
    @State private var meshPhase = 0.0
    @Namespace private var ns

    private static let sunset: [Color] = [.init(hex: "#FF2D3A"), .init(hex: "#FF6A1A"), .init(hex: "#FFB020"),
                                          .init(hex: "#FF4F8B"), .init(hex: "#B13CFF"), .init(hex: "#2E6BFF")].map { $0 ?? .red }
    private static let library: [[String]] = [
        ["#FF2E88", "#00E5FF", "#7A00FF", "#FFE600", "#B6FF00"],
        ["#FF5CE1", "#1FFFA8", "#FFEE33", "#3DB8FF", "#A033FF"],
        ["#0096FF", "#00F5D4", "#2E5BFF", "#2BF5A0", "#22D3FF"],
    ]

    struct Droplet: Identifiable {
        let id: Int
        var color: Color
        var x: CGFloat
        var y: CGFloat
        var w: CGFloat
        var h: CGFloat
        var r: CGFloat
    }

    struct CardState: Identifiable {
        let id: Int
        var colors: [Color]
        var y: CGFloat
    }

    struct Bead: Identifiable {
        let id: Int
        var color: Color
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var r: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                background
                // Island + drop: one container, so the drop pulls out of the
                // island as a single liquid shape and snaps free.
                GlassEffectContainer(spacing: 34) {
                    ZStack {
                        Capsule()
                            .frame(width: 126, height: 37)
                            .glassEffect(.regular.tint(.black.opacity(0.85)), in: .capsule)
                            .position(x: c.x, y: 30)
                        if showDrop {
                            Circle()
                                .frame(width: dropSize, height: dropSize)
                                .glassEffect(.regular.tint(.black.opacity(0.85 * (1 - photo))), in: .circle)
                                .position(x: c.x, y: dropY)
                        }
                    }
                }
                // The orb's view: a sunset seen through the glass.
                if let image = MotionStage.image("sunset.jpg"), showDrop {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: dropSize * 0.92, height: dropSize * 0.92)
                        .clipShape(Circle())
                        .opacity(photo)
                        .position(x: c.x, y: dropY)
                        .allowsHitTesting(false)
                    Circle()
                        .frame(width: dropSize, height: dropSize)
                        .glassEffect(.clear, in: .circle)
                        .opacity(photo)
                        .position(x: c.x, y: dropY)
                }
                // Droplets: start fused as the orb, scatter, then fuse into a palette.
                GlassEffectContainer(spacing: 18) {
                    ZStack {
                        ForEach(droplets) { d in
                            RoundedRectangle(cornerRadius: d.r)
                                .fill(.clear)
                                .frame(width: d.w, height: d.h)
                                .glassEffect(.regular.tint(d.color), in: .rect(cornerRadius: d.r))
                                .position(x: c.x + d.x, y: c.y + d.y)
                        }
                    }
                }
                ForEach(cards) { card in
                    GlassEffectContainer(spacing: 4) {
                        HStack(spacing: 0) {
                            ForEach(Array(card.colors.enumerated()), id: \.offset) { _, color in
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: 330 / CGFloat(card.colors.count), height: 92)
                                    .glassEffect(.regular.tint(color), in: .rect(cornerRadius: 26))
                            }
                        }
                    }
                    .position(x: c.x, y: c.y + card.y)
                }
                // Hue wheel → rainbow grid (no merging: spacing 0).
                GlassEffectContainer(spacing: 0) {
                    ZStack {
                        ForEach(wheel) { b in
                            RoundedRectangle(cornerRadius: b.r)
                                .fill(.clear)
                                .frame(width: b.size, height: b.size)
                                .glassEffect(.regular.tint(b.color), in: .rect(cornerRadius: b.r))
                                .position(x: c.x + b.x, y: c.y + b.y)
                        }
                    }
                }
                .rotationEffect(spin)
                // The icon's three circles fuse into one liquid shape.
                GlassEffectContainer(spacing: 26) {
                    ZStack {
                        ForEach(icon) { b in
                            Circle()
                                .fill(.clear)
                                .frame(width: b.size, height: b.size)
                                .glassEffect(.regular.tint(b.color), in: .circle)
                                .position(x: c.x + b.x, y: c.y + b.y)
                        }
                    }
                }
                if showIcon {
                    Image("AppIconPreviewDark")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(.rect(cornerRadius: 27))
                        .position(x: c.x, y: c.y - 60)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                }
            }
            .task { await run(center: c) }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }

    // A slowly drifting mesh: something real for the glass to refract.
    private var background: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let s = Float(sin(t * 0.35)) * 0.12
            let k = Float(cos(t * 0.27)) * 0.12
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + s, 0], [1, 0],
                    [0, 0.5 + k], [0.5 - s, 0.5 + k], [1, 0.5 - k],
                    [0, 1], [0.5 + k, 1], [1, 1],
                ],
                colors: [
                    .init(hex: "#1A0B2E") ?? .black, .init(hex: "#2B0F4A") ?? .black, .init(hex: "#0A1F3D") ?? .black,
                    .init(hex: "#3A0D35") ?? .black, .init(hex: "#120A24") ?? .black, .init(hex: "#082E3A") ?? .black,
                    .init(hex: "#0B0B18") ?? .black, .init(hex: "#2A1206") ?? .black, .init(hex: "#0B1A2E") ?? .black,
                ]
            )
        }
        .ignoresSafeArea()
    }

    // MARK: Script

    private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    private func run(center c: CGPoint) async {
        await wait(MotionStage.leadIn)

        // 1. Pull: the drop stretches out of the island and snaps free.
        dropY = 30
        dropSize = 30
        showDrop = true
        await wait(0.1)
        withAnimation(.spring(duration: 1.7, bounce: 0.1)) {
            dropY = 150
            dropSize = 52
        }
        await wait(1.7)
        // 2. It falls and swells into the orb, then the sunset fades in.
        withAnimation(.spring(duration: 0.9, bounce: 0.32)) {
            dropY = c.y - 40
            dropSize = 300
        }
        await wait(0.5)
        withAnimation(.easeInOut(duration: 0.6)) { photo = 1 }
        await wait(1.6)

        // 3. Burst: six tinted drops appear fused as the orb, then scatter.
        droplets = Self.sunset.enumerated().map { i, color in
            Droplet(id: i, color: color, x: 0, y: -40, w: 280, h: 280, r: 140)
        }
        withAnimation(.easeOut(duration: 0.25)) { photo = 0 }
        showDrop = false
        withAnimation(.spring(duration: 0.75, bounce: 0.38)) {
            for i in droplets.indices {
                let a = Double(i) / 6 * 2 * .pi - .pi / 2
                droplets[i].x = cos(a) * 140
                droplets[i].y = -40 + sin(a) * 140
                droplets[i].w = 64
                droplets[i].h = 64
                droplets[i].r = 32
            }
        }
        await wait(0.9)
        // Line up as swatches...
        withAnimation(.spring(duration: 0.7, bounce: 0.25)) {
            for i in droplets.indices {
                droplets[i].x = (CGFloat(i) - 2.5) * 60
                droplets[i].y = 40
                droplets[i].w = 52
                droplets[i].h = 52
                droplets[i].r = 16
            }
        }
        await wait(0.8)
        // ...and fuse into one palette.
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
            for i in droplets.indices {
                droplets[i].x = (CGFloat(i) - 2.5) * 55
                droplets[i].w = 56
                droplets[i].h = 100
                droplets[i].r = 22
            }
        }
        await wait(0.9)
        // 4. The library: the palette rises and others stack in beneath it.
        withAnimation(.spring(duration: 0.8, bounce: 0.15)) {
            for i in droplets.indices { droplets[i].y = -190 }
        }
        cards = Self.library.enumerated().map { i, hexes in
            CardState(id: i, colors: hexes.map { Color(hex: $0) ?? .gray }, y: 700 + CGFloat(i) * 80)
        }
        for i in cards.indices {
            await wait(0.08)
            withAnimation(.spring(duration: 0.75, bounce: 0.22)) { cards[i].y = -80 + CGFloat(i) * 112 }
        }
        await wait(1.6)
        withAnimation(.spring(duration: 0.6)) {
            for i in droplets.indices { droplets[i].y -= 700 }
            for i in cards.indices { cards[i].y -= 700 }
        }
        await wait(0.5)
        droplets = []
        cards = []

        // 5. Hue wheel: beads burst from the centre onto a ring and turn.
        let n = 24
        wheel = (0..<n).map { i in
            Bead(id: i, color: Color(hue: Double(i) / Double(n), saturation: 0.9, brightness: 1), x: 0, y: 0, size: 8, r: 4)
        }
        withAnimation(.spring(duration: 0.9, bounce: 0.3)) {
            for i in wheel.indices {
                let a = Double(i) / Double(n) * 2 * .pi - .pi / 2
                wheel[i].x = cos(a) * 130
                wheel[i].y = sin(a) * 130
                wheel[i].size = 34
                wheel[i].r = 17
            }
        }
        withAnimation(.linear(duration: 2.2)) { spin = .degrees(120) }
        await wait(2.0)
        // Snap into a rainbow grid.
        withAnimation(.spring(duration: 0.8, bounce: 0.25)) {
            spin = .zero
            for i in wheel.indices {
                let col = i % 4
                let row = i / 4
                wheel[i].x = (CGFloat(col) - 1.5) * 64
                wheel[i].y = (CGFloat(row) - 2.5) * 64
                wheel[i].size = 56
                wheel[i].r = 16
            }
        }
        await wait(1.8)
        withAnimation(.spring(duration: 0.6)) {
            for i in wheel.indices { wheel[i].y -= 800 }
        }
        await wait(0.5)
        wheel = []

        // 6. End: the icon's circles fly in and fuse, then the icon itself.
        let iconColors = ["#EE5A70", "#F0A030", "#7B5BE0"].map { Color(hex: $0) ?? .pink }
        let starts: [CGPoint] = [.init(x: -320, y: -300), .init(x: 320, y: -200), .init(x: 0, y: 520)]
        icon = iconColors.enumerated().map { i, col in Bead(id: i, color: col, x: starts[i].x, y: starts[i].y, size: 70, r: 35) }
        withAnimation(.spring(duration: 0.9, bounce: 0.3)) {
            let rest: [Double] = [-90, 150, 30]
            for i in icon.indices {
                let a = rest[i] * .pi / 180
                icon[i].x = cos(a) * 22
                icon[i].y = -60 + sin(a) * 22
                icon[i].size = 64
            }
        }
        await wait(1.1)
        withAnimation(.spring(duration: 0.6, bounce: 0.25)) {
            showIcon = true
            for i in icon.indices { icon[i].size = 0 }
        }
    }
}
#endif
