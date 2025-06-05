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

    // MARK: – Focusable Fields
    private enum Field: Hashable {
        case title, description, goal, customMetric
    }
    @FocusState private var focusedField: Field?

    // MARK: – Habit Variables
    @State private var habitTitle = ""
    @State private var habitDescription = ""
    @State private var habitGoal = ""
    @State private var startDate = Date()
    @State private var setReminder = false
    @State private var reminderTime = Date()
    @State private var selectedMetricCategory: MetricCategory = .completion
    @State private var selectedMetricType: MetricType = .predefined("Completed (Yes/No)")
    @State private var customMetricTypeInput = ""

    // MARK: – Alert States
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // MARK: – Styling
    let backgroundColor = Color.black
    let accentColor     = Color(red: 0, green: 1, blue: 1) // Electric cyan
    let textFieldBG     = Color(red: 0.15, green: 0.15, blue: 0.15)

    // MARK: – Form Validation
    private var isFormValid: Bool {
        !habitTitle.isEmpty &&
        !habitDescription.isEmpty &&
        !habitGoal.isEmpty &&
        (selectedMetricCategory != .custom || !customMetricTypeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        // ───────────────────────────────────────────────────────────────────────────
        // Wrap the entire view in a tappable area to dismiss the keyboard.
        ZStack {
            NavigationStack {
                ZStack {
                    backgroundColor.ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Title
                            Text("Add New Habit")
                                .font(.title).fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.top, 20)

                            // MARK: Habit Title Field
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 2) {
                                    Text("Habit Title")
                                        .foregroundColor(accentColor)
                                        .fontWeight(.semibold)
                                    Text("*").foregroundColor(.red)
                                }
                                TextField(
                                    "",
                                    text: $habitTitle,
                                    prompt: Text("Enter Habit Title")
                                        .foregroundColor(.white.opacity(0.8))
                                )
                                .focused($focusedField, equals: .title)
                                .foregroundColor(.white.opacity(0.8))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(textFieldBG)
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
                                    Text("*").foregroundColor(.red)
                                }
                                TextEditor(text: $habitDescription)
                                    .focused($focusedField, equals: .description)
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.subheadline)
                                    .disableAutocorrection(true)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(textFieldBG)
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
                                        },
                                        alignment: .topLeading
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
                                    Text("*").foregroundColor(.red)
                                }
                                TextField(
                                    "",
                                    text: $habitGoal,
                                    prompt: Text("e.g. Read 50 books by the end of the year")
                                        .foregroundColor(.white.opacity(0.8))
                                )
                                .focused($focusedField, equals: .goal)
                                .foregroundColor(.white.opacity(0.8))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(textFieldBG)
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
                                .background(Color.black)
                                .cornerRadius(8)
                                .accentColor(accentColor)
                                .environment(\.colorScheme, .dark)
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
                                        Button(category.rawValue) {
                                            selectedMetricCategory = category
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedMetricCategory.rawValue)
                                            .foregroundColor(.white.opacity(0.8))
                                            .lineLimit(1).truncationMode(.tail)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.vertical).padding(.horizontal)
                                    .background(textFieldBG)
                                    .cornerRadius(8)
                                }
                                .accessibilityLabel("Metric Category Picker")
                                .accessibilityHint("Select a metric category for your habit")
                            }
                            .onChange(of: selectedMetricCategory) { newCat in
                                if newCat == .custom {
                                    selectedMetricType = .custom("")
                                } else if let first = newCat.metricTypes.first {
                                    selectedMetricType = first
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

                            // MARK: Reminder Toggle
                            VStack(alignment: .leading, spacing: 5) {
                                Toggle("Reminder", isOn: $setReminder)
                                    .toggleStyle(SwitchToggleStyle(tint: accentColor))
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)

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
                            .background(textFieldBG)
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
                            Button("Cancel") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Cancel Button")
                            .accessibilityHint("Dismisses the add habit view without saving")
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
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
                .navigationTitle("Add New Habit")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .contentShape(Rectangle())   // Make the entire ZStack respond to taps
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
        // ───────────────────────────────────────────────────────────────────────────
    }

    // MARK: – Create Habit Action
    private func createHabit() {
        guard let userId = session.current_user?.uid else {
            alertMessage = "No authenticated user found; cannot add habit."
            showingAlert = true
            return
        }

        let finalMetricType: MetricType
        if selectedMetricCategory == .custom {
            let trimmed = customMetricTypeInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                alertMessage = "Custom metric type cannot be empty."
                showingAlert = true
                return
            }
            finalMetricType = .custom(trimmed)
        } else {
            finalMetricType = selectedMetricType
        }

        let newHabit = Habit(
            title: habitTitle,
            description: habitDescription,
            goal: habitGoal,
            startDate: startDate,
            ownerId: userId,
            currentStreak: 0,
            longestStreak: 0,
            lastReset: Date(),
            weeklyStreakBadge: false,
            monthlyStreakBadge: false,
            yearlyStreakBadge: false,
            metricCategory: selectedMetricCategory,
            metricType: finalMetricType,
            dailyRecords: []
        )

        viewModel.addHabit(newHabit) { success in
            alertMessage = success
                ? "Habit created successfully!"
                : "Failed to create habit. Please try again."
            showingAlert = true
        }
    }
}

struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        AddHabitView(viewModel: HabitViewModel())
            .environmentObject(SessionStore())
    }
}
