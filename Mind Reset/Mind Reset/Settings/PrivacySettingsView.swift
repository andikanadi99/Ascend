//
//  PrivacySettingsView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/2/25.
//


import SwiftUI

struct PrivacySettingsView: View {
    // Customize your accent color to match your dark/cyan theme.
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    // MARK: - Legal Section
                    Section(header: Text("Legal")
                                .foregroundColor(accentCyan)
                                .font(.headline)) {
                        NavigationLink(destination: PrivacyPolicyView()) {
                            HStack {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(accentCyan)
                                Text("Privacy Policy")
                                    .foregroundColor(.white)
                            }
                        }
                        NavigationLink(destination: TermsOfServiceView()) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(accentCyan)
                                Text("Terms of Service")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // MARK: - Data Section
                    Section(header: Text("Data")
                                .foregroundColor(accentCyan)
                                .font(.headline)) {
                        // Example toggle for analytics.
                        Toggle(isOn: .constant(true)) {
                            Text("Allow Analytics")
                                .foregroundColor(.white)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .background(Color.black)
            }
            .navigationTitle("Privacy & Legal")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Privacy Policy Detail View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
            [Your Privacy Policy]
            
            This is where you can include the details of your privacy policy. Explain what data is collected, how it’s used, and the rights of your users. You can also provide contact information for privacy concerns.
            """)
                .foregroundColor(.white)
                .padding()
        }
        .background(Color.black)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms of Service Detail View
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            Text("""
            [Your Terms of Service]
            
            This is where you can include the details of your terms of service. Explain the rules and guidelines for using your app, and any disclaimers or limitations of liability.
            """)
                .foregroundColor(.white)
                .padding()
        }
        .background(Color.black)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettingsView()
    }
}
