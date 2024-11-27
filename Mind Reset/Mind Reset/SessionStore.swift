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
    func createAccount(email:String, password:String){
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    self?.auth_error = error.localizedDescription
                } else if let user = result?.user {
                    self?.current_user = user
                }
            }
    }
    /*
        Purpose: Handles Sign in events
    */
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                print("helooooooo")
                self?.auth_error = error.localizedDescription
            } else if let user = result?.user {
                print(user)
                self?.current_user = user
            }
        }
    }
    /*
        Purpose: Handles Sign out events
    */
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.current_user = nil
        } catch let signOutError as NSError {
            self.auth_error = signOutError.localizedDescription
        }
    }
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
