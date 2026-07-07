//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 15.2.26.
//

import SwiftUI

struct PaletteEmptyView: View {
    
    let imageName: String
    let message: String
    
    @State private var animateIcon = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 28) {
                Image(systemName: imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.indigo)
                    .symbolEffect(.bounce.byLayer, value: animateIcon)
                    .background {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.indigo.opacity(0.35), .purple.opacity(0.15), .clear],
                                    center: .center, startRadius: 0, endRadius: 160
                                )
                            )
                            .frame(width: 320, height: 320)
                            .blur(radius: 20)
                    }

                Text(message)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                    .padding(.horizontal, 32)
            }
            .offset(y: -50)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateIcon = true
            }
        }
    }
}

#Preview {
    PaletteEmptyView(imageName: "swatchpalette.fill", message: "You currently have no palettes. Create one!")
}
