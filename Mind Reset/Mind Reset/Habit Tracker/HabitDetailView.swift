//
//  HabitDetailView.swift
//  Mind Reset
//  Objective: Displays details/stats of a single habit (streak, timers, notes, etc.)
//  Created by Andika Yudhatrisna on 1/3/25.
//

import SwiftUI
import Combine

struct HabitDetailView: View {
    // MARK: - The Habit Being Displayed
    @Binding var habit: Habit

    // Access your HabitViewModel
    @EnvironmentObject var viewModel: HabitViewModel

    // MARK: - Dismiss Environment for Navigation Back
    @Environment(\.presentationMode) var presentationMode

    // Access SessionStore to get current user
    @EnvironmentObject var session: SessionStore

    // MARK: - Editable Local Fields
    @State private var editableTitle: String
    @State private var editableDescription: String

    // MARK: - Tabs
    @State private var selectedTabIndex: Int = 0  // 0=Focus, 1=Progress, 2=Notes

    // MARK: - Timer States
    @State private var countdownSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var isTimerRunning = false
    @State private var isTimerPaused  = false

    // For demonstration, track totalFocusTime
    @State private var totalFocusTime: Int = 0

    // The user picks hours/min for a custom countdown
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0

    // Notes
    @State private var sessionNotes: String = ""
    @State private var pastSessionNotes: [String] = []

    // Long-term goal
    @State private var longTermGoal: String = ""

    // For transitions/animations if desired
    @Namespace private var animation
    @State private var showCharts: Bool = false

    // MARK: - Colors & Layout
    let backgroundBlack     = Color.black
    let accentCyan          = Color(red: 0, green: 1, blue: 1)
    let textFieldBackground = Color(red: 0.15, green: 0.15, blue: 0.15)

    // MARK: - Local Streak Tracking
    // A local dictionary that is *only* for this detail screen to show immediate changes.
    @State private var localStreaks: [String: Int] = [:]

    // MARK: - Combine Subscriptions
    @State private var cancellables: Set<AnyCancellable> = []

    // MARK: - Init
    init(habit: Binding<Habit>) {
        self._habit = habit
        _editableTitle       = State(initialValue: habit.wrappedValue.title)
        _editableDescription = State(initialValue: habit.wrappedValue.description)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundBlack.ignoresSafeArea()

            // Main Scrollable Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {

                    // Top Bar: Back + Editable Title
                    HStack {
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(accentCyan)
                                .font(.title2)
                        }

                        Spacer()

                        // Editable Title
                        TextField("Habit Title", text: $editableTitle)
                            .multilineTextAlignment(.center)
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .disableAutocorrection(true)

                        Spacer()
                        Spacer().frame(width: 40)
                    }

                    // Editable Description
                    TextField("Habit Description", text: $editableDescription)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)

                    // Long-Term Goal
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goals Related to Habit:")
                            .foregroundColor(accentCyan)
                            .font(.headline)

                        ZStack(alignment: .topLeading) {
                            if longTermGoal.isEmpty {
                                Text("e.g. Read 50 books by the end of the year")
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.top, 8)
                            }
                            TextEditor(text: $longTermGoal)
                                .foregroundColor(.white)
                                .accentColor(accentCyan)
                                .padding(8)
                                .background(textFieldBackground)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(accentCyan.opacity(0.6), lineWidth: 1)
                                )
                                .frame(minHeight: 60, maxHeight: 200)
                                .scrollContentBackground(.hidden)
                        }
                    }

                    // Segmented Tabs for Focus / Progress / Notes
                    Picker("Tabs", selection: $selectedTabIndex) {
                        Text("Focus").tag(0)
                        Text("Progress").tag(1)
                        Text("Notes").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .tint(.gray)
                    .background(.gray)
                    .cornerRadius(8)
                    .padding(.horizontal, 10)

                    // Subview per selectedTabIndex
                    Group {
                        switch selectedTabIndex {
                        case 0:
                            focusTab
                        case 1:
                            progressTab
                        default:
                            notesTab
                        }
                    }

                    // Mark Habit as Done
                    Button {
                        toggleHabitDone()
                    } label: {
                        Text(habit.isCompletedToday ? "Unmark Habit as Done" : "Mark Habit as Done")
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.isCompletedToday ? Color.red : .cyan)
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 30)
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let userId = session.current_user?.uid else {
                print("No authenticated user found.")
                return
            }
            // 1) Fetch existing habits
            viewModel.fetchHabits(for: userId)
            // 2) Setup defaults if needed
            viewModel.setupDefaultHabitsIfNeeded(for: userId)

            // Then do a daily reset check & init local streaks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.dailyResetIfNeeded()
                initializeLocalStreaks()
            }

            // Observe changes in habits to possibly re-init localStreaks
            viewModel.$habits
                .sink { _ in
                    self.initializeLocalStreaks()
                }
                .store(in: &cancellables)
        }
        .onChange(of: selectedHours) { _ in
            if !isTimerRunning && !isTimerPaused {
                countdownSeconds = selectedHours * 3600 + selectedMinutes * 60
            }
        }
        .onChange(of: selectedMinutes) { _ in
            if !isTimerRunning && !isTimerPaused {
                countdownSeconds = selectedHours * 3600 + selectedMinutes * 60
            }
        }
        .onDisappear {
            saveEditsToHabit()
        }
    }
}

// MARK: - Subviews & Timer Logic
extension HabitDetailView {
    // MARK: Focus Tab
    private var focusTab: some View {
        VStack(spacing: 16) {
            let habitID = habit.id ?? UUID().uuidString
            // We'll fetch local streak from localStreaks or habit.currentStreak
            let localStreakValue = localStreaks[habitID] ?? habit.currentStreak

            ZStack {
                Circle()
                    .stroke(accentCyan.opacity(0.2), lineWidth: 10)
                    .frame(width: 180, height: 180)
                    .shadow(color: accentCyan.opacity(0.4), radius: 5)

                // Countdown in mm:ss
                Text(formatTime(countdownSeconds))
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            // Only show if not currently running or paused
            if !isTimerRunning && !isTimerPaused {
                HStack(spacing: 20) {
                    timePickerBlock(label: "HRS", range: 0..<24, selection: $selectedHours)
                    timePickerBlock(label: "MIN", range: 0..<60, selection: $selectedMinutes)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(accentCyan.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: accentCyan.opacity(0.3), radius: 5)
                )
            }

            // Timer Buttons
            HStack(spacing: 20) {
                if !isTimerRunning && !isTimerPaused {
                    Button("Start") {
                        if countdownSeconds == 0 {
                            countdownSeconds = selectedHours * 3600 + selectedMinutes * 60
                        }
                        startTimer()
                    }
                    .buttonStyle(HolographicButtonStyle())
                } else if isTimerRunning && !isTimerPaused {
                    Button("Pause") { pauseTimer() }
                        .buttonStyle(HolographicButtonStyle())
                    Button("Reset") { resetTimer() }
                        .buttonStyle(HolographicButtonStyle())
                } else if isTimerPaused {
                    Button("Resume") { startTimer() }
                        .buttonStyle(HolographicButtonStyle())
                    Button("Reset") { resetTimer() }
                        .buttonStyle(HolographicButtonStyle())
                }
            }

            // Display Streak Info
            HStack {
                Text("Focused: \(formatTime(totalFocusTime))")
                    .foregroundColor(.white)
            }
        }
    }

    private func timePickerBlock(label: String, range: Range<Int>, selection: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .foregroundColor(accentCyan)
                .font(.subheadline)

            Picker(label, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)")
                        .foregroundColor(.white)
                        .font(.title3.monospacedDigit())
                }
            }
            .labelsHidden()
            .frame(width: 45, height: 80)
            .compositingGroup()
            .clipped()
            .pickerStyle(WheelPickerStyle())
        }
    }

    // MARK: Progress Tab
    private var progressTab: some View {
        VStack(spacing: 16) {
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
                // Possibly show details or expanded view
            }
            .foregroundColor(accentCyan)
        }
    }

    // MARK: Notes Tab
    private var notesTab: some View {
        VStack(spacing: 16) {
            Text("Session Notes")
                .font(.headline)
                .foregroundColor(accentCyan)

            TextEditor(text: $sessionNotes)
                .foregroundColor(.white)
                .background(textFieldBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentCyan.opacity(0.6), lineWidth: 1)
                )
                .frame(minHeight: 80)
                .padding(.horizontal, 4)
                .scrollContentBackground(.hidden)

            Button("Save Note") {
                saveNote()
            }
            .foregroundColor(.black)
            .padding()
            .background(accentCyan)
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
                        .scrollContentBackground(.hidden)
                }
            }
        }
    }
}

// MARK: - Timer Logic
extension HabitDetailView {
    private func startTimer() {
        guard !isTimerRunning || isTimerPaused else { return }

        isTimerRunning = true
        isTimerPaused  = false

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownSeconds > 0 {
                countdownSeconds -= 1
                totalFocusTime   += 1
            } else {
                timer?.invalidate()
                isTimerRunning = false
            }
        }
    }

    private func pauseTimer() {
        guard isTimerRunning && !isTimerPaused else { return }
        isTimerPaused = true
        timer?.invalidate()
    }

    private func resetTimer() {
        timer?.invalidate()
        countdownSeconds = 0
        isTimerRunning   = false
        isTimerPaused    = false

        selectedHours   = 0
        selectedMinutes = 0
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Habit Update & Edits
extension HabitDetailView {
    /// Toggles the habit's completion instantly in the localStreak dictionary, then calls `viewModel.toggleHabitCompletion`.
    private func toggleHabitDone() {
        guard let habitID = habit.id else { return }

        // 1) Get localStreak or fallback to habit.currentStreak
        let localVal = localStreaks[habitID] ?? habit.currentStreak

        // 2) Update the localStreak dict immediately
        if habit.isCompletedToday {
            localStreaks[habitID] = max(localVal - 1, 0)
        } else {
            localStreaks[habitID] = localVal + 1
        }

        // 3) Call the official toggle method on the VM
        viewModel.toggleHabitCompletion(habit, userId: habit.ownerId)
    }

    /// Save any title/description changes to Firestore
    private func saveEditsToHabit() {
        guard editableTitle != habit.title || editableDescription != habit.description else {
            return
        }
        habit.title       = editableTitle
        habit.description = editableDescription
        viewModel.updateHabit(habit)
    }
}

// MARK: - Notes
extension HabitDetailView {
    private func saveNote() {
        guard !sessionNotes.isEmpty else { return }
        pastSessionNotes.insert(sessionNotes, at: 0)
        sessionNotes = ""
    }
}

// MARK: - Local Streak Initialization
extension HabitDetailView {
    private func initializeLocalStreaks() {
        guard let habitID = habit.id else { return }

        // If lastReset was today, do nothing
        if let lastReset = habit.lastReset, Calendar.current.isDateInToday(lastReset) {
            // no new day needed
        } else {
            // It's a "new day," so ensure localStreak is at least the habit's currentStreak
            localStreaks[habitID] = max(localStreaks[habitID] ?? 0, habit.currentStreak)
        }
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
        let sampleHabit = Habit(
            id: "sampleHabitId",
            title: "Daily Coding",
            description: "Review Swift concepts",
            startDate: Date(),
            ownerId: "testOwner",
            isCompletedToday: true,
            lastReset: nil,
            points: 100,
            currentStreak: 5,
            longestStreak: 10,
            weeklyStreakBadge: false,
            monthlyStreakBadge: false,
            yearlyStreakBadge: false
        )

        // Create a Binding for the sample habit
        let habitBinding = Binding<Habit>(
            get: { sampleHabit },
            set: { newValue in
                // For preview purposes, no-op
                print("Habit updated in preview.")
            }
        )

        NavigationView {
            HabitDetailView(habit: habitBinding)
                .environmentObject(HabitViewModel())
        }
        .preferredColorScheme(.dark)
    }
}
