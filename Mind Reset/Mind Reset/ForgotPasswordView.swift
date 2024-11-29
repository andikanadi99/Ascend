//
//  ForgetPasswordView.swift
//  Mind Reset
//  This View handles the situation when a user clicks the forget password link on the login pahe
//  Objectives:
//      1.User Registration: Allow users to create a new account using their email and password.
//      2.Handle input validation.
//      3.Error Handling: Display meaningful error messages when registration fails.
//      4.Navigation: Provide a way for users to navigate to the LoginView if they already have an account.
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI

struct ForgetPasswordView: View {
    @EnvironmentObject var session: SessionStore // Access SessionStore
    @Environment(\.presentationMode) var presentationMode

    @State private var email = ""
    @State private var isShowingAlert = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Page Title
            Text("Reset Password")
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding()
            
            //Email Field
            TextField("Enter Your Email", text:$email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: email, initial: false) { oldValue, newValue in
                    session.auth_error = nil
                }
            // Error Message
            if let errorMessage = session.auth_error {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            // Reset Password Button
            Button(action: {
                resetPassword()
            }) {
                Text("Reset Password")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
                .alert(isPresented: $isShowingAlert) {
                    Alert(
                        title: Text("Password Reset Email Sent"),
                        message: Text("An email with password reset instructions has been sent to \(email)."),
                        dismissButton: .default(Text("OK")) {
                            // Dismiss the view
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                }

                Spacer()

        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .onTapGesture {
            hideKeyboard()
        }
    }
    /*
        Purpose: Restes password after all fields are verified and checked.
    */
    func resetPassword() {
        guard !email.isEmpty else {
            session.auth_error = "Please enter your email address."
            return
        }

        guard isEmailValid(email) else {
            session.auth_error = "Please enter a valid email address."
            return
        }

        session.resetPassword(email: email) { success in
            if success {
                isShowingAlert = true
            }
        }
    }
    //Function to check if email is valid
    func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

}

// Hide Keyboard Extension
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct ForgetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgetPasswordView()
            .environmentObject(SessionStore())
    }
}
