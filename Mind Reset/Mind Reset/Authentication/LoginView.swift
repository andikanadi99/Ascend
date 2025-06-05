//
//  LoginView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI
import AuthenticationServices   // ← Apple Sign-in
import CryptoKit               // ← nonce hashing
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

@available(iOS 16.0, *)

// MARK: - UIKit wrapper for the Apple Sign-in button
private struct AppleIDButtonWrapped: UIViewRepresentable {
    var cornerRadius: CGFloat = 8
    let onRequest:  (ASAuthorizationAppleIDRequest) -> Void
    let onComplete: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        btn.cornerRadius = cornerRadius
        btn.addTarget(context.coordinator,
                      action: #selector(Coordinator.didTap),
                      for: .touchUpInside)
        return btn
    }
    func updateUIView(_ view: ASAuthorizationAppleIDButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onRequest, onComplete) }

    final class Coordinator: NSObject,
        ASAuthorizationControllerDelegate,
        ASAuthorizationControllerPresentationContextProviding {

        private let onRequest:  (ASAuthorizationAppleIDRequest) -> Void
        private let onComplete: (Result<ASAuthorization, Error>) -> Void

        init(_ onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
             _ onComplete: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onRequest  = onRequest
            self.onComplete = onComplete
        }

        @objc func didTap() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            onRequest(request)
            let ctrl = ASAuthorizationController(authorizationRequests: [request])
            ctrl.delegate = self
            ctrl.presentationContextProvider = self
            ctrl.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization authorization: ASAuthorization) {
            onComplete(.success(authorization))
        }
        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithError error: Error) {
            onComplete(.failure(error))
        }
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

// MARK: - LoginView
struct LoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var email        = ""
    @State private var password     = ""
    @State private var showPassword = false
    @State private var currentNonce: String?

    private let backgroundBlack = Color.black
    private let neonCyan        = Color(red: 0, green: 1, blue: 1)
    private let fieldBG         = Color(red: 0.102, green: 0.102, blue: 0.102)

    var body: some View {
        ZStack {
            backgroundBlack
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { hideLoginKeyboard() }

            VStack(spacing: 20) {
                Image("AppFullWord")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .padding(.top, 10)

                // Email
                TextField("", text: $email, prompt: Text("Enter Your Email")
                    .foregroundColor(.white.opacity(0.8)))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(fieldBG)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: email) { _ in session.auth_error = nil }

                // Password
                ZStack(alignment: .trailing) {
                    Group {
                        if showPassword {
                            TextField("", text: $password, prompt: Text("Enter Your Password")
                                .foregroundColor(.white.opacity(0.8)))
                        } else {
                            SecureField("", text: $password, prompt: Text("Enter Your Password")
                                .foregroundColor(.white.opacity(0.8)))
                        }
                    }
                    .textContentType(.password)
                    .foregroundColor(.white)
                    .padding()
                    .background(fieldBG)
                    .cornerRadius(8)
                    .onChange(of: password) { _ in session.auth_error = nil }

                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 15)
                    }
                }
                .padding(.horizontal)

                // Auth error
                if let error = session.auth_error,
                   error != "User data not found." {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Email / Password Login
                Button("Login", action: login)
                    .buttonStyle(PrimaryButton(neonCyan))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                // Apple Sign-in
                AppleIDButtonWrapped(
                    onRequest:  configureAppleRequest,
                    onComplete: handleAppleResult
                )
                .frame(height: 45)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                // Google Sign-in
                Button {
                    startGoogleSignIn()
                } label: {
                    HStack(spacing: 8) {
                        Image("GoogleLogo")
                            .resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Text("Sign in with Google")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                // Navigation Links
                NavigationLink("Forgot Password?", destination: ForgetPasswordView())
                    .foregroundColor(neonCyan)
                NavigationLink("Don't have an account? Please sign up",
                               destination: SignUpView())
                    .foregroundColor(neonCyan)
                    .offset(y: -10)
            }
            .padding(.vertical)
            .navigationBarHidden(true)
        }
        .onAppear { session.auth_error = nil }
    }

    // MARK: - Actions
    private func startGoogleSignIn() {
        guard
            let rootVC = UIApplication.shared
                .connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first?.rootViewController
        else {
            print("❗️ Couldn’t find root view-controller")
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { signInResult, error in
            handleGoogleSignIn(signInResult: signInResult, error: error)
        }
    }

    private func login() {
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

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            session.auth_error = error.localizedDescription
        case .success(let auth):
            guard
              let cred = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce
            else {
                session.auth_error = "Bad Apple credential"
                return
            }
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: token,
                rawNonce: nonce
            )
            session.signInWithApple(credential: credential)
        }
    }

    private func handleGoogleSignIn(signInResult: GIDSignInResult?, error: Error?) {
        if let error = error {
            session.auth_error = error.localizedDescription
            return
        }
        guard
            let result  = signInResult,
            let idToken = result.user.idToken?.tokenString
        else {
            session.auth_error = "Google sign-in failed (missing idToken)."
            return
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        session.signInWithGoogle(credential: credential)
    }

    // MARK: - Utilities

    private func isEmailValid(_ email: String) -> Bool {
        let pattern = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""; var remaining = length
        while remaining > 0 {
            (0..<16).map { _ in UInt8.random(in: 0...255) }.forEach {
                if remaining > 0 && $0 < charset.count {
                    result.append(charset[Int($0)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Primary Button Style
private struct PrimaryButton: ButtonStyle {
    let color: Color
    init(_ color: Color) { self.color = color }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(8)
    }
}

// MARK: - Hide Keyboard Helper
#if canImport(UIKit)
extension View {
    func hideLoginKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
                .environmentObject(SessionStore())
        }
        .preferredColorScheme(.dark)
    }
}

