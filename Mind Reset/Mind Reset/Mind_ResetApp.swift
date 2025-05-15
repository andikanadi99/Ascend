//
//  Mind_ResetApp.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import GoogleSignIn
import UserNotifications

// ────────────────────────────────────────────────────────────────
// MARK: - UIKit App-Delegate (needed for Google Sign-in URL hook)
// ────────────────────────────────────────────────────────────────
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // 1️⃣  Firebase bootstrap
        FirebaseApp.configure()

        // 1.1️⃣  Configure Google Sign-In with your Firebase ClientID
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            assertionFailure("⚠️ Could not read Firebase clientID from GoogleService-Info.plist")
        }

        // ——— OPTIONAL EMULATOR SECTION (leave commented for production) ———
        /*
        #if DEBUG
        // Auth emulator
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)

        // Firestore emulator
        let fdb = Firestore.firestore()
        var fSettings            = fdb.settings
        fSettings.host           = "localhost:8080"
        fSettings.isPersistenceEnabled = false
        fSettings.isSSLEnabled   = false
        fdb.settings             = fSettings

        // Functions emulator
        Functions.functions().useEmulator(withHost: "localhost", port: 5001)
        #endif
        */

        // 2️⃣  Firestore on-device cache (production)
        var prodSettings                   = FirestoreSettings()
        prodSettings.isPersistenceEnabled  = true
        if #available(iOS 17, *) {
            prodSettings.cacheSettings =
                PersistentCacheSettings(sizeBytes: NSNumber(value: 20 * 1024 * 1024))
        }
        Firestore.firestore().settings = prodSettings

        // 3️⃣  Local-notification permissions
        _ = NotificationDelegate.shared
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }

        return true
    }

    // 4️⃣  Google-sign-in URL handler
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Pass the URL to the GIDSignIn instance and return the result.
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// ────────────────────────────────────────────────────────────────
// MARK: - SwiftUI entry point
// ────────────────────────────────────────────────────────────────
@main
struct Mind_ResetApp: App {

    // Hook UIKit delegate into SwiftUI lifecycle
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    // Global state objects
    @StateObject private var session        = SessionStore()
    @StateObject private var habitViewModel = HabitViewModel()
    @StateObject private var dayViewState   = DayViewState()
    @StateObject private var weekViewState  = WeekViewState()
    @StateObject private var monthViewState = MonthViewState()

    private let persistenceController = PersistenceController.shared

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
