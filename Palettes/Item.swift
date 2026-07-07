//
//  Item.swift
//  Palettes
//
//  Created by Halil Bagosi on 7.7.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
