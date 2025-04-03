import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @State private var showDeleteAccountAlert = false
    @State private var isDarkMode: Bool = true // default to dark mode for your theme
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    
    // Define your accent cyan color.
    let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Account Settings
                Section(header: Text("Account Settings").foregroundColor(accentCyan)) {
                    NavigationLink(destination: ProfileInfo()) {
                        Label("Profile Info", systemImage: "person.crop.circle")
                            .foregroundColor(.white)
                    }
                    NavigationLink(destination: ChangeCredentialsView()) {
                        Label("Change Password/Email", systemImage: "key.fill")
                            .foregroundColor(.white)
                    }
                    NavigationLink(destination: DeleteAccountView()) {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundColor(.white)
                    }
                }
                
                // MARK: - App Settings
                Section(header: Text("App Settings").foregroundColor(accentCyan)) {
                    NavigationLink(destination: NotificationPreferencesView()) {
                        Label("Notification Preferences", systemImage: "bell.fill")
                            .foregroundColor(.white)
                    }
//                    NavigationLink(destination: PrivacySettingsView()) {
//                        Label("Privacy Settings", systemImage: "lock.shield")
//                            .foregroundColor(.white)
//                    }
                }
                
                // MARK: - Support
                Section(header: Text("Support").foregroundColor(accentCyan)) {
                    NavigationLink(destination: SupportSettingsView()) {
                        Label("Contact Us", systemImage: "envelope.fill")
                            .foregroundColor(.white)
                    }
                }
                
                // MARK: - Legal & About
                Section(header: Text("About").foregroundColor(accentCyan)) {
//                    NavigationLink(destination: PrivacyPolicyView()) {
//                        Label("Privacy Policy", systemImage: "hand.raised.fill")
//                            .foregroundColor(.white)
//                    }
//                    NavigationLink(destination: TermsOfUseView()) {
//                        Label("Terms of Use", systemImage: "doc.text.fill")
//                            .foregroundColor(.white)
//                    }
                    HStack {
                        Text("App Version")
                            .foregroundColor(.white)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - Sign Out
                Section {
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
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Functions
    
    private func signOut() {
        session.signOut()
    }
    
    private func deleteAccount() {
        // Implement your account deletion logic here.
        print("Account deleted.")
        // After deletion, sign out.
        session.signOut()
    }
}

// MARK: - Placeholder Subviews



struct ContactUsView: View {
    var body: some View {
        Text("Contact Us (Coming Soon)")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Contact Us")
    }
}

struct ReportProblemView: View {
    var body: some View {
        Text("Report a Problem (Coming Soon)")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Report a Problem")
    }
}

struct TermsOfUseView: View {
    var body: some View {
        Text("Terms of Use (Coming Soon)")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Terms of Use")
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SessionStore())
    }
}
