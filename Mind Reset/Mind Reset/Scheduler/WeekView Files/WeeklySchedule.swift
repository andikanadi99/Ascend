// WeeklySchedule.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 3/26/25.

import Foundation
import FirebaseFirestore

// MARK: - WeeklySchedule
struct WeeklySchedule: Identifiable, Codable, Equatable {
    @DocumentID var id: String? = nil

    var userId: String
    var startOfWeek: Date
    var weeklyPriorities: [WeeklyPriority]
    var dailyIntentions: [String: String]
    var dailyToDoLists: [String: [ToDoItem]]
}

// MARK: - WeeklyPriority
struct WeeklyPriority: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var progress: Double
    var isCompleted: Bool

    init(id: UUID, title: String, progress: Double, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.progress = progress
        self.isCompleted = isCompleted
    }

    enum CodingKeys: String, CodingKey {
        case id, title, progress, isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id          = try container.decode(UUID.self, forKey: .id)
        title       = try container.decode(String.self, forKey: .title)
        progress    = try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id,          forKey: .id)
        try container.encode(title,       forKey: .title)
        try container.encode(progress,    forKey: .progress)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}

// MARK: - ToDoItem
struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
}
