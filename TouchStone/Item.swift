//
//  Item.swift
//  TouchStone
//
//  Created by KaiMac on 11/1/2026.
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
