//
//  Item.swift
//  VoiceAccount
//
//  Created by 苏先森 on 2026/5/30.
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
