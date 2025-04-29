import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore

    init() {
        // Selected item → white
        UITabBar.appearance().tintColor = .white
        
        // Un-selected items → system gray
        UITabBar.appearance().unselectedItemTintColor = UIColor(
            white: 1.0, alpha: 0.45)          // or  .systemGray  /  .lightGray
        
        // Optional: dark background so the contrast is clear
        UITabBar.appearance().barTintColor = .black
        UITabBar.appearance().backgroundColor = .black
    }

    var body: some View {
        TabView {
            SchedulerView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            HabitTrackerView()
                .tabItem {
                    Label("Habits", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.white)        // ensures selected label text is white
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionStore())
            .preferredColorScheme(.dark)
    }
}
