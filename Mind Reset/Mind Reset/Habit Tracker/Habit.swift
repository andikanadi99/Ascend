//
//  Habit.swift
//  Mind Reset
//  Class definition of a Habit on MindReset
//  Created by Andika Yudhatrisna on 12/1/24.
//

import Foundation
import FirebaseFirestore

struct Habit: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var startDate: Date
    var ownerId: String

    // Tracks if the habit is done for the current day
    var isCompletedToday: Bool = false

    // (optional) Last date we marked it undone
    var lastReset: Date? = nil

    /// The total points accumulated for this habit
    var points: Int = 0

    /// The current streak count for this habit
    var currentStreak: Int = 0

    /// The longest streak ever achieved for this habit
    var longestStreak: Int = 0

    /// Indicates if the user is currently on a 7-day streak
    var weeklyStreakBadge: Bool = false

    /// Indicates if the user is currently on a 30-day streak
    var monthlyStreakBadge: Bool = false

    /// Indicates if the user is currently on a 365-day streak
    var yearlyStreakBadge: Bool = false
}
