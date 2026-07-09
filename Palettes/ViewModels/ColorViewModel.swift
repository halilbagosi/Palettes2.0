//
//  File.swift
//  Palettes
//
//  Created by Halil Bagosi on 18.2.26.
//
import Foundation
import SwiftUI

struct ColorViewModel: Identifiable, Sendable, Hashable {
    let id = UUID()
    var name: String
    var color: Color
    var HEX: String
    var usedInPalette: Bool

    static func == (lhs: ColorViewModel, rhs: ColorViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
