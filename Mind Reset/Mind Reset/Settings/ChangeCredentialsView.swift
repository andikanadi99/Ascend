//
//  ChangeCredentialsView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/2/25.
//


import SwiftUI
import FirebaseAuth

struct ChangeCredentialsView: View {
    @EnvironmentObject var session: SessionStore
    // New email and password fields
    @State private var newEmail: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    // Alert states and messages
    @State private var showEmailAlert: Bool = false
    @State private var emailAlertMessage: String = ""
    @State private var showPasswordAlert: Bool = false
    @State private var passwordAlertMessage: String = ""
    
    // Customize your accent color here
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Change Email")
                            .foregroundColor(accentCyan)) {
                    TextField("New Email", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black)
                        .cornerRadius(8)
                    
                    Button(action: updateEmail) {
                        Text("Update Email")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accentCyan)
                            .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Change Password")
                            .foregroundColor(accentCyan)) {
                    SecureField("New Password", text: $newPassword)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black)
                        .cornerRadius(8)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black)
                        .cornerRadius(8)
                    
                    Button(action: updatePassword) {
                        Text("Update Password")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accentCyan)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Change Credentials")
            .background(Color.black.ignoresSafeArea())
            .foregroundColor(.white)
            .alert(isPresented: $showEmailAlert) {
                Alert(title: Text("Email Update"), message: Text(emailAlertMessage), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showPasswordAlert) {
                Alert(title: Text("Password Update"), message: Text(passwordAlertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Update Email Function
    private func updateEmail() {
        guard !newEmail.trimmingCharacters(in: .whitespaces).isEmpty else {
            emailAlertMessage = "Please enter a valid email."
            showEmailAlert = true
            return
        }
        
        Auth.auth().currentUser?.updateEmail(to: newEmail) { error in
            if let error = error {
                emailAlertMessage = "Failed to update email: \(error.localizedDescription)"
            } else {
                emailAlertMessage = "Email updated successfully!"
            }
            showEmailAlert = true
        }
    }
    
    // MARK: - Update Password Function
    private func updatePassword() {
        guard !newPassword.isEmpty else {
            passwordAlertMessage = "Please enter a new password."
            showPasswordAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            passwordAlertMessage = "Passwords do not match."
            showPasswordAlert = true
            return
        }
        
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            if let error = error {
                passwordAlertMessage = "Failed to update password: \(error.localizedDescription)"
            } else {
                passwordAlertMessage = "Password updated successfully!"
            }
            showPasswordAlert = true
        }
    }
}

struct ChangeCredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeCredentialsView()
            .environmentObject(SessionStore())
    }
}
