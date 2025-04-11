//
//  SessionStore.swift
//  Mind Reset
//
//  Manages User Authentication states using Firebase Authentication
//  Purpose of Class:
//      1. Monitor Authentication State: Keep track of whether a user is logged in or not.
//      2. Perform Authentication Actions: Handles user sign-up, sign-in, and sign-out processes
//      3. Provide User Data to Views: Share authentication data with SwiftUI views so they can reactively update
//         based on the user's authentication status.
//
//  Created by Andika Yudhatrisna on 11/22/24.
//


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class SessionStore: ObservableObject {
    // Holds currently authenticated Firebase user
    @Published var current_user: User?
    // Holds the user's Firestore data
    @Published var userModel: UserModel?
    // Potentially store error messages
    @Published var auth_error: String?
    
    // Firestore reference
    private var db = Firestore.firestore()
    // For listening to auth state changes
    private var handle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Init
    init() {
        listen()
    }
    
    // MARK: - Listen to Auth State
    /// Sets up a listener to monitor authentication state changes (login/logout).
    func listen() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.current_user = user
            if let user = user {
                self?.fetchUserModel(userId: user.uid)
            } else {
                self?.userModel = nil
            }
        }
    }
    
    // MARK: - Fetch UserModel
    /// Fetches the user's Firestore document and decodes it into UserModel.
    private func fetchUserModel(userId: String) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching user document: \(error)")
                DispatchQueue.main.async {
                    self?.auth_error = "Failed to fetch user data."
                }
                return
            }
            
            // If no document exists, only set an error if the user is still logged in.
            guard let document = document, document.exists else {
                print("User document does not exist.")
                DispatchQueue.main.async {
                    // Only set the error if there is a currently authenticated user.
                    self?.auth_error = Auth.auth().currentUser != nil ? "User data not found." : nil
                }
                return
            }
            
            do {
                let userData = try document.data(as: UserModel.self)
                DispatchQueue.main.async {
                    self?.userModel = userData
                }
            } catch {
                print("Error decoding user data: \(error)")
                DispatchQueue.main.async {
                    self?.auth_error = "Failed to decode user data."
                }
            }
        }
    }

    
    // MARK: - Create Account
    /// Creates a new account with email and password in Firebase Auth.
    func createAccount(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.auth_error = self?.mapAuthError(error)
                    completion(false)
                } else if let user = result?.user {
                    print("Sign Up Success: \(user.email ?? "No Email")")
                    self?.current_user = user
                    // Create or verify user doc in Firestore
                    self?.createOrVerifyUserDocument(for: user, email: email) {
                        // After creating/verifying, fetch the user model
                        self?.fetchUserModel(userId: user.uid)
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Sign In
    /// Signs in a user with email and password.
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.auth_error = self?.mapAuthError(error)
                } else if let user = result?.user {
                    print("Sign In Success: \(user.email ?? "No Email")")
                    self?.current_user = user
                    // Ensure user doc exists and fetch user model
                    self?.createOrVerifyUserDocument(for: user, email: email) {
                        self?.fetchUserModel(userId: user.uid)
                    }
                }
            }
        }
    }
    
    // MARK: - Sign Out
    /// Signs out the current user.
    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                print("Sign Out Success")
                self.current_user = nil
                self.userModel = nil
            }
        } catch let signOutError as NSError {
            DispatchQueue.main.async {
                print("Sign Out Error: \(signOutError.localizedDescription)")
                self.auth_error = "Failed to sign out. Please try again."
            }
        }
    }
    
    // MARK: - Reset Password
    /// Sends a password reset email.
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
    
    // MARK: - Email Verification (optional)
    /// Sends an email verification to the current user.
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
    
    // MARK: - Create or Verify User Document
    /// Creates a user doc if one doesn’t exist yet in Firestore at `users/{uid}`.
    private func createOrVerifyUserDocument(for user: User, email: String, completion: @escaping () -> Void) {
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error checking user doc: \(error)")
                DispatchQueue.main.async {
                    self?.auth_error = "Failed to verify user data."
                }
                completion()
                return
            }
            // If it exists, do nothing
            if document?.exists == true {
                completion()
            } else {
                // Else create a new user doc with default data
                let userData: [String: Any] = [
                    "email": email,
                    "displayName": "",
                    "totalPoints": 0,
                    "createdAt": FieldValue.serverTimestamp(),
                    "meditationTime": 0,
                    "deepWorkTime": 0,
                    "defaultHabitsCreated": false
                ]
                userRef.setData(userData) { error in
                    if let error = error {
                        print("Error creating user doc: \(error)")
                        DispatchQueue.main.async {
                            self?.auth_error = "Failed to create user data."
                        }
                    } else {
                        print("User doc created successfully.")
                    }
                    completion()
                }
            }
        }
    }
    
    // MARK: - Example: Award Meditation Time
    /// Adds to meditationTime in the user’s doc. Example of a Firestore transaction.
    func awardMeditationTime(userId: String, additionalMinutes: Int) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snapshot = try transaction.getDocument(userRef)
                let currentTime = snapshot.data()?["meditationTime"] as? Int ?? 0
                let newTime = currentTime + additionalMinutes
                transaction.updateData(["meditationTime": newTime], forDocument: userRef)
            } catch {
                print("Transaction error awarding meditation time: \(error.localizedDescription)")
                return nil
            }
            return nil
        }) { (_, error) in
            if let error = error {
                print("Error updating meditation time: \(error.localizedDescription)")
            } else {
                print("Successfully added \(additionalMinutes) minutes to user's meditationTime.")
            }
        }
    }
    
    // MARK: - Error Mapping
    /// Maps a Firebase Auth error code to a user-friendly message.
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
        // Combine wrongPassword and invalidCredential (if applicable) for a unified message.
        case .wrongPassword, .invalidCredential:
            return "Wrong email or password."
        case .userNotFound:
            return "No account found with this email. Please sign up."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        default:
            return error.localizedDescription
        }
    }

    
    // MARK: - Cleanup
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}


