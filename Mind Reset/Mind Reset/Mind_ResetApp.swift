//
//  Mind_ResetApp.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseFirestore

@main
struct Mind_ResetApp: App {
    // MARK: - State Objects
    @StateObject var session = SessionStore()
    @StateObject var habitViewModel = HabitViewModel()
    
    let persistenceController = PersistenceController.shared

    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject your Core Data context
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Inject SessionStore
                .environmentObject(session)
                // Inject HabitViewModel
                .environmentObject(habitViewModel)
        }
    }
}
