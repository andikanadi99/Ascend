//
//  TodayPriority+Codable.swift
//  Mind Reset
//
//  Adds a lightweight dictionary view so Week-level edits can patch
//  ONLY the `priorities` array in a DaySchedule document.
//

import Foundation

extension TodayPriority {
    /// Minimal Firestore representation (no wake/sleep fields touched).
    var asDictionary: [String: Any] {
        [
            "id"          : id.uuidString,
            "title"       : title,
            "progress"    : progress,
            "isCompleted" : isCompleted
        ]
    }
}
