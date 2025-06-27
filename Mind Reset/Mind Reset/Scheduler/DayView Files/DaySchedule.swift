//
//  DaySchedule.swift
//  Mind Reset
//


import Foundation
import FirebaseFirestore

/// Represents the full daily schedule for a user.
struct DaySchedule: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var wakeUpTime: Date
    var sleepTime: Date
    var priorities: [TodayPriority]
    var timeBlocks: [TimeBlock]

    /// Convenience constructor for “empty” docs (used by WeekViewModel seed).
    init(
        id: String,
        userId: String,
        date: Date,
        wakeUpTime: Date,
        sleepTime: Date,
        priorities: [TodayPriority],
        timeBlocks: [TimeBlock]
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.wakeUpTime = wakeUpTime
        self.sleepTime = sleepTime
        self.priorities = priorities
        self.timeBlocks = timeBlocks
    }

    /// Static helper for WeekViewModel.
    static func documentID(for date: Date, userId: String) -> String {
        let f = WeekViewModel.iso
        return f.string(from: Calendar.current.startOfDay(for: date))
    }
}

/// Top-priority item for the day.
struct TodayPriority: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var progress: Double
    var isCompleted: Bool

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

/// A time-block in the daily schedule, with explicit start and end.
struct TimeBlock: Identifiable, Codable {
    var id: UUID
    var start: Date      // precise block start
    var end: Date        // precise block end
    var task: String     // description of the block

    /// Legacy-read computed label such as “7:00 AM”
    var time: String {
        TimeBlock.timeFormatter.string(from: start)
    }

    private enum CodingKeys: String, CodingKey {
        case id, start, end, task
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}


