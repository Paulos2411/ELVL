//
//  Item.swift
//  ELVL
//
//  Created by Paul Ortulidis-Pflanz on 03.02.2026.
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
