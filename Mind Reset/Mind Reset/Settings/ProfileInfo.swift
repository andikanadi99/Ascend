//
//  ProfileInfo.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/2/25.
//

import SwiftUI
import FirebaseFirestore


struct ProfileInfo: View {
    @EnvironmentObject var session: SessionStore

    // MARK: - Editing state
    @State private var isEditing = false
    @State private var updatedDisplayName = ""
    @State private var updatedEmail = ""
    @State private var showSaveProfileAlert = false
    @FocusState private var isDisplayNameFocused: Bool

    // MARK: - Default wake/sleep times
    @State private var defaultWake: Date = {
        UserDefaults.standard.object(forKey: "DefaultWakeUpTime") as? Date
            ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
    }()
    @State private var defaultSleep: Date = {
        UserDefaults.standard.object(forKey: "DefaultSleepTime") as? Date
            ?? Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
    }()
    @State private var showSaveTimesAlert = false

    let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Picture
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(accentCyan)

                // Account Info
                if let user = session.userModel {
                    if isEditing {
                        VStack(spacing: 12) {
                            TextField("Display Name", text: $updatedDisplayName)
                                .focused($isDisplayNameFocused)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                            
                        }
                    } else {
                        Text(user.displayName.isEmpty ? "No Display Name" : user.displayName)
                            .font(.title)
                            .foregroundColor(.white)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text("Joined on \(formattedDate(user.createdAt))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("Loading Profile...")
                        .foregroundColor(.white)
                }

                // Edit / Save Profile Button
                Button(action: {
                    if isEditing {
                        showSaveProfileAlert = true
                    } else if let user = session.userModel {
                        updatedDisplayName = user.displayName
                        updatedEmail = user.email
                    }
                    withAnimation { isEditing.toggle() }
                }) {
                    Text(isEditing ? "Save Profile" : "Edit Profile")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(accentCyan)
                        .cornerRadius(8)
                }
                .alert(
                    "Save Profile Changes?",
                    isPresented: $showSaveProfileAlert,
                    actions: {
                        Button("Save", role: .destructive) {
                            saveProfile()
                        }
                        Button("Cancel", role: .cancel) { }
                    },
                    message: {
                        Text("Are you sure you want to overwrite your display name?")
                    }
                )

                // Default Times Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Times")
                        .font(.headline)
                        .foregroundColor(accentCyan)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Wake Up")
                                .foregroundColor(.white)
                            DatePicker(
                                "",
                                selection: $defaultWake,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .environment(\.colorScheme, .dark)
                            .padding(4)
                            .background(Color.black)
                            .cornerRadius(4)
                        }

                        Spacer()

                        VStack(alignment: .leading) {
                            Text("Sleep")
                                .foregroundColor(.white)
                            DatePicker(
                                "",
                                selection: $defaultSleep,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .environment(\.colorScheme, .dark)
                            .padding(4)
                            .background(Color.black)
                            .cornerRadius(4)
                        }
                    }

                    Button(action: {
                        showSaveTimesAlert = true
                    }) {
                        Text("Save Default Times")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(accentCyan)
                            .cornerRadius(8)
                    }
                    .alert(
                        "Save Default Times?",
                        isPresented: $showSaveTimesAlert,
                        actions: {
                            Button("Save", role: .destructive) {
                                saveDefaultTimes()
                            }
                            Button("Cancel", role: .cancel) { }
                        },
                        message: {
                            Text("This will update your default wake‑up and sleep times for all future days.")
                        }
                    )

                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
            .padding()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .toolbar {                                             // ← this goes on your root
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
              isDisplayNameFocused = false
            }
          }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    private func saveProfile() {
        guard let uid = session.current_user?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).updateData([
            "displayName": updatedDisplayName,
            "email": updatedEmail
        ]) { error in
            if let error = error {
                print("Profile save error: \(error)")
            } else {
                DispatchQueue.main.async {
                    session.userModel?.displayName = updatedDisplayName
                    session.userModel?.email = updatedEmail
                }
            }
        }
    }

    private func saveDefaultTimes() {
        session.setDefaultTimes(wake: defaultWake, sleep: defaultSleep)
    }
}

struct ProfileInfo_Previews: PreviewProvider {
    static var previews: some View {
        ProfileInfo()
            .environmentObject(SessionStore())
    }
}
