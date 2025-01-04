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
    
    // Tracks the running streak
    var streak: Int = 0
    
    // (optional) Last date we marked it undone
    var lastReset: Date? = nil
}
