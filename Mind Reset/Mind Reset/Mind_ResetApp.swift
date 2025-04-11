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
    @StateObject var session = SessionStore()
    @StateObject var habitViewModel = HabitViewModel()
    @StateObject var dayViewState = DayViewState()
    @StateObject var weekViewState = WeekViewState()
    @StateObject var monthViewState = MonthViewState()  // <-- new

    let persistenceController = PersistenceController.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(session)
                .environmentObject(habitViewModel)
                .environmentObject(dayViewState)
                .environmentObject(weekViewState)
                .environmentObject(monthViewState) // <-- inject
        }
    }
}
