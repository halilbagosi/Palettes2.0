//
//  PaletteCellSearch.swift
//  Palettes
//
//  Created by Halil Bagosi on 24.2.26.
//

import SwiftUI

struct PaletteCellSearch: View {
    let paletteName: String
    let colors: [Color]
    
    var body: some View {
        VStack(spacing: 0) {
            if !colors.isEmpty {
                HStack(spacing: 0) {
                    ForEach(0..<colors.count, id: \.self) { (index: Int) in
                        Rectangle()
                            .fill(colors[index])
                    }
                }
                .frame(height: 48)
            }
            
            Divider()
            
            HStack {
                Text(paletteName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(colors.count) color\(colors.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    VStack(spacing: 12) {
        PaletteCellSearch(paletteName: "Midnight Ocean", colors: [.blue, .indigo, .black, .cyan, .teal, .blue, .purple, .black])
        PaletteCellSearch(paletteName: "Sunset Glow", colors: [.red, .orange, .yellow, .pink, .orange, .red, .yellow, .pink])
        PaletteCellSearch(paletteName: "Forest Floor", colors: [.green, .brown, .mint, .cyan, .green, .brown, .mint, .gray])
    }
    .padding()
}
