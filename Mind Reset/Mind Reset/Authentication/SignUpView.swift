//
//  SignUpView.swift
//  Mind Reset.
//
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI

@available(iOS 16.0, *)
struct SignUpView: View {
    @EnvironmentObject var session: SessionStore
    @State private var isSigningUp = false

    // ───────── UI state
    @State private var email             = ""
    @State private var password          = ""
    @State private var confirmPassword   = ""
    @State private var showPwd           = false
    @State private var showConfirmPwd    = false

    // ───────── Colours
    private let backgroundBlack = Color.black
    private let neonCyan        = Color(red: 0, green: 1, blue: 1)
    private let fieldBG         = Color(red: 0.102, green: 0.102, blue: 0.102)

    var body: some View {
        // ───────────────────────────────────────────────────────────────────────────
        // Wrap everything in a tappable area to dismiss the keyboard.
        ZStack {
            backgroundBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // ── Title
                    Text("Create Account")
                        .font(.largeTitle).fontWeight(.bold)
                        .foregroundColor(neonCyan)
                        .padding(.top, 40)

                    // ── Email
                    TextField("", text: $email,
                              prompt: Text("Enter Your Email")
                                .foregroundColor(.white.opacity(0.8)))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(fieldBG)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onChange(of: email) { _ in session.auth_error = nil }

                    // ── Password
                    passwordField($password, placeholder: "Enter Your Password",
                                  show: $showPwd)
                        .onChange(of: password) { _ in session.auth_error = nil }

                    // ── Confirm
                    passwordField($confirmPassword,
                                  placeholder: "Confirm Your Password",
                                  show: $showConfirmPwd)
                        .onChange(of: confirmPassword) { _ in session.auth_error = nil }

                    // ── Error
                    if let err = session.auth_error {
                        Text(err)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // ── Sign-up
                    Button(action: signUp) {
                        if isSigningUp {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Sign Up")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(neonCyan)
                    .cornerRadius(8)
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .disabled(isSigningUp)    // prevent double-taps

                    NavigationLink("Already have an account? Log In",
                                   destination: LoginView())
                        .foregroundColor(neonCyan)
                        .padding()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .contentShape(Rectangle())   // Make the entire ZStack respond to taps
        // ───────────────────────────────────────────────────────────────────────────
    }

    // MARK: – helpers
    @ViewBuilder
    private func passwordField(_ binding: Binding<String>,
                               placeholder: String,
                               show: Binding<Bool>) -> some View {
        ZStack(alignment: .trailing) {
            Group {
                if show.wrappedValue {
                    TextField("", text: binding,
                              prompt: Text(placeholder)
                                .foregroundColor(.white.opacity(0.8)))
                } else {
                    SecureField("", text: binding,
                                prompt: Text(placeholder)
                                  .foregroundColor(.white.opacity(0.8)))
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(fieldBG)
            .cornerRadius(8)

            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.gray)
                    .padding(.trailing, 15)
            }
        }
        .padding(.horizontal)
    }

    private func signUp() {
        // basic validation…
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            session.auth_error = "Please fill in all fields."
            return
        }
        guard password == confirmPassword else {
            session.auth_error = "Passwords do not match."
            return
        }
        guard password.count >= 6 else {
            session.auth_error = "Passwords must be at least 6 characters."
            return
        }

        isSigningUp = true
        session.createAccount(email: email, password: password) { success in
            isSigningUp = false
            if !success {
                // auth_error already set by SessionStore
            }
            // on success, SessionStore will update current_user → view navigates away
        }
    }
}

#if canImport(UIKit)
extension View {
    // Leave the global hideKeyboard() in whichever file you already defined it,
    // but do NOT redefine it here.
}
#endif
