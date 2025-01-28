//
//  UserModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 1/28/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct UserModel: Identifiable, Codable {
    @DocumentID var id: String? // Firestore document ID
    var email: String
    var displayName: String
    var totalPoints: Int
    var createdAt: Date
    var meditationTime: Int
    var deepWorkTime: Int
    var defaultHabitsCreated: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case totalPoints
        case createdAt
        case meditationTime
        case deepWorkTime
        case defaultHabitsCreated
    }
}
