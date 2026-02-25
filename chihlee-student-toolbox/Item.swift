//
//  Item.swift
//  chihlee-student-toolbox
//
//  Created by CH ouo on 2026/2/25.
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
