//
//  SessionStore.swift
//  Manages User Authentication states using Firebase Authentication
//  Purpose of Class:
//      1. Monitor Authentication State: Keep track of whether a user is logged in or not.
//      2. Performs Authentication Actions: Hanldes User sign-up, sign-in and sign-out processes
//      3. Provides User Data to Views: Share authentication data with SwiftUI views so they can reactively update based on the user's authentication status.
//
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI
import FirebaseAuth

class SessionStore: ObservableObject {
    // Declares a current user and authentication error string.
    @Published var current_user: User?
    @Published var auth_error: String?
    //Firebase optional list handler. Listens when a user authentication changes
    private var handle: AuthStateDidChangeListenerHandle?
    
    // Listens to authentication changes when an instance is created
    init() {
        listen()
    }
    /* All functions associated with this class */
    /*
        Purpose: Sends an email verification after a user successfully signs up
     */
        func sendEmailVerification(completion: @escaping (Bool) -> Void) {
            guard let user = Auth.auth().currentUser else {
                self.auth_error = "Unable to retrieve user information."
                completion(false)
                return
            }

            user.sendEmailVerification { [weak self] error in
                if let error = error as NSError? {
                    self?.auth_error = self?.mapAuthError(error)
                    completion(false)
                } else {
                    print("Email verification sent.")
                    completion(true)
                }
            }
        }
    
    /*
        Purpose: Sets up a listener to monitor authentication state changes. Ensure that app keeps track of when a user logs in or out
    */
    func listen() {
        // Event handle when a user's auth status changes
        handle = Auth.auth().addStateDidChangeListener{
            //Parameters
            [weak self] auth, user in
                self?.current_user = user
        }
    }
    /*
        Purpose: Creates a new account for user with provided email and password.
    */
    func createAccount(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.auth_error = self?.mapAuthError(error)
                    completion(false)
                } else if let user = result?.user {
                    print("Sign Up Success: \(user.email ?? "No Email")")
                    self?.current_user = user
                    completion(true)
                }
            }
        }
    }
    /*
        Purpose: Handles Sign in events
    */
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.auth_error = self?.mapAuthError(error)
                
                } else if let user = result?.user {
                    print("Sign In Success: \(user.email ?? "No Email")")
                    self?.current_user = user
                }
            }
        }
    }
    /*
        Purpose: Handles Sign out events
    */
    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                print("Sign Out Success")
                self.current_user = nil
            }
        } catch let signOutError as NSError {
            DispatchQueue.main.async {
                print("Sign Out Error: \(signOutError.localizedDescription)")
                self.auth_error = "Failed to sign out. Please try again."
            }
        }
    }
    /*
        Purpose: Handles Reset Password events
    */
    func resetPassword(email: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.auth_error = self?.mapAuthError(error)
                    completion(false)
                } else {
                    print("Password reset email sent.")
                    completion(true)
                }
            }
        }
    }
    // Map Firebase AuthErrorCode to custom messages
    private func mapAuthError(_ error: NSError) -> String {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }
    
        switch errorCode {
        case .invalidEmail:
            return "The email address is badly formatted."
        case .emailAlreadyInUse:
            return "The email address is already in use by another account."
        case .weakPassword:
            return "The password is too weak. Please choose a stronger password."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .userNotFound:
            return "No account found with this email. Please sign up."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .invalidCredential:
                return "The email address or password you entered is incorrect. Please double-check your credentials and try again."
        default:
            return error.localizedDescription
        }
    }
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
