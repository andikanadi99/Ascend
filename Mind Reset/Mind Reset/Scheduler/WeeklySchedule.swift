//
//  WeeklySchedule.swift
//  Mind Reset
//
//

import Foundation
import FirebaseFirestore

// MARK: - WeeklySchedule
struct WeeklySchedule: Identifiable, Codable, Equatable {
    @DocumentID var id: String? = nil

    var userId: String            // Owner of this schedule
    var startOfWeek: Date         // First day (Sunday) of the ISO‑week
    var weeklyPriorities: [WeeklyPriority]

    /// Maps "Sun", "Mon", … to an intention string
    var dailyIntentions: [String: String]

    /// Maps "Sun", "Mon", … to a list of tasks
    var dailyToDoLists: [String: [ToDoItem]]
}

// MARK: - WeeklyPriority
struct WeeklyPriority: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var progress: Double          // 0.0 – 1.0
}

// MARK: - ToDoItem
struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
}
