//
//  Item.swift
//  ios-word-game
//
//  Created by Juan Vallejo on 3/1/26.
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
