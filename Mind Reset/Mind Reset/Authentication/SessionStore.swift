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
import FirebaseFirestore

class SessionStore: ObservableObject {
    // Declares a current user and authentication error string.
    @Published var current_user: User?
    @Published var auth_error: String?
    //Firebase optional list handler. Listens when a user authentication changes
    private var handle: AuthStateDidChangeListenerHandle?
    // Firestore reference
    private var db = Firestore.firestore()
    
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
        Purpose: Updates the user class to update their own meditation time
    */
    func awardMeditationTime(userId: String, additionalMinutes: Int) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, _) -> Any? in
            
            // We do a 'do-catch' block so we do NOT make this closure throwing.
            do {
                let snapshot = try transaction.getDocument(userRef)
                let currentTime = snapshot.data()?["meditationTime"] as? Int ?? 0
                let newTime = currentTime + additionalMinutes
                
                transaction.updateData(["meditationTime": newTime], forDocument: userRef)
                
            } catch {
                // If there's any error calling 'transaction.getDocument', we handle it here
                print("Transaction error awarding meditation time: \(error.localizedDescription)")
                // Return nil to abort the transaction
                return nil
            }
            
            // If everything succeeds, return nil to indicate success
            return nil
            
        }) { (_, error) in
            // In the completion, the 'error' param will be non-nil if the transaction failed.
            if let error = error {
                print("Error updating meditation time: \(error.localizedDescription)")
            } else {
                print("Successfully added \(additionalMinutes) minutes to user's meditationTime.")
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
                    // After successful sign-up, create or verify user document
                    self?.createOrVerifyUserDocument(for: user, email: email) {
                        completion(true)
                    }
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
                    // After sign-in, ensure the user doc exists
                    self?.createOrVerifyUserDocument(for: user, email: email) { }
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
    /*
        Purpose: Create or Verify the user document in Firestore
     */
    private func createOrVerifyUserDocument(for user: User, email: String, completion: @escaping () -> Void) {
        let userRef = db.collection("users").document(user.uid)
        //Creates the user data in the collection in Firebase
        userRef.getDocument { [weak self] (document, error) in
            //Error Check
            if let error = error {
                print("Error checking user doc: \(error)")
                completion()
                return
            }
            
            //Creating of document
            if document?.exists == true{
                completion()
            }
            else{
                // Create a new user doc with default values
                let userData: [String: Any] = [
                    "email": email,
                    "displayName": "", // Can be empty for now or prompt user to set it later
                    "totalPoints": 0,
                    "createdAt": FieldValue.serverTimestamp(),
                     "meditationTime": 0,
                     "deepWorkTime": 0,
                     "preferences": [String: Any](),
                    "defaultHabitsCreated": false
                ]
                //Set reference of created user with the base data
                userRef.setData(userData) { error in
                    if let error = error {
                        print("Error creating user doc: \(error)")
                    } else {
                        print("User doc created successfully.")
                    }
                    completion()
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
