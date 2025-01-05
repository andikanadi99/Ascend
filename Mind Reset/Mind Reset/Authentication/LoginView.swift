//
//  LoginView.swift
//  This View handles the Login UI component of Mind Reset
//  Objectives: View that allow user to:
//      1.Enter their email and password.
//      2.Handle input validation.
//      3.Authenticate using the SessionStore class.
//      4.Display error messages when login fails.
//      5.Navigate to the SignUpView if the user doesn't have an account.
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI

@available(iOS 16.0, *)
struct LoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    // Color definitions
    let backgroundBlack = Color.black
    let neonCyan = Color(red: 0, green: 1, blue: 1)  // #00FFFF
    let fieldBackground = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A

    var body: some View {
        ZStack {
            // Main black background
            backgroundBlack
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Title in neonCyan
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(neonCyan)

                // 1) Email Field with .prompt placeholders (iOS 16+)
                TextField(
                    "",
                    text: $email,
                    prompt: Text("Enter Your Email")
                        .foregroundColor(.white.opacity(0.8))
                )
                .foregroundColor(.white.opacity(0.8))
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(fieldBackground)
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: email, initial: false) { _, _ in
                    session.auth_error = nil
                }

                // 2) Password Field with show/hide icon *inside*
                ZStack(alignment: .trailing) {
                    if showPassword {
                        TextField(
                            "",
                            text: $password,
                            prompt: Text("Enter Your Password")
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .foregroundColor(.white)
                        .padding()
                        .background(fieldBackground)
                        .cornerRadius(8)
                        .onChange(of: password, initial: false) { _, _ in
                            session.auth_error = nil
                        }
                    } else {
                        SecureField(
                            "",
                            text: $password,
                            prompt: Text("Enter Your Password")
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .foregroundColor(.white)
                        .padding()
                        .background(fieldBackground)
                        .cornerRadius(8)
                        .onChange(of: password, initial: false) { _, _ in
                            session.auth_error = nil
                        }
                    }

                    // Eye icon inside the same field area
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 15)
                    }
                }
                .padding(.horizontal)

                // Error message
                if let errorMessage = session.auth_error {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Login button: #00FFFF background, black text
                Button(action: {
                    login()
                }) {
                    Text("Login")
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(neonCyan)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                // Links in neonCyan
                NavigationLink(destination: ForgetPasswordView()) {
                    Text("Forget Password?")
                        .foregroundColor(neonCyan)
                }

                NavigationLink(destination: SignUpView()) {
                    Text("Don't have an account? Please sign up")
                        .foregroundColor(neonCyan)
                }
                .offset(y: -10)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onTapGesture {
            hideLoginKeyboard()
        }
    }

    // MARK: - Helper Methods

    func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            session.auth_error = "Please enter both email and password."
            return
        }
        guard isEmailValid(email) else {
            session.auth_error = "Please enter a valid email address."
            return
        }
        session.signIn(email: email, password: password)
    }
}

#if canImport(UIKit)
import UIKit

extension View {
    func hideLoginKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#else
extension View {
    func hideLoginKeyboard() {
        // No-op for environments where UIKit is not available (e.g., previews)
    }
}
#endif

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
                .environmentObject(SessionStore())
                .environmentObject(HabitViewModel())
        }
        .preferredColorScheme(.dark)
    }
}
