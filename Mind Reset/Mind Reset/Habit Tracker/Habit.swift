//
//  Habit.swift
//  Mind Reset
//  Defines the data model for habits.
//
import Foundation
import FirebaseFirestore

struct Habit: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var startDate: Date
    var ownerId: String            // Must match the authenticated user’s UID
    
    // Tracks if the habit is done for the current day
    var isCompletedToday: Bool = false

    // The last date we reset this habit (could be used to check if new day has started)
    var lastReset: Date? = nil

    // Points associated with this habit
    var points: Int = 0

    // Current consecutive streak
    var currentStreak: Int = 0

    // The longest consecutive streak
    var longestStreak: Int = 0

    // Badges: Weekly, Monthly, Yearly
    var weeklyStreakBadge: Bool = false
    var monthlyStreakBadge: Bool = false
    var yearlyStreakBadge: Bool = false
}
