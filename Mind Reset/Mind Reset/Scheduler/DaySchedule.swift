//
//  DaySchedule.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/25/25.
//

import Foundation
import FirebaseFirestore

struct DaySchedule: Identifiable, Codable {
    @DocumentID var id: String?  // Firestore document ID
    
    var userId: String           // Tie to a specific user
    var date: Date               // The date this schedule is for
    var wakeUpTime: Date         // e.g., 7:00 AM
    var sleepTime: Date          // e.g., 10:00 PM
    
    var priorities: [TodayPriority]
    var timeBlocks: [TimeBlock]
}

// Mirror your existing structures, but make them Codable:
struct TodayPriority: Identifiable, Codable {
    var id: UUID
    var title: String
    var progress: Double
}

struct TimeBlock: Identifiable, Codable {
    var id: UUID
    var time: String   // e.g., "7:00 AM"
    var task: String   // e.g., "Gym"
}
