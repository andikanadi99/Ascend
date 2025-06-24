// WeeklySchedule.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 3/26/25.


import Foundation
import FirebaseFirestore

// MARK: - WeeklySchedule
struct WeeklySchedule: Identifiable, Codable {

    // ───── Stored fields ─────
    var id: String?                    // Firestore docID (yyyy-MM-dd)
    var userId: String
    var startOfWeek: Date              // anchor date (respecting firstWeekday)

    /// 1 = Sunday … 7 = Saturday
    /// *Optional* so older documents (that don’t have this key) still decode.
    var anchorWeekday: Int?
    /// ISO year-week string, e.g. “2025-W27” (optional for same reason)
    var isoYearWeek: String?

    var weeklyPriorities: [WeeklyPriority]
    var dailyIntentions:  [String:String]
    var dailyToDoLists:   [String:[ToDoItem]]

    // ───── Static helpers ─────
    static func isoYearWeekString(from date: Date) -> String {
        let cal   = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d",
                      comps.yearForWeekOfYear ?? 0,
                      comps.weekOfYear       ?? 0)
    }

    // ───── Codable conformance ─────
    enum CodingKeys: String, CodingKey {
        case id, userId, startOfWeek,
             anchorWeekday, isoYearWeek,
             weeklyPriorities, dailyIntentions, dailyToDoLists
    }

    /// Custom decoder so missing keys don’t throw for legacy docs
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id              = try c.decodeIfPresent(String.self, forKey: .id)
        userId          = try c.decode(String.self,           forKey: .userId)
        startOfWeek     = try c.decode(Date.self,             forKey: .startOfWeek)
        anchorWeekday   = try c.decodeIfPresent(Int.self,     forKey: .anchorWeekday)
        isoYearWeek     = try c.decodeIfPresent(String.self,  forKey: .isoYearWeek)
        weeklyPriorities = try c.decode([WeeklyPriority].self,
                                        forKey: .weeklyPriorities)
        dailyIntentions  = try c.decode([String:String].self,
                                        forKey: .dailyIntentions)
        dailyToDoLists   = try c.decode([String:[ToDoItem]].self,
                                        forKey: .dailyToDoLists)

        // ── Fallback defaults for older docs ──
        if anchorWeekday == nil {
            anchorWeekday = Calendar.current.firstWeekday
        }
        if isoYearWeek == nil {
            isoYearWeek = Self.isoYearWeekString(from: startOfWeek)
        }
    }

    /// Default encoder (all properties encode as-is)
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id,              forKey: .id)
        try c.encode(userId,                   forKey: .userId)
        try c.encode(startOfWeek,              forKey: .startOfWeek)
        try c.encode(anchorWeekday,            forKey: .anchorWeekday)
        try c.encode(isoYearWeek,              forKey: .isoYearWeek)
        try c.encode(weeklyPriorities,         forKey: .weeklyPriorities)
        try c.encode(dailyIntentions,          forKey: .dailyIntentions)
        try c.encode(dailyToDoLists,           forKey: .dailyToDoLists)
    }

    // ───── Convenience initialiser for new / migrated docs ─────
    init(id: String?,
         userId: String,
         startOfWeek: Date,
         anchorWeekday: Int,
         weeklyPriorities: [WeeklyPriority] = [],
         dailyIntentions:  [String:String]   = [:],
         dailyToDoLists:   [String:[ToDoItem]] = [:]) {

        self.id              = id
        self.userId          = userId
        self.startOfWeek     = startOfWeek
        self.anchorWeekday   = anchorWeekday
        self.isoYearWeek     = WeeklySchedule.isoYearWeekString(from: startOfWeek)
        self.weeklyPriorities = weeklyPriorities
        self.dailyIntentions  = dailyIntentions
        self.dailyToDoLists   = dailyToDoLists
    }
}

// MARK: - WeeklyPriority
struct WeeklyPriority: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var progress: Double
    var isCompleted: Bool

    init(id: UUID, title: String, progress: Double, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.progress = progress
        self.isCompleted = isCompleted
    }
}

// MARK: - ToDoItem
struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
}

