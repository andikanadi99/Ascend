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
    @State private var showConfirmation: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    
    // Customize the accent color to match your dark/cyan aesthetic.
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Text("Delete Account")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(accentCyan)
                        
                        Text("Deleting your account is permanent and cannot be undone. All your data will be lost. Are you sure you want to continue?")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button(action: {
                            showConfirmation = true
                        }) {
                            Text("Permanently Delete")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        .alert(isPresented: $showConfirmation) {
                            Alert(
                                title: Text("Confirm Delete"),
                                message: Text("Are you sure you want to delete your account? This action is permanent and cannot be undone."),
                                primaryButton: .destructive(Text("Delete")) {
                                    deleteAccount()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                        .alert(isPresented: $showAlert) {
                            Alert(title: Text("Delete Account"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            alertMessage = "No authenticated user found."
            showAlert = true
            return
        }
        
        // Optionally, delete the user document from Firestore.
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).delete { error in
            if let error = error {
                print("Error deleting user doc: \(error.localizedDescription)")
            } else {
                print("User doc deleted.")
            }
        }
        
        // Delete the user's account.
        user.delete { error in
            if let error = error {
                alertMessage = "Failed to delete account: \(error.localizedDescription)"
                showAlert = true
            } else {
                alertMessage = "Your account has been deleted permanently."
                showAlert = true
                // Sign out the user to update the session.
                session.signOut()
            }
        }
    }
}

struct DeleteAccountView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteAccountView()
            .environmentObject(SessionStore())
    }
}
