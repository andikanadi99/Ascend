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
        NavigationView{
            Group {
                if session.current_user != nil {
                    // Show the MainTabView once user is authenticated
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .onAppear {
                session.listen()
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SessionStore())
}
