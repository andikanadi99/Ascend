//
//  MonthSchedule.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/27/25.
//
import Foundation
import FirebaseFirestore

struct MonthSchedule: Identifiable, Codable {
    @DocumentID var id: String? = nil
    
    var userId: String
    var yearMonth: String         // e.g. "2025-03"
    var monthlyPriorities: [MonthlyPriority]
    // Key = "YYYY-MM-DD", Value = completion fraction from 0..1
    var dayCompletions: [String: Double]
}

struct MonthlyPriority: Identifiable, Codable {
    var id: UUID
    var title: String
    var progress: Double   // value 0.0..1.0
}

