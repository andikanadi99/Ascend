//
//  AddHabitView.swift
//  Mind Reset
//  Objective: Serves as the a pop up view for users to add habits to their collection.
//  Created by Andika Yudhatrisna on 12/12/24.
//

import SwiftUI
import FirebaseAuth
@available(iOS 16.0, *)
struct AddHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var session: SessionStore
    @ObservedObject var viewModel: HabitViewModel
    
    // MARK: - Habit Variables
    @State private var habitTitle: String = ""
    @State private var habitDescription: String = ""
    @State private var startDate: Date = Date()
    @State private var target: String = "" // e.g. "3 times per week"
    @State private var setReminder: Bool = false
    @State private var reminderTime: Date = Date()
    
    // MARK: - Styling
    let backgroundColor = Color.black
    let accentColor = Color(red: 0, green: 1, blue: 1) // Electric blue/cyan
    let textFieldBackground = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            // Scroll if fields extend beyond the screen
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Title at the top
                    Text("Add New Habit")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // MARK: Habit Title Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Habit Title")
                            .foregroundColor(accentColor)
                            .fontWeight(.semibold)
                        
                        TextField(
                            "",
                            text: $habitTitle,
                            prompt: Text("Enter Habit Title")
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
                        .onChange(of: habitTitle) { _, _ in
                            session.auth_error = nil
                        }
                    }
                    
                    // MARK: Habit Description Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Habit Description")
                            .foregroundColor(accentColor)
                            .fontWeight(.semibold)
                        
                        TextField(
                            "",
                            text: $habitDescription,
                            prompt: Text("Enter Habit Description")
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
                        .onChange(of: habitDescription) { _, _ in
                            session.auth_error = nil
                        }
                    }
                    // MARK: Start Date Picker
                    VStack(alignment: .leading, spacing: 5) {
                       Text("Start Date")
                           .foregroundColor(accentColor)
                           .fontWeight(.semibold)
                       
                       DatePicker(
                           "",
                           selection: $startDate,
                           displayedComponents: .date
                       )
                       .datePickerStyle(WheelDatePickerStyle())
                       .padding()
                       .background(accentColor.opacity(0.8)) //
                       .cornerRadius(8)
                       .accentColor(accentColor)
                   }
                    
                    // MARK: Target Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Target")
                            .foregroundColor(accentColor)
                            .fontWeight(.semibold)
                        
                        TextField(
                            "",
                            text: $target,
                            prompt: Text("e.g. 3 times per week")
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
                        .onChange(of: target) { _, _ in
                            session.auth_error = nil
                        }
                    }
                    
                    // MARK: Reminder Toggle
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle(isOn: $setReminder) {
                            Text("Reminder")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: accentColor))
                        
                        if setReminder {
                            DatePicker(
                                "Reminder Time",
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                            .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(textFieldBackground)
                    .cornerRadius(8)
                    
                    // MARK: Create Habit Button
                    Button(action: {
                        createHabit()
                    }) {
                        Text("Create Habit")
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(accentColor)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                    .disabled(habitTitle.isEmpty || habitDescription.isEmpty)
                    
                    // Cancel Button / or close view
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity)
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Create Habit Action
    private func createHabit() {
        guard let userId = session.current_user?.uid else {
            print("No authenticated user found, cannot add habit.")
            return
        }
        
        let newHabit = Habit(
            title: habitTitle,
            description: habitDescription,
            startDate: startDate,
            ownerId: userId
        )
        
        // Insert into Firestore
        viewModel.addHabit(newHabit)
        
        // Optionally handle target or reminderTime if you plan to store them in Firestore:
        // e.g., you might extend your Habit model or do additional logic
        
        // Close this view
        presentationMode.wrappedValue.dismiss()
    }
}

//Preview
struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock dependencies
        let viewModel = HabitViewModel()
        let session = SessionStore()
        
        return AddHabitView(viewModel: viewModel)
            .environmentObject(session)
    }
}
