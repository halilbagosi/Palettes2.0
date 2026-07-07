//
//  ColorCellSearch.swift
//  Palettes
//
//  Created by Halil Bagosi on 24.2.26.
//

import SwiftUI

struct ColorCellSearch: View {
    let colorName: String
    let hexCode: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(color.gradient)
                .frame(height: 80)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(colorName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                Text(hexCode)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .glassEffect(.regular, in: .rect(cornerRadius: 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        ColorCellSearch(colorName: "Maroon", hexCode: "#800000", color: Color(red: 128/255.0, green: 0, blue: 0))
        ColorCellSearch(colorName: "Electric Blue", hexCode: "#007AFF", color: Color(red: 0.00, green: 0.48, blue: 1.00))
        ColorCellSearch(colorName: "Neon Lime", hexCode: "#CCFF00", color: Color(red: 0.8, green: 1.0, blue: 0.0))
    }
    .padding()
}
