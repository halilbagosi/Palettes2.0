//
//  FirstFillStagger.swift
//  Palettes
//
//  When an empty palette receives several colors in one add (Scan, Library,
//  Harmony), its bands and rows enter one after another instead of all at
//  once. Purely decorative: the draft already holds every color, nothing
//  waits on the animation, and taps work while it plays.
//

import SwiftUI

enum FirstFillStagger {
    /// Delay between one item's entrance and the next's.
    static let step: Double = 0.04
    /// One item's own entrance.
    static let duration: Double = 0.35
    /// How far (pt) an item rises into place.
    static let rise: CGFloat = 8

    /// Entrance order for colors just added: each new id's index, or empty
    /// when this add shouldn't stagger (the palette already had colors, or
    /// fewer than two came in).
    static func plan(existingCount: Int, added: [UUID]) -> [UUID: Int] {
        guard existingCount == 0, added.count >= 2 else { return [:] }
        return Dictionary(uniqueKeysWithValues: added.enumerated().map { ($1, $0) })
    }

    /// When item `index` starts, relative to the add.
    static func delay(forIndex index: Int) -> Double {
        Double(index) * step
    }

    /// How long the whole entrance takes for `count` items; the plan can be
    /// dropped after this.
    static func totalDuration(count: Int) -> Double {
        delay(forIndex: max(count - 1, 0)) + duration
    }
}

private struct FirstFillEntrance: ViewModifier {
    /// Position in the stagger; nil when this item isn't part of one.
    let index: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered: Bool

    init(index: Int?) {
        self.index = index
        _entered = State(initialValue: index == nil)
    }

    func body(content: Content) -> some View {
        content
            .opacity(entered ? 1 : 0)
            // Reduce Motion: a fade only, no rise.
            .offset(y: entered || reduceMotion ? 0 : FirstFillStagger.rise)
            .onAppear {
                guard let index, !entered else { return }
                if reduceMotion {
                    // No stagger either: everything fades in together.
                    withAnimation(.easeInOut(duration: 0.2)) { entered = true }
                } else {
                    withAnimation(.spring(duration: FirstFillStagger.duration, bounce: 0)
                        .delay(FirstFillStagger.delay(forIndex: index))) { entered = true }
                }
            }
    }
}

extension View {
    /// Fades (and rises) this item in as part of a first-fill stagger; does
    /// nothing when `index` is nil.
    func firstFillEntrance(index: Int?) -> some View {
        modifier(FirstFillEntrance(index: index))
    }
}
