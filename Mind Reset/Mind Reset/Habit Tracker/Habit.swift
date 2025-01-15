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
    var ownerId: String
    var isCompletedToday: Bool
    var lastReset: Date?
    var points: Int
    var currentStreak: Int
    var longestStreak: Int
    var weeklyStreakBadge: Bool
    var monthlyStreakBadge: Bool
    var yearlyStreakBadge: Bool
    
    // New property for Habit Goal
    var goal: String // Defaults to an empty string if not set
    
    // Initialize with default values for new habits
    init(title: String, description: String, startDate: Date, ownerId: String, goal: String = "") {
        self.title = title
        self.description = description
        self.startDate = startDate
        self.ownerId = ownerId
        self.isCompletedToday = false
        self.lastReset = nil
        self.points = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.weeklyStreakBadge = false
        self.monthlyStreakBadge = false
        self.yearlyStreakBadge = false
        self.goal = goal
    }
}

