// MonthSchedule.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 3/27/25.
//


// MonthSchedule.swift

import Foundation
import FirebaseFirestore

struct MonthSchedule: Identifiable, Codable {
    @DocumentID var id: String? = nil
    var userId: String
    var yearMonth: String
    var monthlyPriorities: [MonthlyPriority]
    var dayCompletions: [String: Double]
    var dailyPrioritiesByDay: [String: [TodayPriority]] = [:]
}

// -----------------------------------------------
//  ⬇︎ NEW: custom Codable implementation
// -----------------------------------------------
struct MonthlyPriority: Identifiable, Codable {
    var id:          UUID
    var title:       String
    var progress:    Double
    var isCompleted: Bool                    // ← NEW in 2025-05

    // default memberwise init keeps previews happy
    init(id: UUID,
         title: String,
         progress: Double,
         isCompleted: Bool = false)
    {
        self.id          = id
        self.title       = title
        self.progress    = progress
        self.isCompleted = isCompleted
    }

    enum CodingKeys: String, CodingKey {
        case id, title, progress, isCompleted
    }

    // tolerate missing `isCompleted` when reading older months
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        progress    = try c.decode(Double.self, forKey: .progress)
        isCompleted = try c.decodeIfPresent(Bool.self,
                                            forKey: .isCompleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        try c.encode(title,       forKey: .title)
        try c.encode(progress,    forKey: .progress)
        try c.encode(isCompleted, forKey: .isCompleted)
    }
}




