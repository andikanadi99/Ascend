//
//  Habit.swift
//  Mind Reset
//
//  Defines the data model for habits with customizable metrics.
//  Created by Andika Yudhatrisna on 1/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - Metric Categories and Types

/// Represents the general categories of metrics a user can select.
enum MetricCategory: String, CaseIterable, Identifiable, Codable {
    case time = "Time Metrics"
    case quantity = "Quantity Metrics"
    case completion = "Completion Metrics"
    case performance = "Performance Metrics"
    case custom = "Custom Metrics"
    
    var id: String { self.rawValue }
    
    /// Returns the list of metric types based on the selected category.
    var metricTypes: [MetricType] {
        switch self {
        case .time:
            return TimeMetric.allCases.map { .predefined($0.rawValue) }
        case .quantity:
            return QuantityMetric.allCases.map { .predefined($0.rawValue) }
        case .completion:
            return CompletionMetric.allCases.map { .predefined($0.rawValue) }
        case .performance:
            return PerformanceMetric.allCases.map { .predefined($0.rawValue) }
        case .custom:
            return [] // Custom category will handle its own custom types
        }
    }
}

/// Represents both predefined and custom metric types.
enum MetricType: Codable, Identifiable, Equatable, Hashable {
    case predefined(String)
    case custom(String)
    
    var id: String {
        switch self {
        case .predefined(let type):
            return type
        case .custom(let type):
            return type
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        
        if type == "predefined" {
            self = .predefined(value)
        } else {
            self = .custom(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .predefined(let value):
            try container.encode("predefined", forKey: .type)
            try container.encode(value, forKey: .value)
        case .custom(let value):
            try container.encode("custom", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
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
struct HabitRecord: Identifiable, Codable, Equatable {
    var id: String? = UUID().uuidString
    var date: Date
    var value: Double? // For example, minutes, pages, or a flag (1 for completed, 0 for not)
    
    enum CodingKeys: String, CodingKey {
        case id, date, value
    }
    
    init(date: Date, value: Double?) {
        self.date = date
        self.value = value
    }
}

// MARK: - Habit

/// Defines a habit with customizable tracking metrics.
/// NOTE: The `isCompletedToday` property has been removed in favor of tracking daily completion via `dailyRecords`.
struct Habit: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var goal: String
    var startDate: Date
    var ownerId: String
    
    // Removed: var isCompletedToday: Bool
    var lastReset: Date?
    var points: Int
    var currentStreak: Int
    var longestStreak: Int
    var weeklyStreakBadge: Bool
    var monthlyStreakBadge: Bool
    var yearlyStreakBadge: Bool
    
    // MARK: - New Properties for Customizable Metrics
    var metricCategory: MetricCategory
    var metricType: MetricType
    var dailyRecords: [HabitRecord]
    
    // MARK: - Initializer
    init(
        title: String,
        description: String,
        goal: String,
        startDate: Date,
        ownerId: String,
        // isCompletedToday is removed – use dailyRecords for per-day tracking
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastReset: Date? = nil,
        weeklyStreakBadge: Bool = false,
        monthlyStreakBadge: Bool = false,
        yearlyStreakBadge: Bool = false,
        metricCategory: MetricCategory = .completion,
        metricType: MetricType = .predefined("Completed (Yes/No)"),
        dailyRecords: [HabitRecord] = []
    ) {
        self.title = title
        self.description = description
        self.goal = goal
        self.startDate = startDate
        self.ownerId = ownerId
        
        self.lastReset = lastReset
        self.points = 0
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.weeklyStreakBadge = weeklyStreakBadge
        self.monthlyStreakBadge = monthlyStreakBadge
        self.yearlyStreakBadge = yearlyStreakBadge
        
        self.metricCategory = metricCategory
        self.metricType = metricType
        self.dailyRecords = dailyRecords
    }
    
    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey {
        case id, title, description, goal, startDate, ownerId,
             // Removed isCompletedToday from the coding keys.
             lastReset, points, currentStreak, longestStreak, weeklyStreakBadge, monthlyStreakBadge, yearlyStreakBadge,
             metricCategory, metricType, dailyRecords
    }
}

// MARK: - MetricType Extension

extension MetricType {
    /// Returns true if the metric type is "Completed (Yes/No)".
    func isCompletedMetric() -> Bool {
        switch self {
        case .predefined(let value):
            return value.lowercased().contains("completed")
        case .custom:
            return false
        }
    }
}
