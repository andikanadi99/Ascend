//
//  ContentView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI
import CoreData
struct ContentView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationView {
            SwiftUI.Group {
                if session.current_user != nil {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
        }
    }
}


#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SessionStore())
        .environmentObject(HabitViewModel())
        .preferredColorScheme(.dark)
}
