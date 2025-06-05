//
//  ForgetPasswordView.swift
//  Mind Reset
//  This View handles the situation when a user clicks the forget password link on the login page
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI

@available(iOS 16.0, *)
struct ForgetPasswordView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.presentationMode) var presentationMode

    @State private var email = ""
    @State private var isShowingAlert = false

    // Color definitions
    let backgroundBlack = Color.black
    let neonCyan = Color(red: 0, green: 1, blue: 1)  // #00FFFF
    let fieldBackground = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A

    var body: some View {
        // ───────────────────────────────────────────────────────────────────────────
        // Wrap everything in a tappable area to dismiss the keyboard.
        ZStack {
            backgroundBlack
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Page Title in neonCyan
                Text("Reset Password")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(neonCyan)
                    .multilineTextAlignment(.center)
                    .padding()

                // Email Field with .prompt placeholders
                TextField(
                    "",
                    text: $email,
                    prompt: Text("Enter Your Email").foregroundColor(.white.opacity(0.8))
                )
                .foregroundColor(.white)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(fieldBackground)
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: email) { _ in
                    session.auth_error = nil
                }

                // Error message
                if let errorMessage = session.auth_error {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Reset Password Button with #00FFFF background, black text
                Button(action: {
                    resetPassword()
                }) {
                    Text("Reset Password")
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(neonCyan)
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
        }
        .contentShape(Rectangle())   // Make the entire ZStack respond to taps
        .simultaneousGesture(
            TapGesture().onEnded {
                hideKeyboard()
            }
        )
        // ───────────────────────────────────────────────────────────────────────────
    }

    /*
     Purpose: Resets password after field is verified and checked.
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

    // Validate email
    func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif

struct ForgetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ForgetPasswordView()
                .environmentObject(SessionStore())
        }
    }
}
