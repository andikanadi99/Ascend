//
//  WeeklySchedule.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/26/25.
//

import Foundation
import FirebaseFirestore

struct WeeklySchedule: Identifiable, Codable {
    @DocumentID var id: String? = nil
    
    var userId: String          // The user who owns this schedule
    var startOfWeek: Date       // We can store it as a Date
    var weeklyPriorities: [WeeklyPriority]
    // dailyIntentions maps "Sun", "Mon", etc. to a string
    var dailyIntentions: [String: String]
    // dailyToDoLists maps "Sun", "Mon", etc. to an array of ToDoItem
    var dailyToDoLists: [String: [ToDoItem]]
}

// Keep WeeklyPriority and ToDoItem as you have them,
// but ensure they're Codable as well:

struct WeeklyPriority: Identifiable, Codable {
    var id: UUID
    var title: String
    var progress: Double
}

// If needed, add 'Codable' for your ToDoItem
struct ToDoItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var isCompleted: Bool
}
