//
//  MonthView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.


import SwiftUI
import Combine
import Firebase
import FirebaseFirestore
import UIKit

// MARK: – Focus Field Identifier
private enum Field: Hashable {
    case monthlyPriority(UUID)
}

// MARK: – Month View  ▸  “Your Mindful Month”
struct MonthView: View {
    // ── injected ───────────────────────────────────────────────
    let accentColor: Color
    let accountCreationDate: Date

    @EnvironmentObject var monthViewState: MonthViewState
    @EnvironmentObject var session:      SessionStore
    @EnvironmentObject var habitVM:      HabitViewModel

    // ── vm & UI state ──────────────────────────────────────────
    @StateObject private var viewModel = MonthViewModel()

    @State private var selectedDay: Date? = nil
    @State private var showDaySummary   = false
    @State private var isRemoveMode     = false
    @State private var showCopyAlert    = false
    @State private var priorityToDelete: MonthlyPriority?

    @FocusState private var focusedField: Field?

    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    private let coolGray   = Color(red: 1.0, green: 0.45, blue: 0.45)

    // ───────────────────────────────────────────────────────────
    // MARK: ‑ Body
    // ───────────────────────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Copy‑previous‑month
                HStack {
                    Spacer()
                    Button("Copy from Previous Month") { showCopyAlert = true }
                        .font(.headline)
                        .foregroundColor(accentColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                    Spacer()
                }
                .alert("Confirm Copy",
                       isPresented: $showCopyAlert) {
                    Button("Copy",  role: .destructive) { copyFromPreviousMonth() }
                    Button("Cancel", role: .cancel)     { }
                } message: {
                    Text("Are you sure you want to copy the previous month's schedule?")
                }

                prioritiesSection
                calendarSection
                    .frame(height: 300)

                Spacer()
            }
            .padding()
            .padding(.top, -20)
            .overlay(daySummaryOverlay)          // floating overlay
        }
        // no toolbar here – uses SchedulerView’s global one
        .onAppear(perform: loadDataOnce)
        .navigationTitle("Your Month")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Monthly Priorities
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Priorities")
                .font(.headline)
                .foregroundColor(accentColor)

            if let sched = viewModel.schedule {
                let priorities = Binding<[MonthlyPriority]>(
                    get: { sched.monthlyPriorities },
                    set: { new in
                        var tmp = sched; tmp.monthlyPriorities = new
                        viewModel.schedule = tmp
                        viewModel.updateMonthSchedule()
                    }
                )

                ForEach(priorities) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .focused($focusedField, equals: .monthlyPriority(priority.id))
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .cornerRadius(8)
                            .onChange(of: priority.title) { _ in
                                viewModel.updateMonthSchedule()
                            }

                        if isRemoveMode && priorities.wrappedValue.count > 1 {
                            Button { priorityToDelete = priority } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .alert(item: $priorityToDelete) { pr in
                    Alert(
                        title: Text("Delete Priority"),
                        message: Text("Are you sure you want to delete “\(pr.title)” ?"),
                        primaryButton: .destructive(Text("Delete")) {
                            priorities.wrappedValue.removeAll { $0.id == pr.id }
                            if priorities.wrappedValue.count <= 1 { isRemoveMode = false }
                            viewModel.updateMonthSchedule()
                        },
                        secondaryButton: .cancel()
                    )
                }

                HStack {
                    Button("Add Priority") {
                        var tmp = sched
                        tmp.monthlyPriorities.append(
                            MonthlyPriority(id: UUID(), title: "New Priority", progress: 0)
                        )
                        viewModel.schedule = tmp
                        viewModel.updateMonthSchedule()
                        isRemoveMode = false
                    }
                    .font(.headline)
                    .foregroundColor(accentCyan)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)

                    Spacer()

                    if priorities.wrappedValue.count > 1 {
                        Button(isRemoveMode ? "Done" : "Remove Priority") {
                            isRemoveMode.toggle()
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 8)

            } else {
                Text("Loading monthly priorities…").foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // MARK: – Calendar
    private var calendarSection: some View {
        CalendarView(
            currentMonth: $monthViewState.currentMonth,
            accountCreationDate: accountCreationDate
        ) { day in
            if day <= Date() {
                selectedDay = day
                withAnimation { showDaySummary = true }
            }
        }
        .onChange(of: monthViewState.currentMonth) { newMonth in
            if let uid = session.userModel?.id {
                viewModel.loadMonthSchedule(for: newMonth, userId: uid)
            }
        }
    }

    // MARK: – Floating Day‑summary overlay
    @ViewBuilder
    private var daySummaryOverlay: some View {
        if showDaySummary, let day = selectedDay {
            VStack {
                DaySummaryView(
                    day: day,
                    habits: $habitVM.habits,
                    onClose: { withAnimation { showDaySummary = false } }
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

    // MARK: – Data loading
    private func loadDataOnce() {
        let now  = Date()
        let last = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 {
            monthViewState.currentMonth = MonthViewState.startOfMonth(for: now)
        }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")

        if let uid = session.userModel?.id {
            viewModel.loadMonthSchedule(for: monthViewState.currentMonth, userId: uid)
            habitVM.fetchHabits(for: uid)
        }
    }

    // MARK: – Copy previous month helper
    private func copyFromPreviousMonth() {
        guard let uid = session.userModel?.id,
              let curr = viewModel.schedule,
              let prev = Calendar.current.date(byAdding: .month, value: -1,
                                               to: monthViewState.currentMonth)
        else { return }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
        let docId = fmt.string(from: prev)

        Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(docId)
            .getDocument { snap, err in
                guard let snap = snap, snap.exists, err == nil,
                      let prevSched = try? snap.data(as: MonthSchedule.self) else { return }
                DispatchQueue.main.async {
                    var updated = curr
                    updated.monthlyPriorities = prevSched.monthlyPriorities
                    viewModel.schedule = updated
                    viewModel.updateMonthSchedule()
                }
            }
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
            // ... header omitted for brevity ...
            
            // Weekday headers
            HStack {
                ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { maybeDate in
                    if let date = maybeDate {
                        let dayNorm = Calendar.current.startOfDay(for: date)
                        let creationNorm = Calendar.current.startOfDay(for: accountCreationDate)
                        
                        if dayNorm < creationNorm {
                            // Before account creation → greyed out, no tap
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.gray)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(4)
                        }
                        else if date > Date() {
                            // Future dates
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.white)
                                .background(Color.gray)
                                .cornerRadius(4)
                        } else {
                            // Active dates
                            let completion = completionForDay(dayNorm)
                            let bgColor: Color = {
                                if completion == 1.0 {
                                    Color.green.opacity(0.6)
                                } else if completion > 0 {
                                    Color.yellow.opacity(0.6)
                                } else {
                                    coolGray.opacity(0.6)
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
