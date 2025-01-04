//
//  HabitDetailView.swift
//  Mind Reset
//  Objective: Serves as an individual habit page. Display specific statisics, goals and description of said habit
//  Created by Andika Yudhatrisna on 1/3/25.
//

import SwiftUI

/// A self-contained, tabbed SwiftUI view for displaying and managing a single habit
/// using a tabbed interface (Focus, Progress, Notes), timer customization,
/// a long-term goal editor, and a "Mark Habit as Done" button.
/// This version allows the user to edit the habit's title and description at the top.
struct HabitDetailView: View {
    // MARK: - The Habit Being Displayed
    let habit: Habit
    
    // Access your HabitViewModel (optional)
    @EnvironmentObject var viewModel: HabitViewModel
    
    // MARK: - Dismiss Environment for Navigation Back
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Editable Local Fields
    @State private var editableTitle: String
    @State private var editableDescription: String
    
    // MARK: - Tabs
    @State private var selectedTab = 0  // 0=Focus, 1=Progress, 2=Notes
    
    // MARK: - Timer States
    @State private var currentTimerValue: Int = 0
    @State private var isTimerRunning    = false
    @State private var isTimerPaused     = false
    
    // Example local property for demonstration.
    @State private var totalFocusTime: Int = 0
    
    // Timer customization (segmented control)
    @State private var timerOptions: [Int] = [15, 25, 45]
    @State private var selectedTimerIndex: Int = 1   // default = 25 min
    @State private var showCustomTimeSheet = false
    
    // Notes
    @State private var sessionNotes: String = ""
    @State private var pastSessionNotes: [String] = []
    
    // Long-term goal
    @State private var longTermGoal: String = ""
    
    // Smooth transitions
    @Namespace private var animation
    @State private var showCharts: Bool = false
    
    // MARK: - Colors & Layout
    let backgroundBlack      = Color.black
    let accentCyan           = Color(red: 0, green: 1, blue: 1)
    let textFieldBackground  = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    // MARK: - Init
    /// We initialize `editableTitle` and `editableDescription` from the `habit` object
    init(habit: Habit) {
        self.habit = habit
        _editableTitle = State(initialValue: habit.title)
        _editableDescription = State(initialValue: habit.description)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundBlack.ignoresSafeArea()
            
            VStack(spacing: 15) {
                
                // MARK: - Top Bar: Custom Back + Title/Description
                HStack {
                    Button {
                        // Dismiss the view if in NavigationView
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.cyan)
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    // Title is now a TextField for user editing
                    TextField("Habit Title", text: $editableTitle)
                        .multilineTextAlignment(.center)
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: 200) // Slight limit for layout
                        .disableAutocorrection(true)
                    
                    Spacer()
                    Spacer().frame(width: 40)
                }
                
                // MARK: - Editable Description
                TextField("Habit Description", text: $editableDescription)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                
                // MARK: - Long-Term Goal
                // MARK: - Long-Term Goal
                VStack(alignment: .leading, spacing: 8) {
                    Text("Long-Term Goal")
                        .foregroundColor(accentCyan)
                        .font(.headline)
                    
                    // A ZStack so we can overlay a placeholder when the text is empty
                    ZStack(alignment: .topLeading) {
                        
                        // Placeholder text if longTermGoal is empty
                        if longTermGoal.isEmpty {
                            Text("e.g. Read 50 books by the end of the year")
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                        }
                        
                        // Actual TextEditor
                        TextEditor(text: $longTermGoal)
                            .foregroundColor(.white)
                            .accentColor(accentCyan)     // Cursor & selection color
                            .padding(8)                 // Some padding inside
                            .background(textFieldBackground)
                            .cornerRadius(8)
                            // Optional: Add a border for more accent
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(accentCyan.opacity(0.6), lineWidth: 1)
                            )
                            // Adjust the minimum/maximum height to your preference
                            .frame(minHeight: 60, maxHeight: 100)
                    }
                }

                
                // MARK: - Tabbed Interface
                TabView(selection: $selectedTab) {
                    
                    // 1) Focus tab
                    FocusTab(
                        habit: habit,
                        currentTimerValue: $currentTimerValue,
                        isTimerRunning: $isTimerRunning,
                        isTimerPaused: $isTimerPaused,
                        totalFocusTime: $totalFocusTime,
                        animation: animation
                    )
                    .tag(0)
                    
                    // 2) Progress tab
                    ProgressTab(
                        habit: habit,
                        showCharts: $showCharts,
                        animation: animation
                    )
                    .tag(1)
                    
                    // 3) Notes tab
                    NotesTab(
                        sessionNotes: $sessionNotes,
                        pastSessionNotes: $pastSessionNotes
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // MARK: - Timer Customization Presets
                VStack(alignment: .leading, spacing: 10) {
                    Text("Customize Timer")
                        .foregroundColor(.cyan)
                        .font(.headline)
                    
                    Picker("Timer Presets", selection: $selectedTimerIndex) {
                        ForEach(timerOptions.indices, id: \.self) { i in
                            Text("\(timerOptions[i]) min").tag(i)
                        }
                        Text("Custom").tag(timerOptions.count)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedTimerIndex) { newIndex in
                        if newIndex == timerOptions.count {
                            showCustomTimeSheet = true
                        } else {
                            let chosenMinutes = timerOptions[newIndex]
                            startTimer(minutes: chosenMinutes)
                        }
                    }
                    
                    Button("Add a Custom Time") {
                        showCustomTimeSheet = true
                    }
                    .foregroundColor(.cyan)
                }
                
                // MARK: - Mark Habit as Done
                Button(action: {
                    toggleHabitDone()
                }) {
                    Text(habit.isCompletedToday ? "Unmark Habit as Done" : "Mark Habit as Done")
                        .foregroundColor(.black)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(habit.isCompletedToday ? Color.red : .cyan)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: saveEditsToHabit) // Save the user's edits when leaving the view
        .sheet(isPresented: $showCustomTimeSheet) {
            AddCustomTimeView { newTime in
                timerOptions.append(newTime)
                selectedTimerIndex = timerOptions.count - 1
            }
        }
    }
    
    // MARK: - Timer Logic
    private func startTimer(minutes: Int) {
        currentTimerValue = minutes * 60
        isTimerRunning = true
        isTimerPaused  = false
    }
    
    private func toggleHabitDone() {
        var updatedHabit = habit
        updatedHabit.isCompletedToday.toggle()
        if updatedHabit.isCompletedToday {
            updatedHabit.streak += 1
        }
        // e.g. update Firestore
        viewModel.updateHabit(updatedHabit)
    }
    
    /// Called when the view disappears or user navigates back, to persist edits
    private func saveEditsToHabit() {
        guard editableTitle != habit.title || editableDescription != habit.description else { return }
        
        var updatedHabit = habit
        updatedHabit.title = editableTitle
        updatedHabit.description = editableDescription
        
        // e.g., update Firestore to reflect new title/description
        viewModel.updateHabit(updatedHabit)
    }
}

// MARK: - FocusTab
fileprivate struct FocusTab: View {
    let habit: Habit
    
    @Binding var currentTimerValue: Int
    @Binding var isTimerRunning: Bool
    @Binding var isTimerPaused: Bool
    
    @Binding var totalFocusTime: Int
    var animation: Namespace.ID
    
    let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 10)
            
            // Holographic Timer
            ZStack {
                Circle()
                    .stroke(accentCyan.opacity(0.2), lineWidth: 10)
                    .frame(width: 180, height: 180)
                
                Text(formatTime(currentTimerValue))
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            // Timer Buttons
            HStack(spacing: 20) {
                Button("Start")  { startTimer(25) }.buttonStyle(HolographicButtonStyle())
                Button(isTimerPaused ? "Resume" : "Pause") { pauseTimer() }.buttonStyle(HolographicButtonStyle())
                Button("Reset")  { resetTimer()  }.buttonStyle(HolographicButtonStyle())
            }
            
            // Intensity & Focused
            HStack {
                Text("Intensity: \(habit.streak)")
                    .foregroundColor(.white)
                Spacer()
                Text("Focused: \(formatTime(totalFocusTime))")
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
    
    private func startTimer(_ minutes: Int) {
        currentTimerValue = minutes * 60
        isTimerRunning    = true
        isTimerPaused     = false
    }
    
    private func pauseTimer() {
        isTimerPaused.toggle()
    }
    
    private func resetTimer() {
        isTimerRunning    = false
        isTimerPaused     = false
        currentTimerValue = 0
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - ProgressTab
fileprivate struct ProgressTab: View {
    let habit: Habit
    @Binding var showCharts: Bool
    var animation: Namespace.ID
    
    let accentCyan = Color(red: 0, green: 1, blue: 1)
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 10)
            
            Text("Progress Tracking")
                .font(.headline)
                .foregroundColor(accentCyan)
            
            ZStack {
                Rectangle()
                    .fill(accentCyan.opacity(0.2))
                    .frame(height: 150)
                    .cornerRadius(8)
                
                Text("Charts/Graphs Here")
                    .foregroundColor(.white)
            }
            
            Button("View Previous Notes") {
                // Could navigate or show a modal. For demonstration, do nothing
            }
            .foregroundColor(.cyan)
            
            Spacer()
        }
    }
}

// MARK: - NotesTab
fileprivate struct NotesTab: View {
    @Binding var sessionNotes: String
    @Binding var pastSessionNotes: [String]
    
    let accentCyan = Color(red: 0, green: 1, blue: 1)
    let textFieldBackground = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 10)
            
            Text("Session Notes")
                .font(.headline)
                .foregroundColor(accentCyan)
            
            TextEditor(text: $sessionNotes)
                .foregroundColor(.white)
                .background(textFieldBackground)
                .cornerRadius(8)
                .frame(minHeight: 80)
                .padding(.horizontal, 4)
            
            Button("Save Note") {
                saveNote()
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.cyan)
            .cornerRadius(8)
            
            Text("Past Session Notes")
                .font(.headline)
                .foregroundColor(accentCyan)
            
            ScrollView {
                ForEach(pastSessionNotes.indices, id: \.self) { i in
                    Text(pastSessionNotes[i])
                        .foregroundColor(.white)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
                        .padding(.vertical, 2)
                }
            }
            
            Spacer()
        }
    }
    
    private func saveNote() {
        guard !sessionNotes.isEmpty else { return }
        pastSessionNotes.insert(sessionNotes, at: 0)
        sessionNotes = ""
    }
}

// MARK: - AddCustomTimeView
fileprivate struct AddCustomTimeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var customTimeString: String = ""
    
    var onSave: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add a Custom Time (minutes)")
                .font(.headline)
                .foregroundColor(.cyan)
            
            TextField("e.g. 30", text: $customTimeString)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(white: 0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
            
            Button("Save") {
                guard let minutes = Int(customTimeString), minutes > 0 else { return }
                onSave(minutes)
                dismiss()
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.cyan)
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

// MARK: - HolographicButtonStyle
fileprivate struct HolographicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.cyan, lineWidth: 1)
                    .shadow(color: .cyan, radius: configuration.isPressed ? 1 : 3)
                    .blendMode(.plusLighter)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

// MARK: - Preview
struct HabitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a sample habit
        let sampleHabit = Habit(
            title: "Daily Coding",
            description: "Spend 30 minutes on coding challenges or project.",
            startDate: Date(),
            ownerId: "mockOwner"
        )
        
        NavigationView {
            HabitDetailView(habit: sampleHabit)
                .environmentObject(HabitViewModel())
        }
        .preferredColorScheme(.dark)
    }
}


