//
//  LoginView.swift
//  Mind Reset
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
            backgroundBlack
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppFullWord")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .padding(.top, 10)

                // Email field
                TextField(
                    "",
                    text: $email,
                    prompt: Text("Enter Your Email")
                        .foregroundColor(.white.opacity(0.8))
                )
                .foregroundColor(.white)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(fieldBackground)
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: email) { _ in session.auth_error = nil }

                // Password field with show/hide
                ZStack(alignment: .trailing) {
                    Group {
                        if showPassword {
                            TextField(
                                "",
                                text: $password,
                                prompt: Text("Enter Your Password")
                                    .foregroundColor(.white.opacity(0.8))
                            )
                        } else {
                            SecureField(
                                "",
                                text: $password,
                                prompt: Text("Enter Your Password")
                                    .foregroundColor(.white.opacity(0.8))
                            )
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(fieldBackground)
                    .cornerRadius(8)
                    .onChange(of: password) { _ in session.auth_error = nil }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 15)
                    }
                }
                .padding(.horizontal)

                // Only show errors that are *not* the “User data not found” one
                if let errorMessage = session.auth_error,
                   errorMessage != "User data not found." {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Button(action: login) {
                    Text("Login")
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(neonCyan)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

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
        .onTapGesture { hideLoginKeyboard() }
        .onAppear {
            // clear out any leftover “User data not found” from a deleted account
            session.auth_error = nil
        }
    }

    // MARK: - Helper Methods

    func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}"
        return NSPredicate(format:"SELF MATCHES %@", emailRegEx).evaluate(with: email)
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
    func hideLoginKeyboard() { }
}
#endif

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
                .environmentObject(SessionStore())
        }
        .preferredColorScheme(.dark)
    }
}
