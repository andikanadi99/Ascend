//
//  Habit.swift
//  Mind Reset
//  Defines the data model for habits.
//
//  Created by Andika Yudhatrisna on 1/3/25.
//

import Foundation
import FirebaseFirestore

// MARK: - HabitRecord
// Represents daily records for a habit, including the date and intensity score.
struct HabitRecord: Identifiable, Codable {
    var id: String? = UUID().uuidString
    var date: Date
    var intensityScore: CGFloat
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case intensityScore
    }
    
    init(date: Date, intensityScore: CGFloat) {
        self.date = date
        self.intensityScore = intensityScore
    }
}

// MARK: - Habit
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
    
    // New properties
    var goal: String // Defaults to an empty string if not set
    var dailyRecords: [HabitRecord] // Stores intensity scores per day
    
    // Initialize with default values for new habits
    init(title: String, description: String, startDate: Date, ownerId: String, goal: String = "", dailyRecords: [HabitRecord] = []) {
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
        self.dailyRecords = dailyRecords
    }
    
    // Update initializer for Codable
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case startDate
        case ownerId
        case isCompletedToday
        case lastReset
        case points
        case currentStreak
        case longestStreak
        case weeklyStreakBadge
        case monthlyStreakBadge
        case yearlyStreakBadge
        case goal
        case dailyRecords
    }
}
