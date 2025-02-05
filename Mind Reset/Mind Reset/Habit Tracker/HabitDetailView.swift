//
//  HabitDetailView.swift
//  Mind Reset
//
//  Displays details/stats for a single habit. Includes a custom overlay pop-up for
//  picking real weeks (Sunday–Saturday) or real months, while keeping the habit
//  screen visible underneath (tinted white).
//
//  Uses real data from habit.dailyRecords for weekly and monthly views.
//  Now includes "Current Week" or "Current Month" label above the picker.
//  Also fetches and saves session notes from Firestore.
//  A new "View Previous Notes" button launches a separate view that displays
//  all previously saved session notes in an accessible and clean format.
//
//  Created by Andika Yudhatrisna on 1/3/25.
//
 
import SwiftUI
import Combine
import FirebaseFirestore

struct HabitDetailView: View {
    // MARK: - The Habit Being Displayed
    @Binding var habit: Habit

    // MARK: - Environment & Dependencies
    @EnvironmentObject var viewModel: HabitViewModel
    @EnvironmentObject var session: SessionStore
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Editable Local Fields
    @State private var editableTitle: String
    @State private var editableDescription: String

    // MARK: - Tabs (Focus, Progress, Notes)
    @State private var selectedTabIndex: Int = 0  // 0=Focus, 1=Progress, 2=Notes

    // MARK: - Timer States
    @State private var countdownSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var isTimerRunning = false
    @State private var isTimerPaused  = false

    // Track totalFocusTime if you want to log focus minutes
    @State private var totalFocusTime: Int = 0

    // Countdown pickers
    @State private var selectedHours: Int   = 0
    @State private var selectedMinutes: Int = 0

    // MARK: - Notes
    @State private var sessionNotes: String   = ""
    // This array holds new notes locally if needed; previous notes are now viewed via the new view.
    @State private var pastSessionNotes: [UserNote] = []

    // MARK: - Habit Goal
    @State private var goal: String

    // MARK: - Additional UI
    @Namespace private var animation
    @State private var showCharts: Bool = false
    // New state to control presenting the previous notes view.
    @State private var showPreviousNotes: Bool = false

    // MARK: - Styling
    let backgroundBlack     = Color.black
    let accentCyan          = Color(red: 0, green: 1, blue: 1)
    let textFieldBackground = Color(red: 0.15, green: 0.15, blue: 0.15)

    // MARK: - Local Streak Tracking
    @State private var localStreaks: [String: Int]       = [:]
    @State private var localLongestStreaks: [String: Int] = [:]

    // MARK: - Combine
    @State private var cancellables: Set<AnyCancellable> = []

    // MARK: - Time Range
    fileprivate enum TimeRange {
        case weekly, monthly
    }
    @State private var selectedTimeRange: TimeRange = .weekly

    // For switching "weeks" or "months" in the progress view
    @State private var weekOffset: Int = 0
    @State private var monthOffset: Int = 0

    // Instead of a .sheet, we do a custom overlay pop-up
    @State private var showDateRangeOverlay = false

    // MARK: - Initialization
    init(habit: Binding<Habit>) {
        _habit               = habit
        _editableTitle       = State(initialValue: habit.wrappedValue.title)
        _editableDescription = State(initialValue: habit.wrappedValue.description)
        _goal                = State(initialValue: habit.wrappedValue.goal)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Main content behind
            mainContent

            // Custom overlay pop-up for date range
            if showDateRangeOverlay {
                Color.white
                    .opacity(0.9)
                    .ignoresSafeArea()
                dateRangeOverlayView
                    .transition(.scale)
            }
        }
        .onAppear {
            guard let userId = session.current_user?.uid else {
                print("No authenticated user found.")
                return
            }
            viewModel.fetchHabits(for: userId)
            viewModel.setupDefaultHabitsIfNeeded(for: userId)
            initializeLocalStreaks()
            
            // Sync local 'goal' from the actual habit
            goal = habit.goal

            // Observe changes
            viewModel.$habits
                .sink { _ in
                    initializeLocalStreaks()
                }
                .store(in: &cancellables)
            
            // Fetch saved user notes from Firestore for this habit.
            // (These notes can be reloaded in the new view.)
            fetchUserNotes()
        }
        .onDisappear { saveEditsToHabit() }
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
        // Present the PreviousNotesView as a sheet when requested.
        .sheet(isPresented: $showPreviousNotes) {
            PreviousNotesView(habitID: habit.id ?? "")
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack {
            backgroundBlack.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {
                    // Top Bar
                    topBarSection

                    // Editable Description
                    TextEditor(text: $editableDescription)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                        .disableAutocorrection(true)
                        .scrollContentBackground(.hidden)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                        .frame(minHeight: 50)
                        .overlay(
                            Group {
                                if editableDescription.isEmpty {
                                    Text("Habit Description")
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 2)
                                }
                            }, alignment: .topLeading
                        )

                    // Goal Section
                    goalSection

                    // Tabs (Focus, Progress, Notes)
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

                    // Tab Views
                    Group {
                        switch selectedTabIndex {
                        case 0: focusTab
                        case 1: progressTab
                        default: notesTab
                        }
                    }

                    // Mark Habit as Done Button
                    Button {
                        toggleHabitDone()
                    } label: {
                        Text(habit.isCompletedToday ? "Unmark Habit as Done" : "Mark Habit as Done")
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.isCompletedToday ? Color.red : accentCyan)
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 30)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - The custom dateRangeOverlayView
    @ViewBuilder
    private var dateRangeOverlayView: some View {
        VStack(spacing: 0) {
            Text(selectedTimeRange == .weekly ? "Select a Week" : "Select a Month")
                .font(.title3.weight(.semibold))
                .padding()
                .foregroundColor(.black)
            Divider()
            if selectedTimeRange == .weekly {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(realWeeks(), id: \.self) { interval in
                            let label = formatWeekInterval(interval)
                            Button {
                                weekOffset = computeWeekOffset(for: interval)
                                showDateRangeOverlay = false
                            } label: {
                                Text(label)
                                    .font(.callout)
                                    .foregroundColor(.black)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(realMonths(), id: \.self) { monthDate in
                            let label = formatMonth(monthDate)
                            Button {
                                monthOffset = computeMonthOffset(for: monthDate)
                                showDateRangeOverlay = false
                            } label: {
                                Text(label)
                                    .font(.callout)
                                    .foregroundColor(.black)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Divider()
            Button("Cancel") {
                showDateRangeOverlay = false
            }
            .font(.callout.weight(.semibold))
            .foregroundColor(.blue)
            .padding(.vertical, 12)
        }
        .background(Color.white.cornerRadius(12))
        .frame(width: 300, height: 400)
        .shadow(color: .gray.opacity(0.3), radius: 10)
    }
}

// MARK: - Subviews
extension HabitDetailView {
    // MARK: Top Bar + Title
    private var topBarSection: some View {
        HStack {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(accentCyan)
                    .font(.title2)
            }
            Spacer()
            TextField("Habit Title", text: $editableTitle)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: 200)
                .disableAutocorrection(true)
            Spacer()
            Spacer().frame(width: 40)
        }
    }

    // MARK: Goal Section
    private var goalSection: some View {
        VStack() {
            Text("Goal Related to Habit:")
                .foregroundColor(accentCyan)
                .font(.headline)
            ZStack(alignment: .topLeading) {
                if goal.isEmpty {
                    Text("e.g. Read 50 books by the end of the year")
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                }
                TextEditor(text: $goal)
                    .foregroundColor(.white)
                    .accentColor(accentCyan)
                    .padding(8)
                    .background(textFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(accentCyan.opacity(0.6), lineWidth: 1)
                    )
                    .frame(minHeight: 100, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: Focus Tab
    private var focusTab: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(accentCyan.opacity(0.2), lineWidth: 10)
                    .frame(width: 180, height: 180)
                    .shadow(color: accentCyan.opacity(0.4), radius: 5)
                Text(formatTime(countdownSeconds))
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
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
            HStack {
                Text("Focused: \(formatTime(totalFocusTime))")
                    .foregroundColor(.white)
            }
        }
    }

    // Timer pickers helper
    private func timePickerBlock(label: String, range: Range<Int>, selection: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .foregroundColor(accentCyan)
                .font(.subheadline)
            Picker(label, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)")
                        .font(.title3.monospacedDigit())
                        .foregroundColor(.white)
                }
            }
            .labelsHidden()
            .frame(width: 45, height: 80)
            .pickerStyle(WheelPickerStyle())
        }
    }
}

// MARK: - Button Label Helpers
extension HabitDetailView {
    private func navigationButtonLabel(title: String, isDisabled: Bool) -> some View {
        Text(title)
            .multilineTextAlignment(.center)
            .foregroundColor(isDisabled ? Color.gray : accentCyan)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Progress Tab
extension HabitDetailView {
    private var progressTab: some View {
        let userCreationDate = session.userModel?.createdAt ?? habit.startDate
        return VStack(spacing: 20) {
            if selectedTimeRange == .weekly {
                Text("Current Week: \(formatWeekInterval(currentWeekInterval(offset: weekOffset)))")
                    .foregroundColor(.white)
                    .font(.headline)
            } else {
                Text("Current Month: \(formatMonth(currentMonthDate(offset: monthOffset)))")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            Picker("Time Range", selection: $selectedTimeRange) {
                Text("Weekly").tag(TimeRange.weekly)
                Text("Monthly").tag(TimeRange.monthly)
            }
            .pickerStyle(SegmentedPickerStyle())
            .tint(.gray)
            .background(.gray)
            .cornerRadius(8)
            .padding(.horizontal, 10)
            if selectedTimeRange == .weekly {
                let (weekLabels, weekValues) = weeklyData(habit: habit, offset: weekOffset, userCreationDate: userCreationDate)
                SingleLineGraphView(
                    timeRange: .weekly,
                    dates: weekLabels,
                    intensities: weekValues,
                    accentColor: accentCyan
                )
                .frame(maxWidth: .infinity, minHeight: 300)
                .background(accentCyan.opacity(0.15))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                HStack(spacing: 20) {
                    Button {
                        if weekOffset > minWeekOffset {
                            weekOffset -= 1
                        }
                    } label: {
                        navigationButtonLabel(title: "Prev\nWeek", isDisabled: weekOffset <= minWeekOffset)
                    }
                    .disabled(weekOffset <= minWeekOffset)
                    Button {
                        showDateRangeOverlay = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.callout)
                            Text("Choose Week")
                                .font(.callout)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(.black)
                        .background(accentCyan)
                        .cornerRadius(6)
                    }
                    Button {
                        if weekOffset < maxWeekOffset {
                            weekOffset += 1
                        }
                    } label: {
                        navigationButtonLabel(title: "Next\nWeek", isDisabled: weekOffset >= maxWeekOffset)
                    }
                    .disabled(weekOffset >= maxWeekOffset)
                }
                .padding(.top, 10)
            } else {
                MonthlyCurrentMonthGridView(
                    accentColor: accentCyan,
                    offset: monthOffset,
                    dailyRecords: habit.dailyRecords,
                    userCreationDate: userCreationDate
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                HStack(spacing: 20) {
                    Button {
                        if monthOffset > minMonthOffset {
                            monthOffset -= 1
                        }
                    } label: {
                        navigationButtonLabel(title: "Prev\nMonth", isDisabled: monthOffset <= minMonthOffset)
                    }
                    .disabled(monthOffset <= minMonthOffset)
                    Button {
                        showDateRangeOverlay = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.callout)
                            Text("Choose Month")
                                .font(.callout)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(.black)
                        .background(accentCyan)
                        .cornerRadius(6)
                    }
                    Button {
                        if monthOffset < maxMonthOffset {
                            monthOffset += 1
                        }
                    } label: {
                        navigationButtonLabel(title: "Next\nMonth", isDisabled: monthOffset >= maxMonthOffset)
                    }
                    .disabled(monthOffset >= maxMonthOffset)
                }
                .padding(.top, 10)
            }
        }
        .padding(.top, 10)
    }
    
    private func weeklyData(habit: Habit, offset: Int, userCreationDate: Date) -> ([String], [CGFloat?]) {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var intensities: [CGFloat?] = Array(repeating: nil, count: 7)
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let distanceFromSunday = weekday - 1
        guard let startOfThisWeek = calendar.date(byAdding: .day, value: -distanceFromSunday + (offset * 7), to: now) else {
            return (dayLabels, intensities)
        }
        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: startOfThisWeek) else { continue }
            if dayDate < userCreationDate {
                intensities[i] = nil
                continue
            }
            if dayDate > now {
                intensities[i] = nil
                continue
            }
            if let record = habit.dailyRecords.first(where: { rec in
                calendar.isDate(rec.date, inSameDayAs: dayDate)
            }) {
                intensities[i] = record.value ?? 0
            } else {
                intensities[i] = 0
            }
        }
        return (dayLabels, intensities)
    }
}

// MARK: - Real Weeks/Months Helpers
extension HabitDetailView {
    private func realWeeks() -> [DateInterval] {
        let calendar = Calendar.current
        var results: [DateInterval] = []
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let distanceFromSunday = weekday - 1
        guard let startOfThisWeek = calendar.date(byAdding: .day, value: -distanceFromSunday, to: now) else {
            return results
        }
        for offset in minWeekOffset...maxWeekOffset {
            if let start = calendar.date(byAdding: .day, value: offset * 7, to: startOfThisWeek),
               let end = calendar.date(byAdding: .day, value: 6, to: start) {
                results.append(DateInterval(start: start, end: end))
            }
        }
        results.sort { $0.start < $1.start }
        return results
    }
    
    private func formatWeekInterval(_ interval: DateInterval) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: interval.start)
        let endStr   = fmt.string(from: interval.end)
        return "\(startStr) - \(endStr)"
    }
    
    private func computeWeekOffset(for interval: DateInterval) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let distanceFromSunday = weekday - 1
        guard let startOfThisWeek = calendar.date(byAdding: .day, value: -distanceFromSunday, to: now) else {
            return 0
        }
        let comps = calendar.dateComponents([.day], from: startOfThisWeek, to: interval.start)
        let dayDiff = comps.day ?? 0
        return dayDiff / 7
    }
    
    private func realMonths() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        var months: [Date] = []
        for offset in minMonthOffset...maxMonthOffset {
            if let shifted = calendar.date(byAdding: .month, value: offset, to: now) {
                months.append(shifted)
            }
        }
        return months.sorted()
    }
    
    private func formatMonth(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: date)
    }
    
    private func computeMonthOffset(for date: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.month], from: startOfMonth(now), to: startOfMonth(date))
        return comps.month ?? 0
    }
    
    private func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }
    
    private func currentWeekInterval(offset: Int) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let distanceFromSunday = weekday - 1
        guard let startOfThisWeek = calendar.date(byAdding: .day, value: -distanceFromSunday + (offset * 7), to: now),
              let end = calendar.date(byAdding: .day, value: 6, to: startOfThisWeek)
        else {
            return DateInterval(start: now, end: now)
        }
        return DateInterval(start: startOfThisWeek, end: end)
    }
    
    private func currentMonthDate(offset: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(byAdding: .month, value: offset, to: now) ?? now
    }
}

// MARK: - Notes Tab
extension HabitDetailView {
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
                .frame(minHeight: 150)
                .padding(.horizontal, 4)
                .scrollContentBackground(.hidden)
            
            Button("Save Note") {
                saveNote()
            }
            .foregroundColor(.black)
            .padding()
            .background(accentCyan)
            .cornerRadius(8)
            
            // New button to view previous notes in a separate view.
            Button("View Previous Notes") {
                showPreviousNotes = true
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
    }
    
    // Updated saveNote() to save to Firestore and then refresh the notes.
    private func saveNote() {
        guard !sessionNotes.isEmpty, let habitID = habit.id else { return }
        viewModel.saveUserNote(for: habitID, note: sessionNotes) { success in
            if success {
                DispatchQueue.main.async {
                    sessionNotes = ""
                    fetchUserNotes()
                }
            } else {
                print("Failed to save note for habitID: \(habitID)")
            }
        }
    }
    
    // Fetch notes from Firestore for this habit.
    private func fetchUserNotes() {
        guard let habitID = habit.id else { return }
        let db = Firestore.firestore()
        db.collection("UserNotes")
            .whereField("habitID", isEqualTo: habitID)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching notes: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let notes: [UserNote] = documents.compactMap { doc in
                    return try? doc.data(as: UserNote.self)
                }
                DispatchQueue.main.async {
                    self.pastSessionNotes = notes
                }
            }
    }
    
    // Helper to format a Date into a string.
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short  // e.g. "3/14/25"
        formatter.timeStyle = .short  // e.g. "2:45 PM"
        return formatter.string(from: date)
    }
    
    // Delete a note using the view model.
    private func deleteNote(_ note: UserNote) {
        viewModel.deleteUserNote(note: note) { success in
            if success {
                fetchUserNotes()
            } else {
                print("Failed to delete note with id: \(note.id ?? "unknown")")
            }
        }
    }
}

// MARK: - Timer & Habit Edits
extension HabitDetailView {
    private func startTimer() {
        guard !isTimerRunning || isTimerPaused else { return }
        isTimerRunning = true
        isTimerPaused  = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownSeconds > 0 {
                countdownSeconds -= 1
                totalFocusTime += 1
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
        isTimerRunning = false
        isTimerPaused = false
        selectedHours = 0
        selectedMinutes = 0
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func toggleHabitDone() {
        guard let habitID = habit.id else { return }
        let localVal = localStreaks[habitID] ?? habit.currentStreak
        if habit.isCompletedToday {
            localStreaks[habitID] = max(localVal - 1, 0)
        } else {
            localStreaks[habitID] = localVal + 1
        }
        viewModel.toggleHabitCompletion(habit, userId: habit.ownerId)
    }
    
    private func saveEditsToHabit() {
        guard editableTitle != habit.title ||
              editableDescription != habit.description ||
              goal != habit.goal
        else { return }
        habit.title = editableTitle
        habit.description = editableDescription
        habit.goal = goal
        viewModel.updateHabit(habit)
    }
}

// MARK: - Local Streak Initialization
extension HabitDetailView {
    private func initializeLocalStreaks() {
        guard let habitID = habit.id else { return }
        if let lastReset = habit.lastReset, Calendar.current.isDateInToday(lastReset) {
            // same day, do nothing
        } else {
            localStreaks[habitID] = max(localStreaks[habitID] ?? 0, habit.currentStreak)
        }
        localLongestStreaks[habitID] = max(localLongestStreaks[habitID] ?? 0, habit.longestStreak)
    }
}

// MARK: - Offset Calculations
extension HabitDetailView {
    private var minWeekOffset: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let accountWeekStart = calendar.dateInterval(of: .weekOfYear, for: session.userModel?.createdAt ?? now)?.start,
              let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return 0
        }
        let weeks = calendar.dateComponents([.weekOfYear], from: accountWeekStart, to: currentWeekStart).weekOfYear ?? 0
        return -weeks
    }
    
    private var maxWeekOffset: Int {
        return 0
    }
    
    private var minMonthOffset: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let accountMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: session.userModel?.createdAt ?? now)),
              let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return 0
        }
        let months = calendar.dateComponents([.month], from: accountMonthStart, to: currentMonthStart).month ?? 0
        return -months
    }
    
    private var maxMonthOffset: Int {
        return 0
    }
}



// MARK: - SingleLineGraphView
fileprivate struct SingleLineGraphView: View {
    let timeRange: HabitDetailView.TimeRange
    let dates: [String]
    let intensities: [CGFloat?]
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                let axisPadding: CGFloat = 20

                Path { p in
                    p.move(to: CGPoint(x: axisPadding, y: 0))
                    p.addLine(to: CGPoint(x: axisPadding, y: geo.size.height))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1)

                ForEach(0...5, id: \.self) { i in
                    let value = CGFloat(i) * 20
                    let y = yPosition(value, height: geo.size.height, maxValue: 100)

                    Path { path in
                        path.move(to: CGPoint(x: axisPadding, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)

                    Text("\(Int(value))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .position(x: axisPadding - 10, y: y)
                }

                SmoothLineShape(
                    values: intensities.compactMap { $0 },
                    maxValue: 100,
                    axisPadding: axisPadding
                )
                .stroke(
                    accentColor.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                ForEach(intensities.indices, id: \.self) { i in
                    if let intensity = intensities[i] {
                        let x = xPosition(i, width: geo.size.width, axisPadding: axisPadding)
                        let y = yPosition(intensity, height: geo.size.height, maxValue: 100)

                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)

                        Text("\(Int(intensity))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .position(x: x, y: y - 15)

                        if i < dates.count {
                            Text(dates[i])
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 30, alignment: .center)
                                .position(x: x, y: geo.size.height - 10)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func xPosition(_ idx: Int, width: CGFloat, axisPadding: CGFloat) -> CGFloat {
        guard intensities.count > 1 else {
            return axisPadding + width / 2
        }
        let usableWidth = width - axisPadding
        let step = usableWidth / CGFloat(intensities.count - 1)
        return axisPadding + CGFloat(idx) * step
    }

    private func yPosition(_ val: CGFloat, height: CGFloat, maxValue: CGFloat) -> CGFloat {
        let ratio = val / maxValue
        return height - (ratio * height)
    }
}

// MARK: - SmoothLineShape
fileprivate struct SmoothLineShape: Shape {
    let values: [CGFloat]
    let maxValue: CGFloat
    let axisPadding: CGFloat

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }

        let width = rect.width - axisPadding
        let stepX = width / CGFloat(values.count - 1)

        var path = Path()
        var isDrawing = false

        for (i, val) in values.enumerated() {
            let ratio = val / maxValue
            let px = axisPadding + CGFloat(i) * stepX
            let py = rect.height - (ratio * rect.height)
            let point = CGPoint(x: px, y: py)

            if !isDrawing {
                path.move(to: point)
                isDrawing = true
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

// MARK: - PreviousNotesView
fileprivate struct PreviousNotesView: View {
    let habitID: String
    @EnvironmentObject var viewModel: HabitViewModel
    @State private var notes: [UserNote] = []
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(notes) { note in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.noteText)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(formatTimestamp(note.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            viewModel.deleteUserNote(note: note) { success in
                                if success {
                                    fetchNotes()
                                } else {
                                    print("Failed to delete note with id: \(note.id ?? "unknown")")
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Previous Notes")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear(perform: fetchNotes)
        }
    }
    
    private func fetchNotes() {
        let db = Firestore.firestore()
        db.collection("UserNotes")
            .whereField("habitID", isEqualTo: habitID)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching notes: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let fetchedNotes: [UserNote] = documents.compactMap { doc in
                    return try? doc.data(as: UserNote.self)
                }
                DispatchQueue.main.async {
                    self.notes = fetchedNotes
                }
            }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium  // e.g., "Mar 14, 2025"
        formatter.timeStyle = .short   // e.g., "2:45 PM"
        return formatter.string(from: date)
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

// MARK: - MonthlyCurrentMonthGridView
fileprivate struct MonthlyCurrentMonthGridView: View {
    let accentColor: Color
    let offset: Int
    let dailyRecords: [HabitRecord]
    let userCreationDate: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(monthDayData(offset: offset), id: \.self) { item in
                    VStack(spacing: 4) {
                        Text(item.dayLabel)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))

                        if let intensity = item.intensity, intensity > 0 {
                            Image(systemName: "star.fill")
                                .foregroundColor(accentColor)
                                .font(.caption)
                        } else if item.intensity == nil {
                            Image(systemName: "star")
                                .foregroundColor(.gray)
                                .font(.caption)
                        } else {
                            Image(systemName: "star")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .frame(minHeight: 40)
                }
            }
            .padding()
        }
        .padding()
        .background(accentColor.opacity(0.15))
        .cornerRadius(8)
    }

    private func monthDayData(offset: Int) -> [DayData] {
        let calendar = Calendar.current
        let now = Date()
        guard let baseDate = calendar.date(byAdding: .month, value: offset, to: now),
              let range = calendar.range(of: .day, in: .month, for: baseDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate))
        else {
            return []
        }

        let daysInMonth = range.count
        var results: [DayData] = []
        for dayNum in 1...daysInMonth {
            guard let dayDate = calendar.date(byAdding: .day, value: dayNum - 1, to: startOfMonth) else { continue }

            if dayDate < userCreationDate {
                results.append(DayData(
                    date: dayDate,
                    dayLabel: "\(dayNum)",
                    intensity: nil
                ))
                continue
            }

            if dayDate > now {
                results.append(DayData(
                    date: dayDate,
                    dayLabel: "\(dayNum)",
                    intensity: nil
                ))
                continue
            }

            let record = dailyRecords.first(where: {
                calendar.isDate($0.date, inSameDayAs: dayDate)
            })
            let intensity: CGFloat? = record?.value.map { CGFloat($0) }

            results.append(DayData(
                date: dayDate,
                dayLabel: "\(dayNum)",
                intensity: intensity
            ))
        }
        return results
    }
}

fileprivate struct DayData: Hashable {
    let date: Date
    let dayLabel: String
    let intensity: CGFloat?
}
