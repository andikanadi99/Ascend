//
//  MainTabView.swift
//  Mind Reset
//  This View handles the landing page of the app
//  Created by Andika Yudhatrisna on 11/25/24.
//
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        TabView {
            // 1) Habit Tracker as Home
            HabitTrackerView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // 2) Progress Tab
            SchedulerView()
                .tabItem {
                    Label("Schedule", systemImage: "chart.bar.fill")
                }

            // 3) Settings Tab (Sign Out button moved here)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.cyan) // The color of the selected tab icon/label
    }
}



// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionStore())
    }
}


