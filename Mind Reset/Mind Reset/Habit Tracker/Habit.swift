//
//  Habit.swift
//  Mind Reset
//  Class definition of a Habit on MindReset
//  Created by Andika Yudhatrisna on 12/1/24.
//

import Foundation
import FirebaseFirestore

struct Habit: Identifiable, Codable {
    @DocumentID var id: String? //Firestine will assigne a unique ID to the habit
    var title: String
    var description : String
    var startDate : Date
    var isCompletedToday: Bool = false
    var streak: Int = 0
    var ownerId: String //associate habit with specific user
}
