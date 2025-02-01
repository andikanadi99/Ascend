// Habit.swift

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
    
    // Custom CodingKeys to handle encoding and decoding
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    
    // Custom initializer to decode the enum
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
    
    // Custom encoder to encode the enum
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
    var metricType: MetricType // The specific metric type (predefined or custom)
    var targetValue: Double // The goal value based on the metric type
    var dailyRecords: [HabitRecord] // Stores metric values per day
    
    // MARK: - Initializer
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
        metricType: MetricType = .predefined("Completed (Yes/No)"),
        targetValue: Double = 1.0,
        dailyRecords: [HabitRecord] = []
    ) {
        self.title = title
        self.description = description
        self.goal = goal
        self.startDate = startDate
        self.ownerId = ownerId
        self.isCompletedToday = isCompletedToday
        self.lastReset = lastReset
        self.points = 0
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.weeklyStreakBadge = weeklyStreakBadge
        self.monthlyStreakBadge = monthlyStreakBadge
        self.yearlyStreakBadge = yearlyStreakBadge
        self.metricCategory = metricCategory
        self.metricType = metricType
        self.targetValue = targetValue
        self.dailyRecords = dailyRecords
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
