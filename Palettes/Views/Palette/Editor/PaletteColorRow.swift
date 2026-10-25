//
//  PaletteColorRow.swift
//  Palettes
//
//  The editor's colors as a horizontal row of small tiles, under the name:
//  tap a tile to edit it, tap its "−" badge to take it out, hold and drag to
//  reorder. While a tile is dragged its neighbors slide aside, so the gap
//  always shows where it will land; the draft only changes on release. The host (PaletteEditor) owns the
//  draft and what a tap opens.
//

import SwiftUI

struct PaletteColorRow: View {
    @Binding var draft: PaletteDraft
    /// The tile last tapped; the add panel's Harmony source builds on it.
    @Binding var selection: UUID?
    /// Tiles that are entering as a first fill, each with its place in the
    /// stagger (empty otherwise).
    var entrance: [UUID: Int] = [:]
    var onEdit: (UUID) -> Void
    var onTag: (UUID) -> Void
    /// For the Undo toast.
    var onRemove: (_ index: Int, _ color: PaletteColor) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The tile being held and how far it has been dragged. Resets by itself
    /// when the gesture ends or is cancelled, with the settle animation, so
    /// a tile can never be left lifted.
    @GestureState(resetTransaction: Transaction(animation: Self.settleSpring))
    private var lifted: Lift?

    private struct Lift: Equatable {
        var id: UUID
        /// The finger's travel since the lift.
        var translation: CGFloat = 0
        /// The finger, in global coordinates, for the edge auto-scroll.
        var fingerX: CGFloat
        /// `contentMinX` at the lift, so scrolling while holding counts as travel.
        var startContentX: CGFloat
    }

    /// The tiles' leading edge, in global coordinates (like `viewport`); it
    /// goes down as the row scrolls toward its end.
    @State private var contentMinX: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    /// The scroll view, in global coordinates.
    @State private var viewport: CGRect = .zero
    /// The latest lift, kept past the gesture's reset for its release.
    @State private var lastLift: Lift?

    private static let fadeLength: CGFloat = 36
    /// How close to an edge a held tile's finger starts the row scrolling.
    private static let autoScrollZone: CGFloat = 44
    /// One tile's worth of auto-scroll, and how often it repeats.
    private static let autoScrollStep: Duration = .milliseconds(260)

    static let tileSize: CGFloat = 52
    private static let spacing: CGFloat = 12
    private static let tileRadius: CGFloat = 12
    private static let badgeSize: CGFloat = 22
    /// Room above and to the right of the tiles for the badges hanging off
    /// their corners.
    private static let badgeInset: CGFloat = 10
    static var height: CGFloat { tileSize + badgeInset * 2 }
    /// From one tile's slot to the next.
    static var step: CGFloat { tileSize + spacing }

    private static let endID = "rowEnd"

    private static let settleSpring = Animation.spring(duration: 0.35, bounce: 0.15)

    /// Where a tile picked up at `start` would land after moving
    /// `translation` points: the nearest slot, kept inside the row.
    static func targetIndex(from start: Int, translation: CGFloat, step: CGFloat, count: Int) -> Int {
        guard count > 0, step > 0 else { return start }
        let slots = Int((translation / step).rounded())
        return min(max(start + slots, 0), count - 1)
    }

    /// How many slots (-1, 0 or 1) the tile at `index` shifts to make room
    /// while the tile from `start` hovers over `target`.
    static func shift(forIndex index: Int, start: Int, target: Int) -> Int {
        if start < target, index > start, index <= target { return -1 }
        if target < start, index >= target, index < start { return 1 }
        return 0
    }

    /// Neighbors sliding out of the way. Reduce Motion: they jump (nil).
    private var makeRoom: Animation? {
        reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.2)
    }

    /// Removals and duplicates closing or opening a gap.
    private var reshuffle: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    private var liftStart: Int? {
        lifted.flatMap { lift in draft.colors.firstIndex { $0.id == lift.id } }
    }

    /// How far the held tile has travelled along the row: the finger's
    /// drag plus however far the row has auto-scrolled under it.
    private var liftTravel: CGFloat {
        guard let lifted else { return 0 }
        return lifted.translation + (lifted.startContentX - contentMinX)
    }

    private var liftTarget: Int? {
        guard lifted != nil, let start = liftStart else { return nil }
        return Self.targetIndex(from: start, translation: liftTravel, step: Self.step, count: draft.colors.count)
    }

    /// How strongly each edge fades (0...1): it grows with how far the row
    /// runs past that edge, reaching full strength one fade length in, so
    /// the fade eases in with the scroll instead of popping on.
    private var leadingFade: CGFloat {
        min(max((viewport.minX - contentMinX) / Self.fadeLength, 0), 1)
    }

    private var trailingFade: CGFloat {
        min(max((tilesMaxX - viewport.maxX) / Self.fadeLength, 0), 1)
    }

    private var isCutOffLeading: Bool { contentMinX < viewport.minX - 1 }
    private var isCutOffTrailing: Bool { tilesMaxX > viewport.maxX + 1 }

    /// The last tile's trailing edge (the content also holds the badges' room).
    private var tilesMaxX: CGFloat { contentMinX + contentWidth - Self.badgeInset }

    /// -1 / 1 while a held tile's finger sits in the leading / trailing
    /// zone and there is more row that way; 0 otherwise.
    private var autoScrollDirection: Int {
        guard let lifted, viewport.width > 0 else { return 0 }
        if lifted.fingerX < viewport.minX + Self.autoScrollZone, isCutOffLeading { return -1 }
        if lifted.fingerX > viewport.maxX - Self.autoScrollZone, isCutOffTrailing { return 1 }
        return 0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    HStack(spacing: Self.spacing) {
                        ForEach(draft.colors) { entry in
                            tile(entry).id(entry.id)
                        }
                    }
                    // Room for the last badge; scrolling here shows it whole.
                    Color.clear.frame(width: Self.badgeInset).id(Self.endID)
                }
                .padding(.vertical, Self.badgeInset)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { frame in
                    contentMinX = frame.minX
                    contentWidth = frame.width
                }
            }
            .scrollIndicators(.hidden)
            // The lifted tile's shadow and scale reach past the row.
            .scrollClipDisabled()
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { viewport = $0 }
            .mask { edgeFade }
            // A held tile's drag mustn't also scroll the row.
            .scrollDisabled(lifted != nil)
            .onChange(of: draft.colors.count) { old, new in
                // Bring a newly added color into view.
                guard new > old else { return }
                withAnimation(reshuffle) { proxy.scrollTo(Self.endID, anchor: .trailing) }
            }
            .task(id: autoScrollDirection) {
                let direction = autoScrollDirection
                guard direction != 0 else { return }
                while !Task.isCancelled {
                    autoScroll(direction, proxy: proxy)
                    try? await Task.sleep(for: Self.autoScrollStep)
                }
            }
        }
        .frame(height: Self.height)
        .onChange(of: lifted) { _, new in if let new { lastLift = new } }
        .sensoryFeedback(.impact(weight: .medium), trigger: lifted?.id) { _, new in new != nil }
        .sensoryFeedback(.selection, trigger: liftTarget) { old, new in old != nil && new != nil }
    }

    /// Fades the tiles out at the row's own edges (it is as wide as the name
    /// field) while more of the row is cut off there, so the cutoff isn't a
    /// hard line. Taller than the row so a lifted
    /// tile's shadow isn't clipped.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            Self.fade(strength: leadingFade, startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.fadeLength)
            Rectangle()
            Self.fade(strength: trailingFade, startPoint: .trailing, endPoint: .leading)
                .frame(width: Self.fadeLength)
        }
        .padding(.vertical, -24)
    }

    /// Clear-ish at the edge (`1 - strength`) to opaque inward, along a
    /// smoothstep curve so there is no visible line where the fade starts.
    private static func fade(strength: CGFloat, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        let stops = stride(from: 0.0, through: 1.0, by: 0.125).map { t in
            let eased = t * t * (3 - 2 * t)
            return Gradient.Stop(color: .black.opacity(1 - strength * (1 - eased)), location: t)
        }
        return LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint)
    }

    /// Reveals the next tile that is cut off on `direction`'s side. The
    /// held tile stays under the finger: the scroll counts toward its travel.
    private func autoScroll(_ direction: Int, proxy: ScrollViewProxy) {
        let ids = draft.colors.map(\.id)
        let next: Int?
        if direction > 0 {
            let edge = viewport.maxX + 1
            next = ids.indices.first { contentMinX + CGFloat($0) * Self.step + Self.tileSize > edge }
        } else {
            let edge = viewport.minX - 1
            next = ids.indices.last { contentMinX + CGFloat($0) * Self.step < edge }
        }
        guard let next else { return }
        let isLast = direction > 0 && next == ids.count - 1
        withAnimation(.easeInOut(duration: 0.25)) {
            if isLast {
                proxy.scrollTo(Self.endID, anchor: .trailing)
            } else {
                proxy.scrollTo(ids[next], anchor: direction > 0 ? .trailing : .leading)
            }
        }
    }

    // MARK: Tile

    private func tile(_ entry: PaletteColor) -> some View {
        let id = entry.id
        let index = draft.colors.firstIndex { $0.id == id } ?? 0
        let isLast = index == draft.colors.count - 1
        let isLifted = lifted?.id == id
        let shape = RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)

        return shape
            .fill(entry.color)
            .frame(width: Self.tileSize, height: Self.tileSize)
            .overlay(shape.strokeBorder(.primary.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .topTrailing) { removeBadge(id) }
            .scaleEffect(isLifted && !reduceMotion ? 1.1 : 1)
            .shadow(color: .black.opacity(isLifted ? 0.25 : 0), radius: 8, y: 4)
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isLifted)
            .offset(x: offset(forIndex: index, isLifted: isLifted))
            // The held tile follows the finger; the rest glide.
            .animation(isLifted ? nil : makeRoom, value: liftTarget)
            .zIndex(isLifted ? 1 : 0)
            .contentShape(shape)
            .onTapGesture {
                selection = id
                onEdit(id)
            }
            .gesture(reorderGesture(for: id))
            .firstFillEntrance(index: entrance[id])
            .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.name), \(entry.hex)")
            .accessibilityValue(entry.role ?? "")
            .accessibilityHint("Double-tap to edit")
            .accessibilityAddTraits(selection == id ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selection = id; onEdit(id) }
            .accessibilityActions {
                if index > 0 {
                    Button("Move Left") { withAnimation(reshuffle) { draft.move(id: id, to: index - 1) } }
                }
                if !isLast {
                    Button("Move Right") { withAnimation(reshuffle) { draft.move(id: id, to: index + 1) } }
                }
                if !draft.isFull {
                    Button("Duplicate") { withAnimation(reshuffle) { draft.duplicate(id: id) } }
                }
                Button("Tag") { onTag(id) }
                Button("Remove") { remove(id) }
            }
    }

    private func offset(forIndex index: Int, isLifted: Bool) -> CGFloat {
        if isLifted { return liftTravel }
        guard let start = liftStart, let target = liftTarget else { return 0 }
        return CGFloat(Self.shift(forIndex: index, start: start, target: target)) * Self.step
    }

    /// Hold, then drag sideways. Letting go moves the color to the slot the
    /// gap is at; the tile and its neighbors settle together, so nothing jumps.
    private func reorderGesture(for id: UUID) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            // Global, so the auto-scroll moving the tile can't feed back into
            // the drag's own measurements.
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($lifted) { value, state, _ in
                guard case .second(true, let drag) = value else { return }
                guard let drag else {
                    if state == nil { state = Lift(id: id, fingerX: viewport.midX, startContentX: contentMinX) }
                    return
                }
                var lift = state ?? Lift(id: id, fingerX: drag.location.x, startContentX: contentMinX)
                lift.translation = drag.translation.width
                lift.fingerX = drag.location.x
                state = lift
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let start = draft.colors.firstIndex(where: { $0.id == id }) else { return }
                let scrolled = lastLift.map { $0.startContentX - contentMinX } ?? 0
                let to = Self.targetIndex(from: start, translation: drag.translation.width + scrolled, step: Self.step, count: draft.colors.count)
                guard to != start else { return }
                withAnimation(reduceMotion ? nil : Self.settleSpring) { draft.move(id: id, to: to) }
            }
    }

    /// The home-screen style "−" hanging off the tile's top-right corner.
    private func removeBadge(_ id: UUID) -> some View {
        Button { remove(id) } label: {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: Self.badgeSize, height: Self.badgeSize)
                .background(Color(.systemGray), in: Circle())
                .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 1.5))
                // A bigger target than it looks.
                .padding(6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: Self.badgeSize / 2 - 2 + 6, y: -(Self.badgeSize / 2 - 2 + 6))
        .opacity(lifted == nil ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: lifted == nil)
        .accessibilityHidden(true)
    }

    private func remove(_ id: UUID) {
        var removed: (index: Int, color: PaletteColor)?
        withAnimation(reshuffle) { removed = draft.remove(id: id) }
        guard let removed else { return }
        if selection == id { selection = nil }
        onRemove(removed.index, removed.color)
    }
}

#Preview {
    @Previewable @State var draft = PaletteDraft(name: "Dusk", colors: [
        PaletteColor(color: Color(hex: "#264653") ?? .gray, hex: "#264653", name: "Charcoal Blue", role: "Primary"),
        PaletteColor(color: Color(hex: "#2A9D8F") ?? .gray, hex: "#2A9D8F", name: "Persian Green"),
        PaletteColor(color: Color(hex: "#E9C46A") ?? .gray, hex: "#E9C46A", name: "Saffron", role: "Accent"),
        PaletteColor(color: Color(hex: "#F4A261") ?? .gray, hex: "#F4A261", name: "Sandy Brown"),
        PaletteColor(color: Color(hex: "#E76F51") ?? .gray, hex: "#E76F51", name: "Burnt Sienna"),
    ])
    @Previewable @State var selection: UUID?

    PaletteColorRow(
        draft: $draft,
        selection: $selection,
        onEdit: { _ in },
        onTag: { _ in },
        onRemove: { _, _ in }
    )
    .padding()
}
