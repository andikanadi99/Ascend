//
//  SignUpView.swift
//  Mind Reset
//  This View handles the Login UI component of Mind Reset
//  Objectives:
//      1.User Registration: Allow users to create a new account using their email and password.
//      2.Handle input validation.
//      3.Error Handling: Display meaningful error messages when registration fails.
//      4.Navigation: Provide a way for users to navigate to the LoginView if they already have an account.
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI

@available(iOS 16.0, *)
struct SignUpView: View {
    //Access the shared instance of SessionStore
    @EnvironmentObject var session: SessionStore
    
    //Variables for the file
    @State private var email = ""
    @State private var password = ""
    @State private var confirm_password = ""
    @State private var show_password = false
    @State private var show_confirm_password = false
    @State private var isShowingAlert = false
    
    // Color definitions
    let backgroundBlack = Color.black
    let neonCyan = Color(red: 0, green: 1, blue: 1)          // #00FFFF
    let fieldBackground = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A

    var body: some View {
        ZStack {
            // Main black background
            backgroundBlack
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Title section
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(neonCyan)
                        .padding(.top, 40)
                    
                    // Email Field using .prompt placeholders
                    TextField(
                        "",
                        text: $email,
                        prompt: Text("Enter Your Email").foregroundColor(.white.opacity(0.8))
                    )
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(fieldBackground)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: email, initial: false) { _, _ in
                        session.auth_error = nil
                    }
                    
                    // Password Field
                    ZStack(alignment: .trailing) {
                        if show_password {
                            TextField(
                                "",
                                text: $password,
                                prompt: Text("Enter Your Password").foregroundColor(.white.opacity(0.8))
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
                                prompt: Text("Enter Your Password").foregroundColor(.white.opacity(0.8))
                            )
                            .foregroundColor(.white)
                            .padding()
                            .background(fieldBackground)
                            .cornerRadius(8)
                            .onChange(of: password, initial: false) { _, _ in
                                session.auth_error = nil
                            }
                        }
                        
                        // Eye icon
                        Button(action: {
                            show_password.toggle()
                        }) {
                            Image(systemName: show_password ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 15)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Confirm Password Field
                    ZStack(alignment: .trailing) {
                        if show_confirm_password {
                            TextField(
                                "",
                                text: $confirm_password,
                                prompt: Text("Confirm Your Password").foregroundColor(.white.opacity(0.8))
                            )
                            .foregroundColor(.white)
                            .padding()
                            .background(fieldBackground)
                            .cornerRadius(8)
                            .onChange(of: confirm_password, initial: false) { _, _ in
                                session.auth_error = nil
                            }
                        } else {
                            SecureField(
                                "",
                                text: $confirm_password,
                                prompt: Text("Confirm Your Password").foregroundColor(.white.opacity(0.8))
                            )
                            .foregroundColor(.white)
                            .padding()
                            .background(fieldBackground)
                            .cornerRadius(8)
                            .onChange(of: confirm_password, initial: false) { _, _ in
                                session.auth_error = nil
                            }
                        }
                        
                        // Eye icon
                        Button(action: {
                            show_confirm_password.toggle()
                        }) {
                            Image(systemName: show_confirm_password ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 15)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error message conditional pop-up
                    if let error_message = session.auth_error {
                        Text(error_message)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Sign Up Button (using #00FFFF background, black text)
                    Button(action: {
                        signUp()
                    }) {
                        Text("Sign Up")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(neonCyan)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Navigation to LoginView if account already exist
                    NavigationLink("Already have an account? Log In", destination: LoginView())
                        .foregroundColor(neonCyan)
                        .padding()
                }
                .padding()
                .onTapGesture {
                    hideSignUpKeyboard()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Functions associated with page
    
    func isEmailValid(_email: String) -> Bool {
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+(?:com|org|net|edu|gov|mil|int)"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    func isPasswordValid(_password: String) -> Bool {
        return password.count >= 6
    }
    
    func signUp() {
        guard !email.isEmpty, !password.isEmpty, !confirm_password.isEmpty else {
            session.auth_error = "Please fill in all fields."
            return
        }
        guard password == confirm_password else {
            session.auth_error = "Passwords do not match."
            return
        }
        guard isEmailValid(_email: email) else {
            session.auth_error = "Please enter a valid email address."
            return
        }
        guard isPasswordValid(_password: password) else {
            session.auth_error = "Passwords must be at least 6 characters."
            return
        }
        
        session.createAccount(email: email, password: password) { success in
            if success {
                isShowingAlert = true
            } else {
                // handle error
            }
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideSignUpKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SignUpView()
                .environmentObject(SessionStore())
        }
    }
}
