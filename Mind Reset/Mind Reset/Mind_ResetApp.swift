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
import UserNotifications  // ← for local notifications

@main
struct Mind_ResetApp: App {
    @StateObject var session = SessionStore()
    @StateObject var habitViewModel = HabitViewModel()
    @StateObject var dayViewState = DayViewState()
    @StateObject var weekViewState = WeekViewState()
    @StateObject var monthViewState = MonthViewState()  // <-- new

    let persistenceController = PersistenceController.shared

    init() {
        // Firebase
        FirebaseApp.configure()

        // 1️⃣ Wire up our notification delegate so we can show banners in-app
        _ = NotificationDelegate.shared

        // 2️⃣ Request user permission for alerts, sounds, badges
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification auth request failed: \(error.localizedDescription)")
            } else {
                print("Notifications permission granted? \(granted)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
                .environmentObject(session)
                .environmentObject(habitViewModel)
                .environmentObject(dayViewState)
                .environmentObject(weekViewState)
                .environmentObject(monthViewState) // <-- inject
        }
    }
}

