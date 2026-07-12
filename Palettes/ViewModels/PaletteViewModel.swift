//
//  File.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import Foundation
import SwiftUI

struct PaletteViewModel: Identifiable, Sendable, Hashable {
    var id = UUID()
    var name: String
    var colors: [Color]
    var hexCodes: [String] = []
    var colorNames: [String] = []

    static func == (lhs: PaletteViewModel, rhs: PaletteViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
