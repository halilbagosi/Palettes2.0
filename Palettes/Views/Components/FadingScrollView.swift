//
//  FadingScrollView.swift
//  Palettes
//
//  A vertical scroll view whose content fades out at an edge while more of it
//  is cut off there. It measures its content and its visible height itself, so
//  a list that starts cut off fades from the first frame, on every iOS the app
//  supports.
//

import SwiftUI

struct FadingScrollView<Content: View>: View {
    var fadeLength: CGFloat = 18
    @ViewBuilder var content: Content

    private struct Edges: Equatable {
        var top = false
        var bottom = false
    }

    /// How far past the sides content may draw (glass edges, shadows).
    private static var sideOutset: CGFloat { 12 }

    @State private var contentFrame: CGRect = .zero
    @State private var visibleHeight: CGFloat = 0

    private var edges: Edges {
        Edges(
            top: contentFrame.minY < -1,
            bottom: contentFrame.maxY > visibleHeight + 1
        )
    }

    var body: some View {
        ScrollView {
            content
                // Where the content sits in the visible area: minY goes
                // negative as it scrolls up.
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .scrollView) }) { contentFrame = $0 }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { visibleHeight = $0 }
        // The fade mask does the vertical clipping; sideways, content's glass
        // edges and shadows may draw a little past the scroll view's frame.
        .scrollClipDisabled()
        .mask { mask(edges).padding(.horizontal, -Self.sideOutset) }
        .animation(.easeOut(duration: 0.2), value: edges)
    }

    private func mask(_ edges: Edges) -> some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(edges.top ? 0 : 1), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: fadeLength)
            Rectangle()
            LinearGradient(colors: [.black, .black.opacity(edges.bottom ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                .frame(height: fadeLength)
        }
    }
}
