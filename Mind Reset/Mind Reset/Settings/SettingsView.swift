import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var showDeleteAccountAlert = false
    @State private var isDarkMode: Bool = true
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Account Settings
                Section(header: Text("Account Settings")
                            .foregroundColor(accentCyan)) {
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
                Section(header: Text("App Settings")
                            .foregroundColor(accentCyan)) {
                    NavigationLink(destination: NotificationPreferencesView()) {
                        Label("Notification Preferences", systemImage: "bell.fill")
                            .foregroundColor(.white)
                    }
                }

                // MARK: - Support
                Section(header: Text("Support")
                            .foregroundColor(accentCyan)) {
                    NavigationLink(destination: SupportSettingsView()) {
                        Label("Contact Us", systemImage: "envelope.fill")
                            .foregroundColor(.white)
                    }
                }

                // MARK: - About
                Section(header: Text("About")
                            .foregroundColor(accentCyan)) {
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
                    Button(action: signOut) {
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
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading:
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Settings")
                    }
                    .foregroundColor(accentCyan)
                }
            )
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    // MARK: - Actions
    private func signOut() {
        session.signOut()
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SessionStore())
    }
}
