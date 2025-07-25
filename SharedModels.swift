//
//  SharedModels.swift
//  HelloSwiftU
//
//  Created by 今井悠翔 on 2025/07/09.
//

import Foundation
import SwiftUI

// MARK: - ShoppingItem
struct ShoppingItem: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var dueDate: Date?
    var note: String? = nil

    init(id: UUID = UUID(), name: String, dueDate: Date? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.dueDate = dueDate
        self.note = note
    }
}

// MARK: - DeletedItem
struct DeletedItem: Codable, Hashable {
    let name: String
    let category: String
    let dueDate: Date?
    let note: String?
}

// MARK: - HEXカラー対応の拡張
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
