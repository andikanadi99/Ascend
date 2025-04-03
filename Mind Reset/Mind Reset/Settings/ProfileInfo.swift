//
//  ProfileInfo.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/2/25.
//

import SwiftUI

struct ProfileInfo: View {
    @EnvironmentObject var session: SessionStore
    @State private var isEditing: Bool = false
    @State private var updatedDisplayName: String = ""
    @State private var updatedEmail: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture Placeholder
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.accentColor)
            
            // Account Information Section
            if let user = session.userModel {
                if isEditing {
                    VStack(spacing: 10) {
                        TextField("Display Name", text: $updatedDisplayName)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        TextField("Email", text: $updatedEmail)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                } else {
                    Text(user.displayName.isEmpty ? "No Display Name" : user.displayName)
                        .font(.title)
                        .foregroundColor(.white)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text("Joined on \(formattedDate(user.createdAt))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("Loading Profile...")
                    .foregroundColor(.white)
            }
            
            // Edit / Save Button
            Button(action: {
                if isEditing {
                    updateProfile()
                } else if let user = session.userModel {
                    updatedDisplayName = user.displayName
                    updatedEmail = user.email
                }
                withAnimation { isEditing.toggle() }
            }) {
                Text(isEditing ? "Save Profile" : "Edit Profile")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
    
    // Helper function to format the join date.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // Stub function for updating the profile in Firestore.
    // Replace this with your actual Firestore update logic.
    private func updateProfile() {
        print("Updated profile: \(updatedDisplayName), \(updatedEmail)")
        // Example: Firestore update logic here...
    }
}

struct ProfileInfo_Previews: PreviewProvider {
    static var previews: some View {
        ProfileInfo()
            .environmentObject(SessionStore())
    }
}

