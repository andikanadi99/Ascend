//
//  AddHabitView.swift
//  Mind Reset
//  Objective: Serves as a pop-up view for users to add habits to their collection.
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
    @State private var setReminder: Bool = false
    @State private var reminderTime: Date = Date()
    @State private var selectedMetricCategory: MetricCategory = .completion
    @State private var selectedMetricType: MetricType = .predefined("Completed (Yes/No)")
    @State private var customMetricTypeInput: String = ""
    
    // MARK: - Alert States
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Styling
    let backgroundColor = Color.black
    let accentColor = Color(red: 0, green: 1, blue: 1) // Electric blue/cyan
    let textFieldBackground = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !habitTitle.isEmpty &&
        !habitDescription.isEmpty &&
        !habitGoal.isEmpty &&
        (selectedMetricCategory != .custom || !customMetricTypeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
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
                        HStack(spacing: 2) {
                            Text("Habit Title")
                                .foregroundColor(accentColor)
                                .fontWeight(.semibold)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
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
                        .accessibilityLabel("Habit Title")
                        .accessibilityHint("Enter the title of your habit")
                    }
                    
                    // MARK: Habit Description Field
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 2) {
                            Text("Habit Description")
                                .foregroundColor(accentColor)
                                .fontWeight(.semibold)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        TextEditor(text: $habitDescription)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                            .disableAutocorrection(true)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(textFieldBackground)
                            .cornerRadius(8)
                            .frame(minHeight: 100)
                            .overlay(
                                Group {
                                    if habitDescription.isEmpty {
                                        Text("Enter Habit Description")
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 12)
                                    }
                                }, alignment: .topLeading
                            )
                            .accessibilityLabel("Habit Description")
                            .accessibilityHint("Enter a description for your habit")
                    }
                    
                    // MARK: Goal Field
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 2) {
                            Text("Goal")
                                .foregroundColor(accentColor)
                                .fontWeight(.semibold)
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
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
                        .accessibilityLabel("Goal")
                        .accessibilityHint("Enter the goal for your habit")
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
                        .accessibilityLabel("Start Date Picker")
                        .accessibilityHint("Select the start date for your habit")
                    }
                    
                    // MARK: Metric Category Picker
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Metric Category")
                            .foregroundColor(accentColor)
                            .fontWeight(.semibold)
                        
                        Menu {
                            ForEach(MetricCategory.allCases) { category in
                                Button(action: {
                                    selectedMetricCategory = category
                                }) {
                                    Text(category.rawValue)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedMetricCategory.rawValue)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.vertical)
                            .padding(.horizontal)
                            .background(textFieldBackground)
                            .cornerRadius(8)
                        }
                        .accessibilityLabel("Metric Category Picker")
                        .accessibilityHint("Select a metric category for your habit")
                    }
                    .onChange(of: selectedMetricCategory) { newCategory in
                        if newCategory == .custom {
                            selectedMetricType = .custom("")
                        } else if let firstMetric = newCategory.metricTypes.first {
                            selectedMetricType = firstMetric
                        }
                    }
                    
                    // MARK: Metric Type Picker
                    MetricTypePicker(
                        category: selectedMetricCategory,
                        selectedMetricType: $selectedMetricType,
                        customMetricTypeInput: $customMetricTypeInput
                    )
                    .cornerRadius(8)
                    .accessibilityElement(children: .contain)
                    
                    // MARK: Reminder Toggle (Optional Usage)
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle(isOn: $setReminder) {
                            Text("Reminder")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: accentColor))
                        .accessibilityLabel("Reminder Toggle")
                        .accessibilityHint("Toggle to set a reminder for your habit")
                        
                        if setReminder {
                            DatePicker(
                                "",
                                selection: $reminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(WheelDatePickerStyle())
                            .environment(\.colorScheme, .dark)
                            .accessibilityLabel("Reminder Time Picker")
                            .accessibilityHint("Select the time for your habit reminder")
                        }
                    }
                    .padding()
                    .background(textFieldBackground)
                    .cornerRadius(8)
                    
                    // MARK: Create Habit Button
                    Button(action: createHabit) {
                        Text("Create Habit")
                            .foregroundColor(isFormValid ? .black : .gray)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isFormValid ? accentColor : Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                    .disabled(!isFormValid)
                    .accessibilityLabel("Create Habit Button")
                    .accessibilityHint("Creates a new habit with the provided details")
                    
                    // MARK: Cancel Button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Cancel Button")
                    .accessibilityHint("Dismisses the add habit view without saving")
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
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
    }
    
    // MARK: - Create Habit Action
    private func createHabit() {
        guard let userId = session.current_user?.uid else {
            print("No authenticated user found; cannot add habit.")
            alertMessage = "No authenticated user found; cannot add habit."
            showingAlert = true
            return
        }
        
        // Determine the final metric type
        let finalMetricType: MetricType
        if selectedMetricCategory == .custom {
            let trimmedCustomMetric = customMetricTypeInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCustomMetric.isEmpty else {
                print("Custom metric type cannot be empty.")
                alertMessage = "Custom metric type cannot be empty."
                showingAlert = true
                return
            }
            finalMetricType = .custom(trimmedCustomMetric)
        } else {
            finalMetricType = selectedMetricType
        }
        
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
            metricCategory: selectedMetricCategory,
            metricType: finalMetricType,
            dailyRecords: []
        )
        
        viewModel.addHabit(newHabit) { success in
            if success {
                alertMessage = "Habit created successfully!"
            } else {
                alertMessage = "Failed to create habit. Please try again."
            }
            showingAlert = true
        }
    }
}

struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = HabitViewModel()
        let session = SessionStore()
        return AddHabitView(viewModel: viewModel)
            .environmentObject(session)
    }
}
