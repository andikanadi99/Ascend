//
//  MainTabView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/25/24.
//
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: SessionStore // Access SessionStore
    var body: some View {
        VStack(spacing: 30) {
            // Welcome Message
            Text("Welcome, \(userEmail)!")
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding()
            
            // Sign Out Button
            Button(action: {
                signOut()
            }) {
                Text("Sign Out")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationBarHidden(true) // Hide the navigation bar if present
    }
    
    // Computed property to get the user's email
    private var userEmail: String {
        return session.current_user?.email ?? "User"
    }
    
    // Sign Out Function
    private func signOut() {
        session.signOut()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(SessionStore())
    }
}

