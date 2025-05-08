//
//  Mind_ResetApp.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth           // ← added
import FirebaseFunctions      // ← added
import UserNotifications

@main
struct Mind_ResetApp: App {
    @StateObject var session         = SessionStore()
    @StateObject var habitViewModel  = HabitViewModel()
    @StateObject var dayViewState    = DayViewState()
    @StateObject var weekViewState   = WeekViewState()
    @StateObject var monthViewState  = MonthViewState()

    let persistenceController = PersistenceController.shared

    init() {
        // 1️⃣ Firebase bootstrap
        FirebaseApp.configure()

        /*
        #if DEBUG
        // ← Comment out or delete this whole block before you ship:
        // Auth emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        // Firestore emulator
        let fdb = Firestore.firestore()
        var fSettings = fdb.settings
        fSettings.host = "localhost:8080"
        fSettings.isPersistenceEnabled = false
        fSettings.isSSLEnabled = false
        fdb.settings = fSettings

        // Functions emulator
        Functions.functions().useEmulator(withHost: "localhost", port: 5001)
        #endif
        */

        // 5️⃣ Enable Firestore disk cache (production / release)
        var prodSettings = FirestoreSettings()
        prodSettings.isPersistenceEnabled = true
        if #available(iOS 17, *) {
            prodSettings.cacheSettings =
                PersistentCacheSettings(sizeBytes: NSNumber(value: 20 * 1024 * 1024))
        }
        Firestore.firestore().settings = prodSettings

        // 6️⃣ Notifications setup
        _ = NotificationDelegate.shared
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in /* … */ }
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
                .environmentObject(monthViewState)
        }
    }
}
