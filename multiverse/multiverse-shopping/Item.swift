//
//  Item.swift
//  multiverse-shopping
//
//  Created by biubiu on 5/19/25.
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
