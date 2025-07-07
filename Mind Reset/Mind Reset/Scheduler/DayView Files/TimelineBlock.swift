//
//  RGBAColor.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 6/30/25.
//


import SwiftUI

/// Serializable RGBA wrapper for SwiftUI.Color
struct RGBAColor: Hashable, Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }

    /// Convert back to SwiftUI.Color
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

/// A single block on the timeline, representing an event or task.
struct TimelineBlock: Identifiable, Hashable, Codable {
    let id: UUID
    var start: Date
    var end: Date
    var title: String?
    var description: String?
    var color: RGBAColor          // non-optional, serializable
    var isAllDay: Bool = false

    /// Duration of the block in seconds
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    /// Validity check: start must precede end
    var isValid: Bool {
        start < end
    }

    /// Convenience initializer using a SwiftUI.Color directly
    init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        title: String? = nil,
        description: String? = nil,
        color: Color = .accentColor,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
        self.description = description
        self.color = RGBAColor(color: color)
        self.isAllDay = isAllDay
    }
}
