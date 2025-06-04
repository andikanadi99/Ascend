//  MonthView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import FirebaseFirestore

// ───────────────────────────────────────────────────────────────
private enum Field: Hashable { case monthlyPriority(UUID) }

struct MonthView: View {

    // — injected —
    let accentColor:       Color
    let accountCreationDate: Date

    @EnvironmentObject private var monthViewState: MonthViewState
    @EnvironmentObject private var session:        SessionStore

    // — models —
    @StateObject private var monthVM = MonthViewModel()      // month doc + per-day cache
    @StateObject private var dayVM   = DayViewModel()        // popup loader

    // — ui state —
    @State private var selectedDay:  Date?
    @State private var showDayPopup  = false
    @State private var showCopyAlert = false
    @State private var editMode      = EditMode.inactive
    @State private var isRemoveMode  = false
    @FocusState private var focusedField: Field?

    // Track whether last month has any unfinished priorities
    @State private var hasPreviousUnfinished = false

    // palette
    private let accentCyan = Color(red: 0, green: 1,  blue: 1)
    private let coolRed    = Color(red: 1, green: 0.45, blue: 0.45)

    // ───────────────────────────────────────────────────────────────
    // MARK: – Body
    // ───────────────────────────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                copyPreviousMonthButton
                monthNavigationHeader
                monthlyPrioritiesSection

                calendarSection
                    .frame(height: 300)
                    .environmentObject(monthVM)
            }
            .padding()
            .padding(.top, -20)
            .overlay(dayPopupOverlay)
        }
        .onAppear {
            loadAllMonthDataOnce()
            // Defer so that monthViewState.currentMonth is set
            DispatchQueue.main.async {
                updateHasPreviousUnfinished()
            }
        }
        .onChange(of: monthViewState.currentMonth) { _ in
            loadMonth()
            updateHasPreviousUnfinished()
        }
        .navigationTitle("Your Month")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: – Top controls
    // ───────────────────────────────────────────────────────────────
    private var copyPreviousMonthButton: some View {
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
        .alert("Confirm Copy", isPresented: $showCopyAlert) {
            Button("Copy",  role: .destructive) { copyFromPreviousMonth() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var monthNavigationHeader: some View {
        MonthNavigationView(
            currentMonth: $monthViewState.currentMonth,
            accountCreationDate: accountCreationDate,
            accentColor: accentColor
        )
        .onChange(of: monthViewState.currentMonth) { _ in
            loadMonth()
        }
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: – Monthly priorities
    // ───────────────────────────────────────────────────────────────
    private var monthlyPrioritiesSection: some View {
        MonthlyPrioritiesSection(
            priorities: Binding(
                get: { monthVM.schedule?.monthlyPriorities ?? [] },
                set: { new in
                    guard var s = monthVM.schedule else { return }
                    s.monthlyPriorities = new
                    monthVM.schedule    = s
                    monthVM.updateMonthSchedule()
                }
            ),
            editMode:             $editMode,
            accentColor:          accentCyan,
            isRemoveMode:         isRemoveMode,
            isThisMonth:          Calendar.current.isDate(
                                      monthViewState.currentMonth,
                                      equalTo: Date(),
                                      toGranularity: .month
                                  ),
            hasPreviousUnfinished: hasPreviousUnfinished,
            onToggleRemoveMode:   { isRemoveMode.toggle() },
            onToggle:             { id in
                                      guard var s = monthVM.schedule,
                                            let idx = s.monthlyPriorities.firstIndex(where: { $0.id == id })
                                      else { return }
                                      s.monthlyPriorities[idx].isCompleted.toggle()
                                      monthVM.schedule = s
                                      monthVM.updateMonthSchedule()
                                  },
            onMove:               { offsets, newOffset in
                                      guard var s = monthVM.schedule else { return }
                                      s.monthlyPriorities.move(fromOffsets: offsets, toOffset: newOffset)
                                      monthVM.schedule = s
                                      monthVM.updateMonthSchedule()
                                  },
            onCommit:             { monthVM.updateMonthSchedule() },
            onDelete:             { p in
                                      guard var s = monthVM.schedule else { return }
                                      s.monthlyPriorities.removeAll { $0.id == p.id }
                                      monthVM.schedule = s
                                      monthVM.updateMonthSchedule()
                                      if s.monthlyPriorities.isEmpty { isRemoveMode = false }
                                  },
            addAction:            {
                                      guard var s = monthVM.schedule else { return }
                                      s.monthlyPriorities.append(
                                          MonthlyPriority(
                                              id: UUID(),
                                              title: "New Priority",
                                              progress: 0,
                                              isCompleted: false
                                          )
                                      )
                                      monthVM.schedule = s
                                      monthVM.updateMonthSchedule()
                                      isRemoveMode = false
                                  },
            importAction:         { importUnfinishedFromLastMonth() }
        )
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: – Calendar grid
    // ───────────────────────────────────────────────────────────────
    private var calendarSection: some View {
        CalendarView(
            currentMonth: $monthViewState.currentMonth,
            accountCreationDate: accountCreationDate
        ) { day in
            guard let uid = session.userModel?.id, day <= Date() else { return }
            selectedDay = day
            dayVM.loadDaySchedule(for: day, userId: uid)
            withAnimation { showDayPopup = true }
        }
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: – Popup overlay
    // ───────────────────────────────────────────────────────────────
    @ViewBuilder
    private var dayPopupOverlay: some View {
        if showDayPopup, let day = selectedDay {
            let key = Calendar.current.startOfDay(for: day)
            if monthVM.dayPriorityStorage[key] != nil {
                DayPriorityPopup(
                    priorities: Binding(
                        get: { monthVM.dayPriorityStorage[key]! },
                        set: { monthVM.dayPriorityStorage[key] = $0 }
                    ),
                    date: day,
                    onSave: { new in monthVM.saveDayPriorities(for: day, newPriorities: new) },
                    onClose: { withAnimation { showDayPopup = false } }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7).ignoresSafeArea())
                .transition(.opacity)
            }
        }
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: – Data helpers
    // ───────────────────────────────────────────────────────────────
    /// Fetches MonthSchedule *and* the 30-odd DaySchedule docs
    private func loadMonth() {
        guard let uid = session.userModel?.id else { return }

        // Ensure MonthSchedule document exists and load it
        let monthID = MonthViewModel.isoMonth.string(from: monthViewState.currentMonth)
        monthVM.loadMonthSchedule(for: monthViewState.currentMonth, userId: uid)

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(monthID)
        ref.getDocument { snap, _ in
            if !(snap?.exists ?? false) {
                let fresh = MonthSchedule(
                    id:                  monthID,
                    userId:              uid,
                    yearMonth:           monthID,
                    monthlyPriorities:   [],
                    dayCompletions:      [:],
                    dailyPrioritiesByDay: [:]
                )
                try? ref.setData(from: fresh)
                monthVM.schedule = fresh
            }
        }
    }

    private func loadAllMonthDataOnce() {
        let now  = Date()
        let last = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 {
            monthViewState.currentMonth = MonthViewState.startOfMonth(for: now)
        }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")
        loadMonth()
    }

    private func copyFromPreviousMonth() {
        guard let uid  = session.userModel?.id,
              let curr = monthVM.schedule,
              let prev = Calendar.current.date(byAdding: .month, value: -1,
                                               to: monthViewState.currentMonth) else { return }

        let idPrev = MonthViewModel.isoMonth.string(from: prev)
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(idPrev)
            .getDocument { snap, _ in
                guard let snap, snap.exists,
                      let prevSched = try? snap.data(as: MonthSchedule.self) else { return }
                var updated = curr
                updated.monthlyPriorities = prevSched.monthlyPriorities
                monthVM.schedule = updated
                monthVM.updateMonthSchedule()
            }
    }

    // ───────────────────────────────────────────────────────────────
    // MARK: – Import Unfinished Helper
    // ───────────────────────────────────────────────────────────────
    private func updateHasPreviousUnfinished() {
        guard let uid = session.userModel?.id else {
            hasPreviousUnfinished = false
            return
        }
        // Only check if displayed month is “this” calendar month
        let thisMonth = Calendar.current.isDate(
            Date(),
            equalTo: monthViewState.currentMonth,
            toGranularity: .month
        )
        if thisMonth {
            // Compute last month’s start date
            guard let lastMonth = Calendar.current.date(
                      byAdding: .month,
                      value: -1,
                      to: monthViewState.currentMonth
                  ) else {
                hasPreviousUnfinished = false
                return
            }
            let lastID = MonthViewModel.isoMonth.string(from: lastMonth)
            let ref = Firestore.firestore()
                .collection("users").document(uid)
                .collection("monthSchedules").document(lastID)
            ref.getDocument { snap, _ in
                if let snap, snap.exists,
                   let prevSched = try? snap.data(as: MonthSchedule.self) {
                    let unfinished = prevSched.monthlyPriorities.filter { !$0.isCompleted }
                    hasPreviousUnfinished = !unfinished.isEmpty
                } else {
                    hasPreviousUnfinished = false
                }
            }
        } else {
            hasPreviousUnfinished = false
        }
    }

    private func importUnfinishedFromLastMonth() {
        guard let uid = session.userModel?.id else { return }
        // Compute last month’s start date
        guard let lastMonth = Calendar.current.date(
                  byAdding: .month,
                  value: -1,
                  to: monthViewState.currentMonth
              ) else { return }
        let lastID = MonthViewModel.isoMonth.string(from: lastMonth)
        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(lastID)
        ref.getDocument { snap, _ in
            if let snap, snap.exists,
               let prevSched = try? snap.data(as: MonthSchedule.self),
               var currSched = monthVM.schedule {
                let unfinished = prevSched.monthlyPriorities.filter { !$0.isCompleted }
                // Avoid duplicates by title
                let existingTitles = Set(currSched.monthlyPriorities.map { $0.title })
                for old in unfinished {
                    if !existingTitles.contains(old.title) {
                        let newPriority = MonthlyPriority(
                            id: UUID(),
                            title: old.title,
                            progress: 0,
                            isCompleted: false
                        )
                        currSched.monthlyPriorities.append(newPriority)
                    }
                }
                monthVM.schedule = currSched
                monthVM.updateMonthSchedule()
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────
// MARK: – Month navigation view (arrows + label)
// ──────────────────────────────────────────────────────────────────
private struct MonthNavigationView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    let accentColor: Color

    var body: some View {
        HStack {
            Button { prevMonth() } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack ? .white : .gray)
            }
            Spacer()
            Text(monthYearString(from: currentMonth))
                .font(.headline)
                .foregroundColor(isCurrentMonth ? accentColor : .white)
            Spacer()
            Button { nextMonth() } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    private func prevMonth() {
        if let prev = Calendar.current.date(byAdding: .month,
                                            value: -1,
                                            to: currentMonth),
           prev >= MonthViewState.startOfMonth(for: accountCreationDate) {
            currentMonth = prev
        }
    }
    private func nextMonth() {
        if let next = Calendar.current.date(byAdding: .month,
                                            value: 1,
                                            to: currentMonth) {
            currentMonth = next
        }
    }
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }
    private var canGoBack: Bool {
        guard let prev = Calendar.current.date(byAdding: .month,
                                               value: -1,
                                               to: currentMonth)
        else { return false }
        return prev >= MonthViewState.startOfMonth(for: accountCreationDate)
    }
    private func monthYearString(from d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f.string(from: d)
    }
}

// ──────────────────────────────────────────────────────────────────
// MARK: – Calendar grid
// ──────────────────────────────────────────────────────────────────
private struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    var onDaySelected: (Date) -> Void

    @EnvironmentObject var monthVM: MonthViewModel

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let coolRed  = Color(red: 1.0, green: 0.45, blue: 0.45)

    var body: some View {
        VStack {
            // weekday headers
            HStack {
                ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }

            // grid of days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { maybeDate in
                    if let date = maybeDate { cell(for: date) }
                    else { Color.clear.frame(height: 30) }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: day cell
    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let dayStart    = Calendar.current.startOfDay(for: date)
        let creationDay = Calendar.current.startOfDay(for: accountCreationDate)

        if dayStart < creationDay {                    // before account creation
            Text(dayString(date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.gray)
                .background(Color.black.opacity(0.1))
                .cornerRadius(4)

        } else if date > Date() {                      // future day
            Text(dayString(date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.white)
                .background(Color.gray)
                .cornerRadius(4)

        } else {                                       // current/past day
            let ratio      = completionRatio(for: dayStart)
            let background: Color = {
                switch ratio {
                case 1.0:                      return .green.opacity(0.6)
                case 0..<1 where ratio > 0:    return .yellow.opacity(0.6)
                default:                       return coolRed.opacity(0.6)
                }
            }()
            Text(dayString(date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.white)
                .background(background)
                .cornerRadius(4)
                .onTapGesture { onDaySelected(date) }
        }
    }

    // MARK: helpers
    private func completionRatio(for day: Date) -> Double {
        let key = Calendar.current.startOfDay(for: day)
        if let status = monthVM.dayPriorityStatus[key], status.total > 0 {
            return Double(status.done) / Double(status.total)
        }
        return 0
    }

    private func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: d)
    }

    private func generateDays() -> [Date?] {
        var days: [Date?] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return days }
        let first  = cal.startOfDay(for: interval.start)
        let offset = cal.component(.weekday, from: first) - 1      // sunday = 1
        days.append(contentsOf: Array(repeating: nil, count: offset))
        var cursor = first
        while cursor < interval.end {
            days.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return days
    }
}
// MARK: – Day Summary View (unchanged from previous)
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
