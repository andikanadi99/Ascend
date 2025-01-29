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
   @State private var habitGoal: String = ""
   @State private var startDate: Date = Date()
   @State private var target: String = ""
   @State private var setReminder: Bool = false
   @State private var reminderTime: Date = Date()
   @State private var selectedMetricCategory: MetricCategory = .completion
   @State private var metricType: String = "Completion"
@State private var showingAlert = false
@State private var alertMessage = ""
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
                    }
                    
                    // MARK: Goal Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Goal")
                            .foregroundColor(accentColor)
                            .fontWeight(.semibold)
                        
                        TextField(
                            "",
                            text: $habitGoal,
                            prompt: Text("e.g. Read 50 books by the end of the year")
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
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
                       .background(accentColor.opacity(0.8))
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
                       }
                       
                       // MARK: Metric Category Picker (Optional)
                       VStack(alignment: .leading, spacing: 5) {
                           Text("Metric Category")
                               .foregroundColor(accentColor)
                               .fontWeight(.semibold)
                           
                           Picker("Metric Category", selection: $selectedMetricCategory) {
                               ForEach(MetricCategory.allCases, id: \.self) { category in
                                   Text(category.rawValue).tag(category)
                               }
                           }
                           .pickerStyle(MenuPickerStyle())
                           .foregroundColor(.white.opacity(0.8))
                           .padding()
                           .background(textFieldBackground)
                           .cornerRadius(8)
                       }
                       
                       // MARK: Metric Type Field (Optional)
                       VStack(alignment: .leading, spacing: 5) {
                           Text("Metric Type")
                               .foregroundColor(accentColor)
                               .fontWeight(.semibold)
                           
                           TextField(
                               "",
                               text: $metricType,
                               prompt: Text("e.g. Minutes, Times, Completion")
                                   .foregroundColor(.white.opacity(0.8))
                           )
                           .foregroundColor(.white.opacity(0.8))
                           .autocapitalization(.none)
                           .disableAutocorrection(true)
                           .padding()
                           .background(textFieldBackground)
                           .cornerRadius(8)
                       }
                       
                       // MARK: Reminder Toggle (Optional Usage)
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
                    Button(action: createHabit) {
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
                    
                    // Cancel Button
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
        // Attach the alert to the view
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text("Info"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            if alertMessage == "Habit created successfully!" {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                }
            }
    
    // MARK: - Create Habit Action
    private func createHabit() {
        guard let userId = session.current_user?.uid else {
            print("No authenticated user found; cannot add habit.")
            alertMessage = "No authenticated user found; cannot add habit."
            showingAlert = true
            return
        }
        
        // Validate and convert target to Double
        guard let targetValue = Double(target), targetValue > 0 else {
            print("Invalid target value; must be a positive number.")
            alertMessage = "Invalid target value; must be a positive number."
            showingAlert = true
            return
        }
        
        // Initialize a new Habit instance with all necessary properties
        let newHabit = Habit(
            title: habitTitle,
            description: habitDescription,
            goal: habitGoal,
            startDate: startDate,
            ownerId: userId,
            isCompletedToday: false,
            currentStreak: 0,
            longestStreak: 0,
            lastReset: Date(),
            metricCategory: selectedMetricCategory, // Default or selected value
            metricType: metricType.isEmpty ? "Completion" : metricType, // Default if empty
            targetValue: targetValue,
            dailyRecords: [] // Initialize as empty
        )
        
        // Insert into Firestore via ViewModel with Completion Handler
        viewModel.addHabit(newHabit) { success in
            if success {
                // Show success message and dismiss
                alertMessage = "Habit created successfully!"
            } else {
                // Show failure message
                alertMessage = "Failed to create habit. Please try again."
            }
            showingAlert = true
        }
    }
}

// MARK: - Preview
struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock dependencies
        let viewModel = HabitViewModel()
        let session = SessionStore()
        
        return AddHabitView(viewModel: viewModel)
            .environmentObject(session)
    }
}
