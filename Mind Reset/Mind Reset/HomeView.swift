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
            SettingsViewPlaceholder(session: _session)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.cyan) // The color of the selected tab icon/label
    }
}


// MARK: - SettingsViewPlaceholder
// The Settings tab now includes the sign-out button.
struct SettingsViewPlaceholder: View {
    @EnvironmentObject var session: SessionStore

    // Or inject it directly as a parameter if you prefer:
    // let session: SessionStore

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 30) {
                    Text("Settings (Placeholder)")
                        .foregroundColor(.white)
                        .font(.title)
                        .fontWeight(.semibold)
                        .padding()

                    // Sign Out Button Moved Here
                    Button(action: {
                        signOut()
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }

    // Sign Out Function
    private func signOut() {
        session.signOut()
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SessionStore())
    }
}


