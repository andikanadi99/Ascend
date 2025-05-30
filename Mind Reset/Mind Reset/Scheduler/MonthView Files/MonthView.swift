// MonthView.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine
import FirebaseFirestore
import UIKit

// MARK: – Focus Field Identifier
private enum Field: Hashable {
    case monthlyPriority(UUID)
}

struct MonthView: View {
    // ── injected ───────────────────────────────────────────────
    let accentColor: Color
    let accountCreationDate: Date

    @EnvironmentObject var monthViewState: MonthViewState
    @EnvironmentObject var session:      SessionStore
    @EnvironmentObject var habitVM:      HabitViewModel

    // ── local view-models & UI state ────────────────────────────────
    @StateObject private var viewModel = MonthViewModel()
    @State private var selectedDay: Date?
    @State private var showDaySummary   = false
    @State private var isRemoveMode     = false
    @State private var showCopyAlert    = false
    @State private var priorityToDelete: MonthlyPriority?
    @State private var editMode:        EditMode = .inactive

    @FocusState private var focusedField: Field?

    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    private let coolGray   = Color(red: 1.0, green: 0.45, blue: 0.45)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Copy-previous-month button
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
                    Button("Copy", role: .destructive) { copyFromPreviousMonth() }
                    Button("Cancel", role: .cancel)     { }
                } message: {
                    Text("Are you sure you want to copy the previous month's schedule?")
                }

                // Month navigation (arrows + title)
                MonthNavigationView(
                    currentMonth: $monthViewState.currentMonth,
                    accountCreationDate: accountCreationDate,
                    accentColor: accentColor
                )
                .onChange(of: monthViewState.currentMonth) { newMonth in
                    if let uid = session.userModel?.id {
                        viewModel.loadMonthSchedule(for: newMonth, userId: uid)
                    }
                }

                // ── Monthly Priorities Section ─────────────────────────────────
                MonthlyPrioritiesSection(
                    priorities: Binding(
                        get: {
                            viewModel.schedule?.monthlyPriorities ?? []
                        },
                        set: { new in
                            guard var sched = viewModel.schedule else { return }
                            sched.monthlyPriorities = new
                            viewModel.schedule = sched
                            viewModel.updateMonthSchedule()
                        }
                    ),
                    editMode:           $editMode,
                    accentColor:        accentCyan,
                    isRemoveMode:       isRemoveMode,
                    onToggleRemoveMode: { isRemoveMode.toggle() },
                    onToggle: { id in
                        guard var sched = viewModel.schedule,
                              let idx = sched.monthlyPriorities.firstIndex(where: { $0.id == id })
                        else { return }
                        sched.monthlyPriorities[idx].isCompleted.toggle()
                        viewModel.schedule = sched
                        viewModel.updateMonthSchedule()
                    },
                    onMove: { offsets, newOffset in
                        guard var sched = viewModel.schedule else { return }
                        sched.monthlyPriorities.move(fromOffsets: offsets, toOffset: newOffset)
                        viewModel.schedule = sched
                        viewModel.updateMonthSchedule()
                    },
                    onCommit: {
                        viewModel.updateMonthSchedule()
                    },
                    onDelete: { pr in
                        guard var sched = viewModel.schedule else { return }
                        sched.monthlyPriorities.removeAll { $0.id == pr.id }
                        viewModel.schedule = sched
                        viewModel.updateMonthSchedule()
                        if sched.monthlyPriorities.count <= 1 {
                            isRemoveMode = false
                        }
                    },
                    addAction: {
                        guard var sched = viewModel.schedule else { return }
                        sched.monthlyPriorities.append(
                            MonthlyPriority(
                                id: UUID(),
                                title: "New Priority",
                                progress: 0,
                                isCompleted: false
                            )
                        )
                        viewModel.schedule = sched
                        viewModel.updateMonthSchedule()
                        isRemoveMode = false
                    }
                )
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)

                // ── Calendar Section ───────────────────────────────────────────
                calendarSection
                    .frame(height: 300)

                Spacer()
            }
            .padding()
            .padding(.top, -20)
            .overlay(daySummaryOverlay)
        }
        .onAppear(perform: loadDataOnce)
        .navigationTitle("Your Month")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Calendar Section
    private var calendarSection: some View {
        CalendarView(
            currentMonth: $monthViewState.currentMonth,
            accountCreationDate: accountCreationDate,
            onDaySelected: { day in
                if day <= Date() {
                    selectedDay = day
                    withAnimation { showDaySummary = true }
                }
            }
        )
    }

    // MARK: – Day Summary Overlay
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

    // MARK: – Data Loading & Helpers
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

    private func copyFromPreviousMonth() {
        guard let uid = session.userModel?.id,
              let curr = viewModel.schedule,
              let prev = Calendar.current.date(byAdding: .month, value: -1, to: monthViewState.currentMonth)
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

// MARK: – Month Navigation View
private struct MonthNavigationView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    let accentColor: Color

    var body: some View {
        HStack {
            Button {
                if canGoBack(),
                   let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
                    currentMonth = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack() ? .white : .gray)
            }

            Spacer()

            Text(monthYearString(from: currentMonth))
                .font(.headline)
                .foregroundColor(isCurrentMonth ? accentColor : .white)

            Spacer()

            Button {
                if let next = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
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
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    private func canGoBack() -> Bool {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return false }
        return prev >= MonthViewState.startOfMonth(for: accountCreationDate)
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

// MARK: – Calendar View
struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    var onDaySelected: (Date) -> Void = { _ in }

    @EnvironmentObject var habitVM: HabitViewModel

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let coolGray = Color(red: 1.0, green: 0.45, blue: 0.45)

    var body: some View {
        VStack {
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
                        activeDayCell(for: date)
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func activeDayCell(for date: Date) -> some View {
        let dayNorm      = Calendar.current.startOfDay(for: date)
        let creationNorm = Calendar.current.startOfDay(for: accountCreationDate)
        if dayNorm < creationNorm {
            Text(dayString(from: date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.gray)
                .background(Color.black.opacity(0.1))
                .cornerRadius(4)
        } else if date > Date() {
            Text(dayString(from: date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.white)
                .background(Color.gray)
                .cornerRadius(4)
        } else {
            let completion = completionForDay(dayNorm)
            let bgColor: Color = {
                if completion == 1.0 { return .green.opacity(0.6) }
                else if completion > 0 { return .yellow.opacity(0.6) }
                else { return coolGray.opacity(0.6) }
            }()
            Text(dayString(from: date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.white)
                .background(bgColor)
                .cornerRadius(4)
                .onTapGesture { onDaySelected(date) }
        }
    }

    private func completionForDay(_ day: Date) -> Double {
        let cal       = Calendar.current
        let relevant  = habitVM.habits.filter {
            cal.compare($0.startDate, to: day, toGranularity: .day) != .orderedDescending
        }
        let doneCount = relevant.filter {
            $0.dailyRecords.contains { rec in
                cal.isDate(rec.date, inSameDayAs: day) && ((rec.value ?? 0) > 0)
            }
        }.count
        return relevant.isEmpty ? 0 : Double(doneCount) / Double(relevant.count)
    }

    private func generateDays() -> [Date?] {
        var days: [Date?] = []
        let cal      = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return days }
        let first    = cal.startOfDay(for: interval.start)
        let weekday  = cal.component(.weekday, from: first)
        for _ in 1..<weekday { days.append(nil) }
        var cursor = first
        while cursor < interval.end {
            days.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private func dayString(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
}

// MARK: – Day Summary View
struct DaySummaryView: View {
    let day: Date
    @Binding var habits: [Habit]
    let onClose: () -> Void

    @EnvironmentObject var viewModel: HabitViewModel
    private var cal: Calendar { .current }

    @State private var showMetricInput = false
    @State private var metricInput     = ""
    @State private var habitBeingUpdated: Habit?

    private let coolGray = Color(red: 1.0, green: 0.45, blue: 0.45)

    private var relevantHabits: [Habit] {
        habits.filter { cal.compare($0.startDate, to: day, toGranularity: .day) != .orderedDescending }
    }
    private var finishedCount: Int {
        relevantHabits.filter { cal.isDateCompleted(habit: $0, for: day) }.count
    }

    var body: some View {
        ZStack {
            summaryCard
            if showMetricInput { metricInputOverlay.transition(.opacity) }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            Text("Summary for \(formattedDate(day))")
                .font(.headline)
                .foregroundColor(.white)

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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(relevantHabits.enumerated()), id: \.element.id) { idx, habit in
                    Toggle(isOn: bindingForHabitCompletion(indexInAll: idx)) {
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

    private func bindingForHabitCompletion(indexInAll idx: Int) -> Binding<Bool> {
        Binding<Bool>(
            get: { cal.isDateCompleted(habit: habits[idx], for: day) },
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
                if let h = habitBeingUpdated, h.metricType.isCompletedMetric() {
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
        guard let h = habitBeingUpdated else { return "Enter a metric value:" }
        switch h.metricType {
        case .predefined(let v): return predefinedPrompt(for: v)
        case .custom(let v):     return "Enter this day's \(v.lowercased()) value:"
        }
    }

    private func predefinedPrompt(for value: String) -> String {
        let lower = value.lowercased()
        switch true {
        case lower.contains("minute"):    return "How many minutes did you meditate this day?"
        case lower.contains("mile"):      return "How many miles did you run this day?"
        case lower.contains("page"):      return "How many pages did you read this day?"
        case lower.contains("rep"):       return "How many reps did you complete this day?"
        case lower.contains("step"):      return "How many steps did you take this day?"
        case lower.contains("calorie"):   return "How many calories did you burn/consume this day?"
        case lower.contains("hour"):      return "How many hours did you sleep this day?"
        case lower.contains("completed"): return "Were you able to complete the task? (1 = Yes, 0 = No)"
        default:                           return "Enter this day's \(lower) value:"
        }
    }
}

// MARK: – Calendar Extension
extension Calendar {
    func isDateCompleted(habit: Habit, for day: Date) -> Bool {
        habit.dailyRecords.contains { record in
            isDate(record.date, inSameDayAs: day) && ((record.value ?? 0) > 0)
        }
    }
}
