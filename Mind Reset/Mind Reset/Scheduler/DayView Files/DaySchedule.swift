//  DaySchedule.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/25/25.
//

import Foundation
import FirebaseFirestore

/// Represents the full daily schedule for a user, including wake/sleep times, priorities, and time blocks.
struct DaySchedule: Identifiable, Codable {
    @DocumentID var id: String?        // Firestore document ID
    var userId: String                  // Tie to a specific user
    var date: Date                      // The date this schedule is for
    var wakeUpTime: Date                // e.g., 7:00 AM
    var sleepTime: Date                 // e.g., 10:00 PM
    var priorities: [TodayPriority]     // List of top priorities
    var timeBlocks: [TimeBlock]         // Hourly time blocks
}

/// A single "Top Priority" entry for the day, with a completion flag.
struct TodayPriority: Identifiable, Codable, Equatable {
    var id: UUID                        // Unique identifier for this priority
    var title: String                   // Description of the priority
    var progress: Double                // Optional progress (0.0–1.0)
    var isCompleted: Bool               // Whether the priority is done for the day

    init(
        id: UUID = UUID(),
        title: String,
        progress: Double = 0.0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.progress = progress
        self.isCompleted = isCompleted
    }
}

/// An hourly time block in the day schedule, for tasks.
struct TimeBlock: Identifiable, Codable {
    var id: UUID                       // Unique identifier for this time block
    var time: String                   // e.g., "7:00 AM"
    var task: String                   // Task description
}
