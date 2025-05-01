//
//  MonthView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine
import Firebase
import FirebaseFirestore

// MARK: - Month View ("Your Mindful Month")
struct MonthView: View {
    let accentColor: Color
    let accountCreationDate: Date

    // Replace local state with environment object
    @EnvironmentObject var monthViewState: MonthViewState
    
    // If your app can handle user sessions:
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var habitVM: HabitViewModel
    
    @State private var selectedDay: Date? = nil
    @State private var showDaySummary: Bool = false

    @StateObject private var viewModel = MonthViewModel()
    
    @State private var isRemoveMode: Bool = false
    // New state variable to control the prompt for copying from the previous month.
    @State private var showMonthCopyAlert: Bool = false
    
    @State private var monthlyPriorityToDelete: MonthlyPriority?
    
    let accentCyan      = Color(red: 0, green: 1, blue: 1)
    
    let coolGray = Color(red: 1.0, green: 0.45, blue: 0.45)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Copy Button Row
                HStack {
                    Spacer()
                    Button(action: {
                        // Show the alert confirmation.
                        showMonthCopyAlert = true
                    }) {
                        Text("Copy from Previous Month")
                            .font(.headline)
                            .foregroundColor(accentColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .alert(isPresented: $showMonthCopyAlert) {
                    Alert(
                        title: Text("Confirm Copy"),
                        message: Text("Are you sure you want to copy the previous month's schedule?"),
                        primaryButton: .destructive(Text("Copy")) {
                            copyFromPreviousMonth()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                // Monthly Priorities Section
                prioritiesSection
                
                // Calendar Section
                calendarSection
                    .frame(height: 300)
                
                Spacer()
            }
            .padding()
            .padding(.top, -20)
            .overlay(
                Group {
                    if showDaySummary, let day = selectedDay {
                        VStack {
                            DaySummaryView(
                                day: day,
                                habits: $habitVM.habits,
                                onClose: {
                                    withAnimation {
                                        showDaySummary = false
                                    }
                                }
                            )
                            .cornerRadius(12)
                        }
                        .frame(maxWidth: 300)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .transition(.opacity)
                    }
                }
            )
            .onAppear {
                // Inactivity check – if > 30 minutes, reset to the current month.
                let now = Date()
                let lastActive = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
                if now.timeIntervalSince(lastActive) > 1800 {
                    monthViewState.currentMonth = MonthViewState.startOfMonth(for: Date())
                }
                UserDefaults.standard.set(now, forKey: "LastActiveTime")
                
                if let userId = session.userModel?.id {
                    viewModel.loadMonthSchedule(for: monthViewState.currentMonth, userId: userId)
                    habitVM.fetchHabits(for: userId)
                }
            }
        }
    }
    
    // MARK: - Monthly Priorities Section (unchanged)
    private var prioritiesSection: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
            }
            if let schedule = viewModel.schedule {
                let bindingPriorities = Binding<[MonthlyPriority]>(
                    get: { schedule.monthlyPriorities },
                    set: { newValue in
                        var updatedSchedule = schedule
                        updatedSchedule.monthlyPriorities = newValue
                        viewModel.schedule = updatedSchedule
                        viewModel.updateMonthSchedule()
                    }
                )
                ForEach(bindingPriorities) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .cornerRadius(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .onChange(of: priority.title) { _ in
                                viewModel.updateMonthSchedule()
                            }
                        // Only show the delete button if removal mode is active and more than one priority.
                        if isRemoveMode && bindingPriorities.wrappedValue.count > 1 {
                            Button(action: {
                                monthlyPriorityToDelete = priority          // ← just set it; alert appears
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .alert(item: $monthlyPriorityToDelete) { priority in
                    Alert(
                        title: Text("Delete Priority"),
                        message: Text("Are you sure you want to delete “\(priority.title)” ?"),
                        primaryButton: .destructive(Text("Delete")) {
                            // Safe‑delete when confirmed
                            bindingPriorities.wrappedValue.removeAll { $0.id == priority.id }
                            if bindingPriorities.wrappedValue.count <= 1 { isRemoveMode = false }
                            viewModel.updateMonthSchedule()
                        },
                        secondaryButton: .cancel()
                    )
                }
            } else {
                Text("Loading monthly priorities...")
                    .foregroundColor(.white)
            }
            
            // Buttons row below the priorities list.
            HStack {
                Button(action: {
                    guard var schedule = viewModel.schedule else { return }
                    let newPriority = MonthlyPriority(id: UUID(), title: "New Priority", progress: 0.0)
                    schedule.monthlyPriorities.append(newPriority)
                    viewModel.schedule = schedule
                    viewModel.updateMonthSchedule()
                    isRemoveMode = false
                }) {
                    Text("Add Priority")
                        .font(.headline)
                        .foregroundColor(accentCyan)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                if let schedule = viewModel.schedule, schedule.monthlyPriorities.count > 1 {
                    Button(action: {
                        isRemoveMode.toggle()
                    }) {
                        Text(isRemoveMode ? "Done" : "Remove Priority")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
    
    // MARK: - Copy Feature: Copy from Previous Month
    private func copyFromPreviousMonth() {
        // Ensure we have a userId and current schedule.
        guard let userId = session.userModel?.id,
              let currentSchedule = viewModel.schedule else { return }
        
        // Compute the previous month date from shared state.
        guard let prevMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: monthViewState.currentMonth) else {
            print("Error computing previous month date.")
            return
        }
        
        // Compute the document ID string for the previous month schedule.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"   // Must match your MonthSchedule ID format.
        let prevDocId = formatter.string(from: prevMonthDate)
        
        // Query Firestore for the previous month's schedule.
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("monthSchedules")
            .document(prevDocId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error loading previous month schedule: \(error)")
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    print("Previous month schedule not found.")
                    return
                }
                do {
                    let prevSchedule = try snapshot.data(as: MonthSchedule.self)
                    DispatchQueue.main.async {
                        var updatedSchedule = currentSchedule
                        // Copy the relevant data (e.g., priorities, intentions, and other fields if needed).
                        updatedSchedule.monthlyPriorities = prevSchedule.monthlyPriorities
                        viewModel.schedule = updatedSchedule
                        viewModel.updateMonthSchedule()
                    }
                } catch {
                    print("Error decoding previous month schedule: \(error)")
                }
            }
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        CalendarView(
            currentMonth: $monthViewState.currentMonth, // <-- use shared state
            accountCreationDate: accountCreationDate,
            onDaySelected: { day in
                // open day summary
                if day <= Date() {
                    selectedDay = day
                    showDaySummary = true
                }
            }
        )
        .onChange(of: monthViewState.currentMonth) { newMonth in
            // load monthly schedule whenever the user changes the month
            if let userId = session.userModel?.id {
                viewModel.loadMonthSchedule(for: newMonth, userId: userId)
            }
        }
    }
    
    private func addNewMonthlyPriority() {
        guard var schedule = viewModel.schedule else { return }
        let newPriority = MonthlyPriority(id: UUID(), title: "New Priority", progress: 0.0)
        schedule.monthlyPriorities.append(newPriority)
        viewModel.schedule = schedule
        viewModel.updateMonthSchedule()
    }
}


// MARK: - Calendar View
struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    var onDaySelected: (Date) -> Void = { _ in }
    
    @EnvironmentObject var habitVM: HabitViewModel
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let coolGray = Color(red: 1.0, green: 0.45, blue: 0.45)
    
    var body: some View {
        VStack {
            // Month header with navigation
            HStack {
                // ← back one month
                Button {
                    if canGoBack(),
                       let prev = Calendar.current.date(byAdding: .month,
                                                        value: -1,
                                                        to: currentMonth) {
                        currentMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor( canGoBack() ? .white : .gray )
                }

                Spacer()

                let avg = computeAverageCompletion()
                Text("\(monthYearString(from: currentMonth))  (\(Int(avg * 100))%)")
                    .foregroundColor(.white)
                    .font(.headline)

                Spacer()

                // → forward one month (always enabled)
                Button {
                    if let next = Calendar.current.date(byAdding: .month,
                                                        value: 1,
                                                        to: currentMonth) {
                        currentMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)

            
            Spacer()
            
            // Weekday headers
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { date in
                    if let date = date {
                        if date > Date() {
                            // Future dates
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.white)
                                .background(Color.gray)
                                .cornerRadius(4)
                        } else {
                            let normalizedDate = Calendar.current.startOfDay(for: date)
                            let completion = completionForDay(normalizedDate)
                            let bgColor: Color = {
                                if completion == 1.0 {
                                    return Color.green.opacity(0.6)
                                } else if completion > 0 {
                                    return Color.yellow.opacity(0.6)
                                } else {
                                    return coolGray.opacity(0.6)
                                }
                            }()
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.white)
                                .background(bgColor)
                                .cornerRadius(4)
                                .onTapGesture {
                                    onDaySelected(date)
                                }
                        }
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Computes the fraction of habits completed for a given day.
    private func completionForDay(_ day: Date) -> Double {
        let cal = Calendar.current
        let norm = cal.startOfDay(for: day)

        // Only habits whose startDate is on / before this calendar day
        let relevant = habitVM.habits.filter {
            cal.compare($0.startDate, to: norm, toGranularity: .day) != .orderedDescending
        }

        let done = relevant.filter { habit in
            habit.dailyRecords.contains { rec in
                cal.isDate(rec.date, inSameDayAs: norm) && ((rec.value ?? 0) > 0)
            }
        }.count

        let total = relevant.count
        return total > 0 ? Double(done) / Double(total) : 0.0
    }
    private func computeAverageCompletion() -> Double {
        let days = generateDays().compactMap { $0 }
        guard !days.isEmpty else { return 0 }
        let total = days.reduce(0) { (sum, day) -> Double in
            sum + completionForDay(day)
        }
        return total / Double(days.count)
    }
    
    private func canGoBack() -> Bool {
        guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return false }
        return prevMonth >= startOfMonth(for: accountCreationDate)
    }
    
    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func generateDays() -> [Date?] {
        var days: [Date?] = []
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return days }
        let firstDay = calendar.startOfDay(for: monthInterval.start)
        let weekday = calendar.component(.weekday, from: firstDay)
        
        // Leading blank days
        for _ in 1..<weekday {
            days.append(nil)
        }
        
        // Actual days
        var date = firstDay
        while date < monthInterval.end {
            days.append(date)
            if let next = calendar.date(byAdding: .day, value: 1, to: date) {
                date = next
            } else { break }
        }
        return days
    }
}

// MARK: - Day Summary View
struct DaySummaryView: View {
    let day: Date
    @Binding var habits: [Habit]
    let onClose: () -> Void
    
    @EnvironmentObject var viewModel: HabitViewModel
    private var cal: Calendar { .current }
    
    // UI state
    @State private var showMetricInput = false
    @State private var metricInput = ""
    @State private var habitBeingUpdated: Habit?
    
    private let coolGray = Color(red: 1.0, green: 0.45, blue: 0.45)
    
    // Helper: is the habit active on (or before) this day?
    private func isActive(_ habit: Habit) -> Bool {
        cal.compare(habit.startDate, to: day, toGranularity: .day) != .orderedDescending
    }
    
    // Filter once, reuse
    private var relevantHabits: [Habit] { habits.filter(isActive) }
    
    private var finishedCount: Int {
        relevantHabits.filter { cal.isDateCompleted(habit: $0, for: day) }.count
    }
    
    var body: some View {
        ZStack {
            summaryCard
            if showMetricInput { metricInputOverlay.transition(.opacity) }
        }
    }
    
    // ───── summary card ─────
    private var summaryCard: some View {
        VStack(spacing: 16) {
            Text("Summary for \(formattedDate(day))")
                .font(.headline)
                .foregroundColor(.white)
            
            // Progress section
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(finishedCount), total: Double(relevantHabits.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor()))
                    .padding(.bottom, 4)
                Text("Finished \(finishedCount) of \(relevantHabits.count) habits")
                    .font(.subheadline)
                    .foregroundColor(progressColor())
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            // Toggle list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(relevantHabits.enumerated()), id: \.element.id) { idx, habit in
                    Toggle(isOn: bindingForHabitCompletion(indexInAll: indexInHabitsArray(for: habit))) {
                        Text(habit.title).foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            Button("Close Summary") { onClose() }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    // ───── bindings & helpers ─────
    private func indexInHabitsArray(for habit: Habit) -> Int {
        habits.firstIndex(where: { $0.id == habit.id }) ?? 0
    }
    
    private func bindingForHabitCompletion(indexInAll idx: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                cal.isDateCompleted(habit: habits[idx], for: day)
            },
            set: { newValue in
                if newValue {
                    habitBeingUpdated = habits[idx]
                    showMetricInput = true
                } else {
                    var updated = habits[idx]
                    updated.dailyRecords.removeAll { rec in
                        cal.isDate(rec.date, inSameDayAs: day)
                    }
                    habits[idx] = updated
                    viewModel.updateHabit(updated)
                }
            }
        )
    }
    
    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
    
    private func progressColor() -> Color {
        if relevantHabits.isEmpty { return coolGray }
        if finishedCount == relevantHabits.count { return .green }
        if finishedCount > 0 { return .yellow }
        return coolGray
    }
    
    // ───── metric input overlay & prompt  (unchanged) ─────
    private var metricInputOverlay: some View {
        let prompt = metricPrompt()
        return VStack(spacing: 16) {
            Text(prompt)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            TextField("Enter a number", text: $metricInput)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
            
            if !metricInput.isEmpty {
                if let habit = habitBeingUpdated, habit.metricType.isCompletedMetric() {
                    if metricInput != "0" && metricInput != "1" {
                        Text("Please enter either 0 (No) or 1 (Yes)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else if Int(metricInput) == nil {
                    Text("Please enter a valid number")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Button("Cancel") {
                    withAnimation {
                        showMetricInput = false
                        metricInput = ""
                        habitBeingUpdated = nil
                    }
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Save") {
                    if let val = Int(metricInput),
                       let h = habitBeingUpdated,
                       let idx = habits.firstIndex(where: { $0.id == h.id }) {
                        var updated = habits[idx]
                        updated.dailyRecords.append(HabitRecord(date: day, value: Double(val)))
                        habits[idx] = updated
                        viewModel.updateHabit(updated)
                        withAnimation {
                            showMetricInput = false
                            metricInput = ""
                            habitBeingUpdated = nil
                        }
                    }
                }
                .disabled({
                    if let h = habitBeingUpdated, h.metricType.isCompletedMetric() {
                        return !(metricInput == "0" || metricInput == "1")
                    } else {
                        return Int(metricInput) == nil
                    }
                }())
                .foregroundColor(.green)
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    private func metricPrompt() -> String {
        guard let habit = habitBeingUpdated else { return "Enter a metric value:" }
        switch habit.metricType {
        case .predefined(let v): return predefinedPrompt(for: v)
        case .custom(let v):     return "Enter this day's \(v.lowercased()) value:"
        }
    }
    private func predefinedPrompt(for value: String) -> String {
        let lower = value.lowercased()
        if lower.contains("minute")   { return "How many minutes did you meditate this day?" }
        if lower.contains("mile")     { return "How many miles did you run this day?" }
        if lower.contains("page")     { return "How many pages did you read this day?" }
        if lower.contains("rep")      { return "How many reps did you complete this day?" }
        if lower.contains("step")     { return "How many steps did you take this day?" }
        if lower.contains("calorie")  { return "How many calories did you burn/consume this day?" }
        if lower.contains("hour")     { return "How many hours did you sleep this day?" }
        if lower.contains("completed"){ return "Were you able to complete the task? (1 = Yes, 0 = No)" }
        return "Enter this day's \(lower) value:"
    }
}


// MARK: - Calendar Extension
extension Calendar {
    func isDateCompleted(habit: Habit, for day: Date) -> Bool {
        return habit.dailyRecords.contains { record in
            self.isDate(record.date, inSameDayAs: day) && ((record.value ?? 0) > 0)
        }
    }
}
