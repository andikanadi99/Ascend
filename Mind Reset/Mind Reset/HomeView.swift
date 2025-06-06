import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore

    init() {
        // Selected item → white
        UITabBar.appearance().tintColor = .white

        // Un-selected items → translucent gray
        UITabBar.appearance().unselectedItemTintColor = UIColor(white: 1.0, alpha: 0.45)

        // Dark background for contrast
        UITabBar.appearance().barTintColor       = .black
        UITabBar.appearance().backgroundColor    = .black
    }

    var body: some View {
        TabView {
            // ───────── Home
            SchedulerView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // ───────── Habits
            HabitTrackerView()
                .tabItem {
                    Label("Habits", systemImage: "list.bullet")
                }

            // ───────── Settings (wrapped in its own NavigationStack)
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .accentColor(.white)          // selected label tint
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionStore())
            .preferredColorScheme(.dark)
    }
}

