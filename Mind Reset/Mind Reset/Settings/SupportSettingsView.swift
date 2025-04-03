//
//  SupportSettingsView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/3/25.
//

import SwiftUI

struct SupportSettingsView: View {
    // Customize your accent color to match your dark/cyan theme.
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section(header: Text("Support")
                                .padding(.bottom)
                                .foregroundColor(accentCyan)
                                .font(.headline)) {
                        NavigationLink(destination: ContactSupportView(supportType: .contact)) {
                            Label("Question/Feedback", systemImage: "envelope")
                                .foregroundColor(.white)
                        }
                        NavigationLink(destination: ContactSupportView(supportType: .report)) {
                            Label("Report a Problem", systemImage: "exclamationmark.bubble")
                                .foregroundColor(.white)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .background(Color.black)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

enum SupportType {
    case contact
    case report
}

struct ContactSupportView: View {
    let supportType: SupportType
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var showAlert: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    // Customize your accent color to match your dark/cyan theme.
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    private var titleText: String {
        switch supportType {
        case .contact:
            return "Question/Feedback"
        case .report:
            return "Report a Problem"
        }
    }
    
    private var defaultSubject: String {
        switch supportType {
        case .contact:
            return "Question/Feedback"
        case .report:
            return "Problem Report"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(titleText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
                
                TextEditor(text: $message)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .frame(minHeight: 200)
                    .overlay(
                        Group {
                            if message.isEmpty {
                                Text("Type your message here...")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    )
                
                Button(action: sendMessage) {
                    Text("Send")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentCyan)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // Remove the explicit back button modifiers so the parent's back arrow is used.
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Message Sent"),
                message: Text("Your \(titleText.lowercased()) message has been sent."),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func sendMessage() {
        // In a real app, implement the functionality to send the message (e.g., via email or a support API)
        print("Subject: \(subject)")
        print("Message: \(message)")
        showAlert = true
    }
}

struct SupportSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SupportSettingsView()
    }
}
