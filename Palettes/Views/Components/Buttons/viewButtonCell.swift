//
//  File.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import Foundation
import SwiftUI

struct viewButtonCell: View {
    let title: LocalizedStringKey
    var tintColor: Color = .accentColor
    
    private var textColor: Color {
        tintColor.isLight ? .black : .white
    }
    
    var body: some View {
        Text(title)
            .padding()
            .font(.callout)
            .fontWeight(.semibold)
            .glassEffect(.regular.tint(tintColor).interactive())
            .foregroundColor(textColor)
    }
}

#Preview {
    viewButtonCell(title: "View Palette", tintColor: .blue)
}


