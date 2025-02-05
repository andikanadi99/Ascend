//
//  UserNote.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/4/25.
//

import Foundation
import FirebaseFirestore

struct UserNote: Identifiable, Codable {
    @DocumentID var id: String?
    var habitID: String
    var noteText: String
    var timestamp: Date
    
    init(habitID: String, noteText: String, timestamp: Date = Date()) {
        self.habitID = habitID
        self.noteText = noteText
        self.timestamp = timestamp
    }
}
