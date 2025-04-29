//
//  DeleteAccountView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/2/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DeleteAccountView: View {
    @EnvironmentObject var session: SessionStore
    
    // MARK: UI state
    @State private var showConfirmation = false          // first “Are you sure?” alert
    @State private var showReauthModal   = false          // custom password prompt
    @State private var currentPassword   = ""             // user-entered current password
    @State private var showResultAlert   = false
    @State private var resultTitle       = ""
    @State private var resultMessage     = ""
    
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        ZStack {
            // Main background
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Delete Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(accentCyan)
                    
                    Text("Deleting your account is permanent and cannot be undone. All your data will be lost. Are you sure you want to continue?")
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Permanently Delete") {
                        showConfirmation = true
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .shadow(radius: 10)
                
                Spacer()
            }
            .padding()
            
            // MARK: – Re-auth Modal
            if showReauthModal {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { /* prevent background taps */ }
                
                VStack(spacing: 16) {
                    Text("Enter your current password to confirm")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    
                    SecureField("Password", text: $currentPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    
                    HStack {
                        Button("Cancel") {
                            currentPassword = ""
                            showReauthModal = false
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Confirm") {
                            reauthenticateAndDelete()
                        }
                        .foregroundColor(.black)
                        .padding()
                        .background(accentCyan)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .frame(maxWidth: 300)
                .background(Color.black)
                .cornerRadius(12)
                .shadow(radius: 12)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        // First confirmation
        .alert("Confirm Delete",
               isPresented: $showConfirmation,
               actions: {
                   Button("Delete", role: .destructive) {
                       showReauthModal = true
                   }
                   Button("Cancel", role: .cancel) { }
               },
               message: {
                   Text("This action is permanent and cannot be undone.")
               })
        // Final result
        .alert(resultTitle,
               isPresented: $showResultAlert,
               actions: {
                   Button("OK", role: .cancel) {
                       // No extra action needed; if deletion was successful,
                       // session.signOut() has already been called.
                   }
               },
               message: {
                   Text(resultMessage)
               })
    }
    
    // MARK: – Helpers
    
    private func reauthenticateAndDelete() {
        guard let user = Auth.auth().currentUser,
              !currentPassword.isEmpty else {
            resultTitle   = "Error"
            resultMessage = "Password cannot be empty."
            showResultAlert = true
            return
        }
        
        // Build credential and re-authenticate
        let credential = EmailAuthProvider.credential(
            withEmail: user.email ?? "",
            password: currentPassword
        )
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                resultTitle   = "Re-authentication Failed"
                resultMessage = error.localizedDescription
                showResultAlert = true
                // keep the modal open for retry
            } else {
                // Now actually delete
                deleteUserDataAndAccount(user: user)
            }
        }
    }
    
    private func deleteUserDataAndAccount(user: FirebaseAuth.User) {
        let uid = user.uid
        let db  = Firestore.firestore()
        
        // Remove Firestore doc (best effort)
        db.collection("users").document(uid).delete { _ in
            // ignore errors here
        }
        
        // Delete auth user
        user.delete { error in
            if let error = error {
                resultTitle   = "Deletion Failed"
                resultMessage = error.localizedDescription
            } else {
                // success: sign out and inform
                session.signOut()
                resultTitle   = "Account Deleted"
                resultMessage = "Your account has been permanently removed."
            }
            // dismiss modal & show result
            showReauthModal  = false
            currentPassword  = ""
            showResultAlert  = true
        }
    }
}

struct DeleteAccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeleteAccountView()
                .environmentObject(SessionStore())
        }
    }
}
