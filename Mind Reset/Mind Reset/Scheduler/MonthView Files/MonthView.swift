//  MonthView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import FirebaseFirestore

// ────────────────────────────────────────────────────────────────
// MARK: – Small helpers
// ────────────────────────────────────────────────────────────────
private enum Field: Hashable { case monthlyPriority(UUID) }
private enum DisplayMode: String, CaseIterable { case days = "Days", weeks = "Weeks" }

// ────────────────────────────────────────────────────────────────
// MARK: – MAIN VIEW
// ────────────────────────────────────────────────────────────────
struct MonthView: View {

    // — injected —
    let accentColor: Color
    let accountCreationDate: Date

    // — env —
    @EnvironmentObject private var monthViewState: MonthViewState
    @EnvironmentObject private var session: SessionStore

    // — models —
    @StateObject private var monthVM = MonthViewModel()
    @StateObject private var dayVM   = DayViewModel()

    // — ui —
    @State private var selectedDay:  Date?
    @State private var showDayPopup  = false
    @State private var editMode      = EditMode.inactive
    @State private var isRemoveMode  = false
    @State private var hasPreviousUnfinished = false
    @State private var displayMode:  DisplayMode = .days
    @State private var weekStartRefreshID = UUID()
    @FocusState private var focusedField: Field?

    // palette
    private let accentCyan = Color(red: 0, green: 1, blue: 1)
    private let coolRed    = Color(red: 1, green: 0.45, blue: 0.45)

    // current user preference (0 = Sun … 6 = Sat)
    private var weekStartIndex: Int {
        UserDefaults.standard.integer(forKey: "weekStartIndex")
    }

    // ────────────────────────── BODY
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                monthNavigationHeader
                monthlyPrioritiesSection
                segmentedPicker

                if displayMode == .days {
                    calendarSection
                        .frame(height: 300)
                        .environmentObject(monthVM)
                } else {
                    weekCardsSection
                }
            }
            .padding(.top, -20)
            .overlay(dayPopupOverlay)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            loadAllMonthDataOnce()
            updateHasPreviousUnfinished()
        }
        .onReceive(NotificationCenter.default.publisher(for: .weekStartChanged)) { _ in
            weekStartRefreshID = UUID()
        }
        .navigationTitle("Your Month")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ────────────────────────── SEGMENTED PICKER
    private var segmentedPicker: some View {
        VStack(spacing: 4) {
            Picker("", selection: $displayMode) {
                Text(DisplayMode.days.rawValue).tag(DisplayMode.days)
                Text(DisplayMode.weeks.rawValue).tag(DisplayMode.weeks)
            }
            .pickerStyle(.segmented)
            .tint(.gray)
            .background(Color.gray)
            .cornerRadius(8)
            .padding(.horizontal, 10)

            Rectangle()
                .fill(Color.black)
                .frame(height: 4)
                .padding(.horizontal, 10)
        }
    }

    // ────────────────────────── WEEK CARDS SECTION
    private var weekCardsSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(weeksInMonth(), id: \.self) { weekStart in
                    WeekCardHostView(
                        accentColor:  accentCyan,
                        weekStart:    weekStart,
                        editMode:     $editMode,
                        isRemoveMode: $isRemoveMode
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 280)
        }
        .id(weekStartRefreshID)   // ← added line
    }


    /// Array of week anchors covering the displayed month (no overlaps)
    private func weeksInMonth() -> [Date] {
        var result: [Date] = []
        let cal = Calendar.current

        // 1) find the month’s full range
        guard let interval = cal.dateInterval(of: .month,
                                              for: monthViewState.currentMonth)
        else { return [] }

        // 2) compute first anchor using current rule
        let firstOfMonth = interval.start
        let firstAnchor  = WeekViewState.startOfWeek(for: firstOfMonth)
        result.append(firstAnchor)

        // 3) hop exactly one week at a time
        var anchor = firstAnchor
        while true {
            let next = WeekViewState.nextWeekStart(from: anchor)
            // stop if that next week begins outside the month
            guard next < interval.end else { break }
            result.append(next)
            anchor = next
        }

        return result
    }


    // ────────────────────────── MONTH NAV HEADER
    private var monthNavigationHeader: some View {
        MonthNavigationView(
            currentMonth:        $monthViewState.currentMonth,
            accountCreationDate: accountCreationDate,
            accentColor:         accentColor
        )
        .padding(.top, 25)
        .onChange(of: monthViewState.currentMonth) { _ in
            loadMonth()
            updateHasPreviousUnfinished()
        }
    }

    // ────────────────────────── MONTHLY PRIORITIES
    private var monthlyPrioritiesSection: some View {
        MonthlyPrioritiesSection(
            priorities: Binding(
                get: { monthVM.schedule?.monthlyPriorities ?? [] },
                set: { new in
                    guard var s = monthVM.schedule else { return }
                    s.monthlyPriorities = new
                    monthVM.schedule = s
                    monthVM.updateMonthSchedule()
                }
            ),
            editMode:             $editMode,
            accentColor:          accentCyan,
            isRemoveMode:         isRemoveMode,
            isThisMonth:          Calendar.current.isDate(monthViewState.currentMonth,
                                                          equalTo: Date(),
                                                          toGranularity: .month),
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
            onMove: { from, to in
                guard var s = monthVM.schedule else { return }
                s.monthlyPriorities.move(fromOffsets: from, toOffset: to)
                monthVM.schedule = s
                monthVM.updateMonthSchedule()
            },
            onCommit: { monthVM.updateMonthSchedule() },
            onDelete: { p in
                guard var s = monthVM.schedule else { return }
                s.monthlyPriorities.removeAll { $0.id == p.id }
                monthVM.schedule = s
                monthVM.updateMonthSchedule()
                if s.monthlyPriorities.isEmpty { isRemoveMode = false }
            },
            addAction: {
                guard var s = monthVM.schedule else { return }
                s.monthlyPriorities.append(
                    MonthlyPriority(id: UUID(), title: "New Priority",
                                    progress: 0, isCompleted: false)
                )
                monthVM.schedule = s
                monthVM.updateMonthSchedule()
                isRemoveMode = false
            },
            importAction: { importUnfinishedFromLastMonth() }
        )
    }

    // ────────────────────────── CALENDAR SECTION (grid)
    private var calendarSection: some View {
        CalendarView(
            currentMonth:        $monthViewState.currentMonth,
            accountCreationDate: accountCreationDate,
            weekStartIndex:      weekStartIndex
        ) { day in
            guard let uid = session.current_user?.uid, day <= Date() else { return }
            selectedDay = day
            dayVM.scheduleMeta = nil            // optional: clear old data
            dayVM.loadDay(for: day, userId: uid)
            withAnimation { showDayPopup = true }
        }
    }

    // ────────────────────────── POPUP OVERLAY
    // MonthView.swift

    @ViewBuilder
    private var dayPopupOverlay: some View {
        if showDayPopup,
           let day = selectedDay,
           let meta = dayVM.scheduleMeta,
           Calendar.current.isDate(meta.date, inSameDayAs: day)
        {
            DayPriorityPopup(
                // Bind straight into dayVM.scheduleMeta.priorities
                priorities: Binding(
                    get: { meta.priorities },
                    set: { new in
                        var updated = meta
                        updated.priorities = new
                        dayVM.scheduleMeta = updated
                        dayVM.pushMeta()    // persist back to Firestore
                    }
                ),
                date: day,
                onSave: { newList in
                        monthVM.saveDayPriorities(for: day, newPriorities: newList)
                    },
                onClose: {
                    withAnimation { showDayPopup = false }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.7).ignoresSafeArea())
            .transition(.opacity)
        }
    }

    // ────────────────────────── DATA HELPERS
    private func loadMonth() {
        guard let uid = session.current_user?.uid else { return }

        let monthID = MonthViewModel.isoMonth.string(from: monthViewState.currentMonth)
        monthVM.loadMonthSchedule(for: monthViewState.currentMonth, userId: uid)

        let ref = Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(monthID)
        ref.getDocument { snap, _ in
            if !(snap?.exists ?? false) {
                let fresh = MonthSchedule(
                    id: monthID, userId: uid, yearMonth: monthID,
                    monthlyPriorities: [], dayCompletions: [:],
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

    private func updateHasPreviousUnfinished() {
        guard let uid = session.current_user?.uid else { hasPreviousUnfinished = false; return }

        let thisMonth = Calendar.current.isDate(Date(),
                                                equalTo: monthViewState.currentMonth,
                                                toGranularity: .month)
        guard thisMonth,
              let lastMonth = Calendar.current.date(byAdding: .month,
                                                    value: -1,
                                                    to: monthViewState.currentMonth) else {
            hasPreviousUnfinished = false
            return
        }

        let lastID = MonthViewModel.isoMonth.string(from: lastMonth)
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(lastID)
            .getDocument { snap, _ in
                if let snap, snap.exists,
                   let prev = try? snap.data(as: MonthSchedule.self) {
                    hasPreviousUnfinished = prev.monthlyPriorities.contains { !$0.isCompleted }
                } else {
                    hasPreviousUnfinished = false
                }
            }
    }

    private func importUnfinishedFromLastMonth() {
        guard let uid = session.current_user?.uid,
              let lastMonth = Calendar.current.date(byAdding: .month, value: -1,
                                                    to: monthViewState.currentMonth) else { return }

        let lastID = MonthViewModel.isoMonth.string(from: lastMonth)
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("monthSchedules").document(lastID)
            .getDocument { snap, _ in
                guard let snap, snap.exists,
                      let prev = try? snap.data(as: MonthSchedule.self),
                      var curr = monthVM.schedule else { return }

                let unfinished = prev.monthlyPriorities.filter { !$0.isCompleted }
                let existing   = Set(curr.monthlyPriorities.map(\.title))
                for p in unfinished where !existing.contains(p.title) {
                    curr.monthlyPriorities.append(
                        MonthlyPriority(id: UUID(), title: p.title,
                                        progress: 0, isCompleted: false)
                    )
                }
                monthVM.schedule = curr
                monthVM.updateMonthSchedule()
            }
    }
}

// ──────────────────────────────────────────────────────────────────
// MARK: – MONTH NAVIGATION VIEW
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
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth),
           prev >= MonthViewState.startOfMonth(for: accountCreationDate) {
            currentMonth = prev
        }
    }
    private func nextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = next
        }
    }
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }
    private var canGoBack: Bool {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)
        else { return false }
        return prev >= MonthViewState.startOfMonth(for: accountCreationDate)
    }
    private func monthYearString(from d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: d)
    }
}


// ──────────────────────────────────────────────────────────────────
// MARK: – WEEK-CARD HOST  (unchanged)
// ──────────────────────────────────────────────────────────────────
private struct WeekCardHostView: View {
    let accentColor: Color
    let weekStart: Date

    @Binding var editMode: EditMode
    @Binding var isRemoveMode: Bool

    @EnvironmentObject private var session: SessionStore
    @StateObject private var weekVM = WeekViewModel()

    var body: some View {
        WeekCardView(
            accentColor:      accentColor,
            weekStart:        weekStart,
            weeklyPriorities: Binding(
                get: { weekVM.schedule?.weeklyPriorities ?? [] },
                set: { new in
                    guard var s = weekVM.schedule else { return }
                    s.weeklyPriorities = new
                    weekVM.schedule = s
                }
            ),
            editMode:     $editMode,
            isRemoveMode: $isRemoveMode,
            onToggle:     { weekVM.toggleWeeklyPriorityCompletion($0) },
            onDelete:     { weekVM.deletePriority($0) },
            onCommit:     { weekVM.updateWeeklySchedule() },
            addAction:    { weekVM.addNewPriority() }
        )
        .onAppear {
            guard let uid = session.current_user?.uid else { return }
            weekVM.loadWeeklySchedule(for: weekStart, userId: uid)
        }
    }
}

// ──────────────────────────────────────────────────────────────────
// MARK: – CALENDAR GRID
// ──────────────────────────────────────────────────────────────────
private struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    let weekStartIndex: Int         // 0 = Sun … 6 = Sat
    var onDaySelected: (Date) -> Void

    @EnvironmentObject var monthVM: MonthViewModel

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let coolRed  = Color(red: 1, green: 0.45, blue: 0.45)

    /// Rotated weekday labels respecting user’s first-weekday
    private var weekdayLabels: [String] {
        let raw = Calendar.current.shortWeekdaySymbols
        return Array(raw[weekStartIndex...] + raw[..<weekStartIndex])
    }

    var body: some View {
        VStack {
            HStack {
                ForEach(weekdayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { maybeDate in
                    if let date = maybeDate { cell(for: date) }
                    else { Color.clear.frame(height: 30) }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let dayStart    = Calendar.current.startOfDay(for: date)
        let creationDay = Calendar.current.startOfDay(for: accountCreationDate)

        if dayStart < creationDay {
            Text(dayString(date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.gray)
                .background(Color.black.opacity(0.1))
                .cornerRadius(4)

        } else if date > Date() {
            Text(dayString(date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.white)
                .background(Color.gray)
                .cornerRadius(4)

        } else {
            let ratio = completionRatio(for: dayStart)
            let bg: Color = {
                switch ratio {
                case 1:                   return .green.opacity(0.6)
                case 0..<1 where ratio>0: return .yellow.opacity(0.6)
                default:                  return coolRed.opacity(0.6)
                }
            }()
            Text(dayString(date))
                .font(.caption2)
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundColor(.white)
                .background(bg)
                .cornerRadius(4)
                .onTapGesture { onDaySelected(date) }
        }
    }

    private func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: d)
    }

    private func completionRatio(for day: Date) -> Double {
        let key = Calendar.current.startOfDay(for: day)
        if let s = monthVM.dayPriorityStatus[key], s.total > 0 {
            return Double(s.done) / Double(s.total)
        }
        return 0
    }

    private func generateDays() -> [Date?] {
        var buffer: [Date?] = []
        let cal = Calendar.current

        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return [] }
        let first = cal.startOfDay(for: interval.start)

        // weekday index Sun=1…Sat=7 → 0…6
        let wkIndex = (cal.component(.weekday, from: first) - 1 + 7) % 7
        let blanks  = (wkIndex - weekStartIndex + 7) % 7
        buffer.append(contentsOf: Array(repeating: nil, count: blanks))

        var cursor = first
        while cursor < interval.end {
            buffer.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return buffer
    }
}

// – helper
extension Calendar {
    func isDateCompleted(habit: Habit, for day: Date) -> Bool {
        habit.dailyRecords.contains {
            isDate($0.date, inSameDayAs: day) && (($0.value ?? 0) > 0)
        }
    }
}

