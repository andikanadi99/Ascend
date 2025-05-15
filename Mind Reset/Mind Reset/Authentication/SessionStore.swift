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
import FirebaseCore
import GoogleSignIn
import GoogleSignInSwift

class SessionStore: ObservableObject {
    // MARK: - Published State
    @Published var current_user: User?          // Firebase Auth user
    @Published var userModel: UserModel?        // Firestore user document
    @Published var auth_error: String?          // Any auth-related error message

    @Published var defaultWakeTime: Date?
    @Published var defaultSleepTime: Date?

    // MARK: - Private Properties
    private var db: Firestore = {
        let f = Firestore.firestore()
        var s = f.settings
        s.isPersistenceEnabled = true
        f.settings = s
        return f
    }()
    private var userDocListener: ListenerRegistration?
    private var handle: AuthStateDidChangeListenerHandle?
    private var isUpdatingSchedules = false

    // MARK: - Init
    init() {
        // Load default wake/sleep times
        let wake = UserDefaults.standard.object(forKey: "DefaultWakeUpTime") as? Date
            ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let sleep = UserDefaults.standard.object(forKey: "DefaultSleepTime") as? Date
            ?? Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        self.defaultWakeTime = wake
        self.defaultSleepTime = sleep

        listen()
    }

    // MARK: - Default Times
    func setDefaultTimes(wake: Date, sleep: Date) {
        defaultWakeTime = wake
        defaultSleepTime = sleep
        UserDefaults.standard.set(wake, forKey: "DefaultWakeUpTime")
        UserDefaults.standard.set(sleep, forKey: "DefaultSleepTime")
        updateFutureDaySchedules(wake: wake, sleep: sleep)
    }

    private func updateFutureDaySchedules(wake: Date, sleep: Date) {
        guard !isUpdatingSchedules else { return }
        isUpdatingSchedules = true
        defer { isUpdatingSchedules = false }

        guard let uid = current_user?.uid else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let col = db.collection("users")
                    .document(uid)
                    .collection("daySchedules")
        col.whereField("date", isGreaterThanOrEqualTo: Timestamp(date: today))
           .getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            let batch = self.db.batch()
            for doc in docs {
                batch.updateData([
                    "wakeUpTime": wake,
                    "sleepTime": sleep
                ], forDocument: doc.reference)
            }
            batch.commit()
        }
    }

    // MARK: - Auth State Listener
    func listen() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.current_user = user
            self.userModel = nil
            self.userDocListener?.remove()

            guard let uid = user?.uid else { return }
            self.userDocListener = self.db
                .collection("users")
                .document(uid)
                .addSnapshotListener { snap, _ in
                    if let model = try? snap?.data(as: UserModel.self) {
                        self.userModel = model
                    }
                }
        }
    }

    // MARK: - Google Sign-In 🔹 Google Sign-in ADDITIONS
    func startGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            auth_error = "Missing Google clientID."
            return
        }
        guard let rootVC = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController
        else {
            auth_error = "Could not find root view controller."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async { self?.auth_error = error.localizedDescription }
                return
            }
            guard
                let idToken = result?.user.idToken?.tokenString,
                let accessToken = result?.user.accessToken.tokenString
            else {
                DispatchQueue.main.async { self?.auth_error = "Google Sign-in: missing tokens." }
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: accessToken)
            let fallbackEmail = result?.user.profile?.email ?? ""
            self?.firebaseLogin(with: credential, fallbackEmail: fallbackEmail)
        }
    }

    // MARK: - Shared Firebase Hand-off
    func firebaseLogin(with credential: AuthCredential, fallbackEmail: String) {
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = error as NSError? {
                    self.auth_error = self.mapAuthError(err)
                    return
                }
                guard let user = result?.user else {
                    self.auth_error = "Login failed: no user."
                    return
                }
                self.current_user = user
                let email = user.email ?? fallbackEmail
                self.createOrVerifyUserDocument(for: user, email: email) {
                    self.fetchUserModel(userId: user.uid)
                }
            }
        }
    }

    // MARK: - Apple Sign-In now routes through same flow
    func signInWithApple(credential: AuthCredential) {
        firebaseLogin(with: credential, fallbackEmail: "")
    }
    
    /// Signs in (or up) a user with a Google OAuth credential
    func signInWithGoogle(credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error as NSError? {
                    self.auth_error = self.mapAuthError(error)
                    return
                }
                guard let user = result?.user else {
                    self.auth_error = "Google sign-in: couldn't retrieve user."
                    return
                }
                self.current_user = user
                // Use the Firebase user.email fallback if Google doesn’t supply it.
                let email = user.email ?? ""
                self.createOrVerifyUserDocument(for: user, email: email) {
                    self.fetchUserModel(userId: user.uid)
                }
            }
        }
    }


    // MARK: - Email/Password
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = error as NSError? {
                    self.auth_error = self.mapAuthError(err)
                } else if let user = result?.user {
                    self.current_user = user
                    self.createOrVerifyUserDocument(for: user, email: email) {
                        self.fetchUserModel(userId: user.uid)
                    }
                }
            }
        }
    }

    func createAccount(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] res, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = error as NSError? {
                    self.auth_error = self.mapAuthError(err)
                    completion(false)
                } else if let user = res?.user {
                    self.current_user = user
                    self.createOrVerifyUserDocument(for: user, email: email) {
                        self.fetchUserModel(userId: user.uid)
                        completion(true)
                    }
                }
            }
        }
    }

    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.current_user = nil
                self.userModel = nil
            }
        } catch let err as NSError {
            DispatchQueue.main.async {
                self.auth_error = "Sign out failed: \(err.localizedDescription)"
            }
        }
    }

    // MARK: - Password Reset
    func resetPassword(email: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                if let err = error as NSError? {
                    self?.auth_error = self?.mapAuthError(err)
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    // MARK: - Email Verification
    func sendEmailVerification(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            self.auth_error = "No user to verify."
            completion(false)
            return
        }
        user.sendEmailVerification { [weak self] error in
            if let err = error as NSError? {
                self?.auth_error = self?.mapAuthError(err)
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - Firestore User Doc
    private func createOrVerifyUserDocument(for user: User, email: String, completion: @escaping () -> Void) {
        let ref = db.collection("users").document(user.uid)
        ref.getDocument { [weak self] doc, error in
            if let _ = error {
                self?.auth_error = "Failed to verify user data."
                completion(); return
            }
            if doc?.exists == true {
                completion()
            } else {
                let data: [String:Any] = [
                    "email": email,
                    "displayName": "",
                    "totalPoints": 0,
                    "createdAt": FieldValue.serverTimestamp(),
                    "meditationTime": 0,
                    "deepWorkTime": 0,
                    "defaultHabitsCreated": false
                ]
                ref.setData(data) { error in
                    if error != nil {
                        self?.auth_error = "Failed to create user data."
                    }
                    completion()
                }
            }
        }
    }

    private func fetchUserModel(userId: String) {
        let ref = db.collection("users").document(userId)
        ref.getDocument { [weak self] doc, error in
            if let _ = error {
                self?.auth_error = "Failed to fetch user data."
                return
            }
            if let model = try? doc?.data(as: UserModel.self) {
                self?.userModel = model
            }
        }
    }

    // MARK: - Error Mapping
    private func mapAuthError(_ error: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail:         return "Badly formatted email."
        case .emailAlreadyInUse:    return "Email already in use."
        case .weakPassword:         return "Password too weak."
        case .wrongPassword:        return "Wrong email or password."
        case .userNotFound:         return "No account found with this email."
        case .networkError:         return "Network error. Try again."
        default:                    return error.localizedDescription
        }
    }

    // MARK: - Cleanup
    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
        userDocListener?.remove()
    }
}


