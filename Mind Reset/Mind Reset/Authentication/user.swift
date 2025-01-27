////
////  user.swift
////  Mind Reset
////
////  Created by Andika Yudhatrisna on 1/27/25.
////
//
//// User.swift
//
//import Foundation
//import FirebaseAuth
//import FirebaseFirestore
//
///// Represents a user in the Mind Reset app.
//struct User: Identifiable, Codable {
//    /// Unique identifier for the user (Firestore document ID).
//    @DocumentID var id: String?
//    
//    /// User's email address.
//    var email: String
//    
//    /// User's display name. Can be empty by default.
//    var displayName: String
//    
//    /// Total points accumulated from habit completion.
//    var totalPoints: Int
//    
//    /// Timestamp of when the user account was created.
//    @ServerTimestamp var createdAt: Timestamp?
//    
//    /// Boolean to check if the default habits have been created for this user.
//    var defaultHabitsCreated: Bool = false
//    
//    /// Computed property to convert `createdAt` to `Date`.
//    var userCreationDate: Date? {
//        return createdAt?.dateValue()
//    }
//}
