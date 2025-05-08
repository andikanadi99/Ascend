//
//  Mind_ResetApp.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UserNotifications

@main
struct Mind_ResetApp: App {
    @StateObject var session         = SessionStore()
    @StateObject var habitViewModel  = HabitViewModel()
    @StateObject var dayViewState    = DayViewState()
    @StateObject var weekViewState   = WeekViewState()
    @StateObject var monthViewState  = MonthViewState()

    let persistenceController = PersistenceController.shared

    // -------------------------------------------------------------
    init() {
        // Firebase bootstrap
        FirebaseApp.configure()

        // Enable Firestore disk cache
        var settings = FirestoreSettings()
        settings.isPersistenceEnabled = true

        if #available(iOS 17, *) {
            settings.cacheSettings =
                PersistentCacheSettings(sizeBytes: NSNumber(value: 20 * 1024 * 1024))
        }
        Firestore.firestore().settings = settings

        // Notifications setup
        _ = NotificationDelegate.shared
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            // …
        }
    }


    // -------------------------------------------------------------
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                             persistenceController.container.viewContext)
                .environmentObject(session)
                .environmentObject(habitViewModel)
                .environmentObject(dayViewState)
                .environmentObject(weekViewState)
                .environmentObject(monthViewState)
        }
    }
}
