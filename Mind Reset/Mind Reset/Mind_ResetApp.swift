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
    // Instantiate SessionStore as a StateObject
    @StateObject var session = SessionStore()
    let persistenceController = PersistenceController.shared

    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(session) // Inject SessionStore into the environment
        }
    }
}




