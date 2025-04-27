//
//  ChangeCredentialsView.swift
//  Mind Reset.
//
//  Created by Andika Yudhatrisna on 4/2/25.


import SwiftUI
import FirebaseAuth

// ────────────────────────────────────────────────────────────────
private enum VerificationStage { case none, reauth }

struct ChangeCredentialsView: View {
    @EnvironmentObject private var session: SessionStore
    
    // ───────── user input
    @State private var newPassword        = ""
    @State private var confirmPassword    = ""
    @State private var showNewPassword    = false      // 👁 toggle
    @State private var showConfirmPwd     = false      // 👁 toggle
    
    // ───────── re-auth modal
    @State private var currentPassword    = ""
    @State private var stage: VerificationStage = .none
    
    // ───────── alert
    @State private var showAlert  = false
    @State private var alertTitle = ""
    @State private var alertMsg   = ""
    
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    // ───────────────────────────────────────────────
    var body: some View {
        ZStack {
            formContent
                .blur(radius: stage == .none ? 0 : 3)
                .disabled(stage != .none)
            
            if stage == .reauth { reauthDialog }
        }
        .animation(.easeInOut, value: stage)
        .alert(alertTitle, isPresented: $showAlert) { } message: { Text(alertMsg) }
        .navigationTitle("Change Password")
        .scrollContentBackground(.hidden)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
    
    // MARK: – main form
    private var formContent: some View {
        Form {
            Section(header: Text("New Password").foregroundColor(accentCyan)) {

                PasswordFieldWithToggle(title: "New Password",
                                        text: $newPassword)

                PasswordFieldWithToggle(title: "Confirm New Password",
                                        text: $confirmPassword)

                Button("Update Password") { startFlow() }
                    .buttonStyle(CyanButtonStyle(color: accentCyan))
            }

        }
    }
    
    // MARK: – re-auth modal
    private var reauthDialog: some View {
        VStack(spacing: 24) {
            Text("Enter your *current* password")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            SecureField("Current Password", text: $currentPassword)
                .padding()
                .background(Color.black)
                .cornerRadius(8)
                .foregroundColor(.white)
            
            // 🔽 vertically-stacked buttons
            VStack(spacing: 8) {
                Button("Confirm") { finishFlow() }
                    .buttonStyle(CyanButtonStyle(color: accentCyan))
                
                Button("Cancel", role: .cancel) { dismissModal() }
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: 320)
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.9))
        .cornerRadius(16)
        .shadow(radius: 12)
    }
    
    private func dismissModal() {
        currentPassword = ""
        stage = .none
    }
    
    // MARK: – flow
    private func startFlow() {
        guard newPassword.count >= 6 else {
            show("Password must be at least 6 characters."); return
        }
        guard newPassword == confirmPassword else {
            show("Passwords do not match."); return
        }
        stage = .reauth
    }
    
    private func finishFlow() {
        reauthenticate(with: currentPassword) { success in
            guard success, let user = Auth.auth().currentUser else { return }
            user.updatePassword(to: newPassword) { error in
                if let error = error {
                    show("Password update failed:\n\(error.localizedDescription)")
                } else {
                    show("Password updated successfully!", title: "Success")
                }
                dismissModal()
            }
        }
    }
    
    // MARK: – helpers
    private func reauthenticate(with pwd: String,
                                completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser, !pwd.isEmpty else {
            show("Current password cannot be empty."); completion(false); return
        }
        let cred = EmailAuthProvider.credential(withEmail: user.email ?? "", password: pwd)
        user.reauthenticate(with: cred) { _, error in
            if let error = error {
                show("Re-authentication failed:\n\(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    private func show(_ msg: String, title: String = "Error") {
        alertTitle = title
        alertMsg   = msg
        showAlert  = true
    }
}

// ──────────────────────────────────────────────
private struct CyanButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(8)
    }
}

// put this helper inside the same file (above or below ChangeCredentialsView)
private struct PasswordFieldWithToggle: View {
    let title: String                       // placeholder / prompt
    @Binding var text: String               // bound to caller’s State
    @State private var reveal = false       // ⇢ default = hidden
    
    var body: some View {
        HStack {
            Group {
                if reveal {
                    TextField(title, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                } else {
                    SecureField(title, text: $text)
                        .textContentType(.password)
                }
            }
            .foregroundColor(.white)
            
            Button { reveal.toggle() } label: {
                Image(systemName: reveal ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.black)
        .cornerRadius(8)
    }
}

