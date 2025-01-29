//
//  Habit.swift
//  Mind Reset
//  Defines the data model for habits with customizable metrics.
//
//  Created by Andika Yudhatrisna on 1/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - Metric Categories and Types

/// Represents the general categories of metrics a user can select.
enum MetricCategory: String, CaseIterable, Identifiable, Codable {
    case time = "Time"
    case quantity = "Quantity"
    case completion = "Completion"
    case performance = "Performance"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}

/// Specific metric types under the Time category.
enum TimeMetric: String, CaseIterable, Identifiable, Codable {
    case minutes = "Minutes"
    case hours = "Hours"
    case consistencyScore = "Consistency Score"
    
    var id: String { self.rawValue }
}

/// Specific metric types under the Quantity category.
enum QuantityMetric: String, CaseIterable, Identifiable, Codable {
    case pagesRead = "Pages Read"
    case entriesWritten = "Entries Written"
    case repsDone = "Reps Done"
    case newWordsLearned = "New Words Learned"
    case projectsDone = "Projects Done"
    case weightLbs = "Weight (lbs)"
    case weightKg = "Weight (kg)"
    case distanceMiles = "Distance (miles)"
    case distanceKm = "Distance (km)"
    
    var id: String { self.rawValue }
}

/// Specific metric types under the Completion category.
enum CompletionMetric: String, CaseIterable, Identifiable, Codable {
    case completed = "Completed (Yes/No)"
    case stepsTaken = "Steps Taken"
    
    var id: String { self.rawValue }
}

/// Specific metric types under the Performance category.
enum PerformanceMetric: String, CaseIterable, Identifiable, Codable {
    case caloriesBurned = "Calories Burned"
    case caloriesConsumed = "Calories Consumed"
    case sleepHours = "Sleep (Hours)"
    case posesHeld = "Poses Held (count)"
    
    var id: String { self.rawValue }
}

// MARK: - HabitRecord
/// Represents daily records for a habit, including the date and the metric value.
struct HabitRecord: Identifiable, Codable {
    var id: String? = UUID().uuidString
    var date: Date
    var value: Double? // Represents the metric value for the day (e.g., minutes, pages, completed: 1 for yes, 0 for no)
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case value
    }
    
    init(date: Date, value: Double?) {
        self.date = date
        self.value = value
    }
}

// MARK: - Habit
/// Defines a habit with customizable tracking metrics.
struct Habit: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var goal: String
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
    
    // MARK: - New Properties for Customizable Metrics
    var metricCategory: MetricCategory // The general category of the metric
    var metricType: String // The specific metric type or custom description
    var targetValue: Double // The goal value based on the metric type
    var dailyRecords: [HabitRecord] // Stores metric values per day
    
    // MARK: - Corrected Initializer
    init(
        title: String,
        description: String,
        goal: String,
        startDate: Date,
        ownerId: String,
        isCompletedToday: Bool = false,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastReset: Date? = nil,
        weeklyStreakBadge: Bool = false,
        monthlyStreakBadge: Bool = false,
        yearlyStreakBadge: Bool = false,
        metricCategory: MetricCategory = .completion,
        metricType: String = "Completed (Yes/No)",
        targetValue: Double = 1.0,
        dailyRecords: [HabitRecord] = []
    ) {
        self.title = title
        self.description = description
        self.goal = goal
        self.startDate = startDate
        self.ownerId = ownerId
        self.isCompletedToday = isCompletedToday              // Correctly assigned
        self.lastReset = lastReset                            // Correctly assigned
        self.points = 0                                       // Initialized as per original logic
        self.currentStreak = currentStreak                    // Correctly assigned
        self.longestStreak = longestStreak                    // Correctly assigned
        self.weeklyStreakBadge = weeklyStreakBadge            // Correctly assigned
        self.monthlyStreakBadge = monthlyStreakBadge          // Correctly assigned
        self.yearlyStreakBadge = yearlyStreakBadge            // Correctly assigned
        self.metricCategory = metricCategory                  // Correctly assigned
        self.metricType = metricType                          // Correctly assigned
        self.targetValue = targetValue                        // Correctly assigned
        self.dailyRecords = dailyRecords                      // Correctly assigned
    }
    
    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case goal
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
        case metricCategory
        case metricType
        case targetValue
        case dailyRecords
    }
}
