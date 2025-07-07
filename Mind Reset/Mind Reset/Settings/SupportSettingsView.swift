//
//  SupportSettingsView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/3/25.
//

import SwiftUI
import FirebaseFirestore

struct SupportSettingsView: View {
    @EnvironmentObject private var session: SessionStore
    private let db = Firestore.firestore()
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    private let supportAddress = "andikanadi10@gmail.com"

    // MARK: – User input
    @State private var feedbackMessage: String = ""
    @State private var issueMessage: String = ""

    // MARK: – Focus states for keyboard
    @FocusState private var isFeedbackFocused: Bool
    @FocusState private var isIssueFocused: Bool

    // MARK: – Alert state
    @State private var showAlert      = false
    @State private var alertTitle     = ""
    @State private var alertMessage   = ""

    var body: some View {
        // ───────────────────────────────────────────────────────────────────────────
        // Wrap the entire view in a tappable area to dismiss the keyboard.
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    // MARK: General Feedback
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share Feedback")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextEditor(text: $feedbackMessage)
                            .focused($isFeedbackFocused)                              // focus binding
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .overlay(
                                SwiftUI.Group {
                                    if feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Your thoughts…")
                                            .foregroundColor(.white.opacity(0.6))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    }
                                },
                                alignment: .topLeading
                            )

                        Button("Send Feedback") {
                            submit(type: "Feedback", message: feedbackMessage)
                        }
                        .disabled(feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(CyanButtonStyle())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    // MARK: Problem Reports
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Report a Problem")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextEditor(text: $issueMessage)
                            .focused($isIssueFocused)                                 // focus binding
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .overlay(
                                SwiftUI.Group {
                                    if issueMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Describe the issue…")
                                            .foregroundColor(.white.opacity(0.6))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    }
                                },
                                alignment: .topLeading
                            )

                        Button("Send Report") {
                            submit(type: "Issue Report", message: issueMessage)
                        }
                        .disabled(issueMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(CyanButtonStyle())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
        }
        // ───────────────────────────────────────────────────────────────────────────
        .toolbar {
            // This toolbar appears whenever *any* keyboard is up
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // Clear every focus state
                    isFeedbackFocused = false
                    isIssueFocused    = false
                }
            }
        }
        .navigationBarTitle("Support", displayMode: .inline)
        .preferredColorScheme(.dark)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: – Submit to `mail` collection
    private func submit(type: String, message: String) {
        guard let user = session.userModel else {
            alertTitle   = "Not Signed In"
            alertMessage = "You must be signed in to send feedback."
            showAlert    = true
            return
        }

        let emailDoc: [String: Any] = [
            "to":      [ supportAddress ],
            "from":    user.email,
            "replyTo": supportAddress,
            "message": [
                "subject": "\(type) from \(user.displayName.isEmpty ? user.email : user.displayName)",
                "text":    message
            ]
        ]

        db.collection("mail")
          .addDocument(data: emailDoc) { error in
            if let error = error {
                alertTitle   = "Error"
                alertMessage = "Failed to send: \(error.localizedDescription)"
            } else {
                alertTitle   = "Thank You!"
                alertMessage = (type == "Feedback")
                    ? "Your feedback has been sent."
                    : "Your problem report has been sent. We'll look into it."
                if type == "Feedback" { feedbackMessage = "" }
                else                  { issueMessage = "" }
            }
            showAlert = true
        }
    }
}

// MARK: – Reusable Cyan Button Style
private struct CyanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let accent = Color(red: 0, green: 1, blue: 1)
        return configuration.label
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(accent.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(8)
    }
}

// MARK: – Preview
struct SupportSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SupportSettingsView()
                .environmentObject(SessionStore())
        }
    }
}
