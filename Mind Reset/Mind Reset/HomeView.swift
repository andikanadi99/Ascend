import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        TabView {
            // 1) Scheduler as Home
            SchedulerView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // 2) Habit Tracker Tab
            HabitTrackerView()
                .tabItem {
                    Label("Habits", systemImage: "list.bullet")
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

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionStore())
    }
}
