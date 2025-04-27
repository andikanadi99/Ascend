//  SettingsView.swift
//  Mind Reset.
//
//  Created by Andika Yudhatrisna on 2/6/25.


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        NavigationView {
            Form {
                // Account
                Section(header: Text("Account Settings").foregroundColor(accentCyan)) {
                    NavigationLink(destination: ProfileInfo()) {
                        Label("Profile Info", systemImage: "person.crop.circle")
                            .foregroundColor(.white)
                    }
                    NavigationLink(destination: ChangeCredentialsView()) {
                        Label("Change Password", systemImage: "key.fill")
                            .foregroundColor(.white)
                    }
                    NavigationLink(destination: DeleteAccountView()) {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundColor(.white)
                    }
                }
                
                // App
                Section(header: Text("App Settings").foregroundColor(accentCyan)) {
                    NavigationLink(destination: NotificationPreferencesView()) {
                        Label("Notification Preferences", systemImage: "bell.fill")
                            .foregroundColor(.white)
                    }
                }
                
                // Support
                Section(header: Text("Support").foregroundColor(accentCyan)) {
                    NavigationLink(destination: SupportSettingsView()) {
                        Label("Contact Us", systemImage: "envelope.fill")
                            .foregroundColor(.white)
                    }
                }
                
                // About
                Section(header: Text("About").foregroundColor(accentCyan)) {
                    HStack {
                        Text("App Version").foregroundColor(.white)
                        Spacer()
                        Text("1.0.0").foregroundColor(.gray)
                    }
                }
                
                // Sign-out
                Section {
                    Button(role: .destructive) { session.signOut() } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}

// ───────── Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(SessionStore())
    }
}
